import { execSync } from 'child_process';
import { readFileSync, existsSync } from 'fs';
import { select, outro, intro, spinner, isCancel } from '@clack/prompts';
import chalk from 'chalk';

// Helper to execute git/system commands
function runCmd(cmd) {
  try {
    return execSync(cmd, { encoding: 'utf8', stdio: 'pipe' }).trim();
  } catch (err) {
    const stderr = err.stderr ? err.stderr.toString() : err.message;
    throw new Error(`Command failed: ${cmd}\nError: ${stderr}`);
  }
}

// Helper to increment SemVer version
function incrementVersion(version, type) {
  const parts = version.split('.').map(Number);
  if (type === 'patch') {
    parts[2] += 1;
  } else if (type === 'minor') {
    parts[1] += 1;
    parts[2] = 0;
  } else if (type === 'major') {
    parts[0] += 1;
    parts[1] = 0;
    parts[2] = 0;
  }
  return parts.join('.');
}

async function main() {
  intro(chalk.cyan('Ziptie Git Flow Release Orchestrator'));

  // Pre-flight check A: Must be on develop branch
  let currentBranch = '';
  try {
    currentBranch = runCmd('git rev-parse --abbrev-ref HEAD');
  } catch (e) {
    outro(chalk.red('Error: Not in a git repository.'));
    process.exit(1);
  }

  if (currentBranch !== 'develop') {
    outro(chalk.red(`Error: Releases must be initiated from the "develop" branch. Currently on: "${currentBranch}"`));
    process.exit(1);
  }

  // Pre-flight check B: Git working tree must be clean
  const status = runCmd('git status --porcelain');
  if (status.length > 0) {
    outro(chalk.red('Error: Git working directory is not clean. Please commit or stash your changes.'));
    process.exit(1);
  }

  // Read current version
  const pkg = JSON.parse(readFileSync('package.json', 'utf8'));
  const currentVersion = pkg.version;

  // Prompt for version increment
  const releaseType = await select({
    message: `Current version is ${chalk.green(currentVersion)}. Select next version increment:`,
    options: [
      { value: 'patch', label: `Patch (${incrementVersion(currentVersion, 'patch')})` },
      { value: 'minor', label: `Minor (${incrementVersion(currentVersion, 'minor')})` },
      { value: 'major', label: `Major (${incrementVersion(currentVersion, 'major')})` }
    ]
  });

  if (isCancel(releaseType)) {
    outro(chalk.yellow('Release cancelled.'));
    process.exit(0);
  }

  const nextVersion = incrementVersion(currentVersion, releaseType);
  const branchName = `release/v${nextVersion}`;

  const s = spinner();
  s.start(`Creating release branch ${branchName}...`);

  try {
    // 1. Create and switch to release branch
    runCmd(`git checkout -b ${branchName}`);

    // 2. Bump the package version in package.json and package-lock.json
    s.message('Bumping package versions...');
    runCmd(`npm version ${nextVersion} --no-git-tag-version`);

    // 3. Commit version bumps
    s.message('Committing version bump...');
    runCmd('git add package.json package-lock.json');
    runCmd(`git commit -m "chore(release): v${nextVersion}"`);

    // 4. Merge release branch into main
    s.message('Merging release branch into main...');
    runCmd('git checkout main');
    runCmd(`git merge ${branchName} --no-edit --allow-unrelated-histories -X theirs`);

    // 5. Create local git tag on main
    s.message(`Creating git tag v${nextVersion} on main...`);
    runCmd(`git tag v${nextVersion}`);

    // 6. Merge main back into develop to keep them in sync
    s.message('Merging main back into develop...');
    runCmd('git checkout develop');
    runCmd('git merge main --no-edit');

    // 7. Push both branches and tags to GitHub
    s.message('Pushing main, develop, and tags to GitHub...');
    runCmd('git push origin main');
    runCmd('git push origin develop');
    runCmd('git push origin --tags');

    s.stop(chalk.green(`Git Flow branches successfully merged and pushed for v${nextVersion}!`));
  } catch (err) {
    s.stop(chalk.red('Git Flow sequence failed!'));
    console.error(chalk.red(err.message));

    // Attempt recovery back to develop
    try {
      runCmd('git checkout develop');
    } catch {}
    process.exit(1);
  }

  // 8. Clean up release branch and return to develop
  const cleanupSpinner = spinner();
  cleanupSpinner.start('Cleaning up and checking out develop...');
  try {
    runCmd('git checkout develop');
    runCmd(`git branch -d ${branchName}`);
    cleanupSpinner.stop(chalk.green('Cleanup completed. Checked out develop.'));
  } catch (err) {
    cleanupSpinner.stop(chalk.red('Failed to clean up release branch.'));
    console.error(chalk.red(err.message));
  }

  outro(chalk.green(`\nZiptie Release process finished for v${nextVersion}!`));
}

main();
