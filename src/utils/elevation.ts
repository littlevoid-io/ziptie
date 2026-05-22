import { execSync } from 'node:child_process';
import chalk from 'chalk';

/**
 * Checks if the current process has administrative (elevated) privileges.
 */
export function isAdmin(): boolean {
  try {
    execSync('net session', { stdio: 'ignore', windowsHide: true });
    return true;
  } catch {
    return false;
  }
}

/**
 * Asserts administrative rights. Spawns an elevated UAC session and terminates
 * the current process if elevation is needed and not already present.
 *
 * @param dryRun If true, skips elevation assertions as no real system changes will be made.
 */
export function ensureElevated(dryRun: boolean): void {
  if (process.platform !== 'win32') {
    // Suppress elevation check on non-windows platforms (which will error downstream anyway)
    return;
  }

  if (!isAdmin() && !dryRun) {
    console.log(chalk.yellow('Elevation required. Spawning administrative UAC prompt...'));
    
    const nodeExecutable = process.argv[0];
    const nodeArgs = process.argv.slice(1);
    const formattedArgs = nodeArgs
      .map(arg => (arg.includes(' ') ? `"${arg}"` : arg))
      .join(' ');

    const runCmd = `powershell -Command "Start-Process -FilePath '${nodeExecutable}' -ArgumentList '${formattedArgs}' -Verb RunAs"`;
    
    try {
      execSync(runCmd);
      process.exit(0);
    } catch (e: any) {
      console.error(chalk.red(`Elevation request failed: ${e.message}`));
      process.exit(1);
    }
  }
}
