import { readFileSync } from 'node:fs';
import { execSync } from 'node:child_process';
import { intro, isCancel, outro, select, tasks } from '@clack/prompts';
import chalk from 'chalk';
import { branchTasks, mergeTasks, syncTasks } from './release-tasks.js';

function run(cmd, args) {
  try {
    const fullCmd = [cmd, ...args].join(' ');
    return execSync(fullCmd, { encoding: 'utf8', stdio: 'pipe' }).trim();
  } catch (err) {
    const message = err.stderr ? err.stderr.toString() : err.message;
    throw new Error(`${cmd} ${args.join(' ')} failed: ${message}`);
  }
}

function computeNextVersion(version, type) {
  const [major = 0, minor = 0, patch = 0] = version.split('.').map(Number);
  if (type === 'major') return `${major + 1}.0.0`;
  if (type === 'minor') return `${major}.${minor + 1}.0`;
  return `${major}.${minor}.${patch + 1}`;
}

function verifyGitState() {
  const branch = run('git', ['rev-parse', '--abbrev-ref', 'HEAD']);
  if (branch !== 'develop') {
    throw new Error(`Releases must start from "develop". Current: "${branch}"`);
  }
  const status = run('git', ['status', '--porcelain']);
  if (status.length > 0) {
    throw new Error('Working directory has uncommitted changes.');
  }
}

async function promptVersion(currentVersion) {
  const options = ['patch', 'minor', 'major'].map(type => ({
    value: type,
    label: `${type} (${computeNextVersion(currentVersion, type)})`,
  }));
  const choice = await select({
    message: `Current version is ${chalk.green(currentVersion)}. Select next version:`,
    options,
  });
  if (isCancel(choice)) {
    outro(chalk.yellow('Release cancelled.'));
    process.exit(0);
  }
  return computeNextVersion(currentVersion, choice);
}

function recoverToDevelop(err) {
  console.error(chalk.red(`Release failed: ${err.message}`));
  try {
    run('git', ['checkout', 'develop']);
  } catch {
    // Best-effort recovery
  }
  process.exit(1);
}

async function main() {
  intro(chalk.cyan('Ziptie Release Orchestrator'));
  try {
    verifyGitState();
  } catch (err) {
    outro(chalk.red(err.message));
    process.exit(1);
  }
  const pkg = JSON.parse(readFileSync('package.json', 'utf8'));
  const nextVersion = await promptVersion(pkg.version);
  const branch = `release/v${nextVersion}`;
  try {
    await tasks([
      ...branchTasks(run, nextVersion, branch),
      ...mergeTasks(run, nextVersion, branch),
      ...syncTasks(run, branch),
    ]);
    outro(chalk.green(`v${nextVersion} released and pushed to GitHub!`));
  } catch (err) {
    recoverToDevelop(err);
  }
}

main();
