import { spawn } from 'node:child_process';
import * as path from 'node:path';

/**
 * Executes a modular PowerShell script silently and captures errors.
 *
 * @param scriptPath Relative or absolute path to the target .ps1 script.
 * @param configPath Path to the temporary merged configuration JSON file.
 * @param isUndo True if running in revert/undo mode.
 * @param isDryRun True if running in safe dry-run mode.
 * @param extraArgs Optional additional arguments to pass to the script execution.
 */
export const runPowerShellScript = (
  scriptPath: string,
  configPath: string,
  isUndo: boolean,
  isDryRun: boolean,
  extraArgs: string[] = []
): Promise<void> => {
  return new Promise((resolve, reject) => {
    const resolvedPath = path.resolve(scriptPath);
    const escapedScriptPath = resolvedPath.replace(/'/g, "''");
    const escapedConfigPath = path.resolve(configPath).replace(/'/g, "''");
    const isLockdownScript =
      resolvedPath.includes('scripts/windows') || resolvedPath.includes('scripts\\windows');

    let scriptCmd = '';
    if (isLockdownScript) {
      scriptCmd += `$config = Get-Content -Raw -Path '${escapedConfigPath}' | ConvertFrom-Json; `;
      scriptCmd += `& '${escapedScriptPath}' -Config $config`;
      if (isDryRun) scriptCmd += ' -DryRun';
      if (isUndo) scriptCmd += ' -Undo';
    } else {
      scriptCmd += `& '${escapedScriptPath}'`;
      if (isDryRun) scriptCmd += ' -DryRun';
    }

    if (extraArgs.length > 0) {
      scriptCmd += ' ' + extraArgs.join(' ');
    }

    const args = [
      '-ExecutionPolicy', 'Bypass',
      '-NoProfile',
      '-Command', scriptCmd
    ];

    const child = spawn('powershell.exe', args, {
      shell: false,
      windowsHide: true,
      stdio: 'pipe'
    });

    let stdout = '';
    let stderr = '';

    child.stdout.on('data', (data) => {
      stdout += data.toString();
    });
    
    child.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    child.on('close', (code) => {
      if (code === 0) {
        resolve();
      } else {
        const errorDetails = stderr.trim() || stdout.trim() || `Exited with code ${code}`;
        reject(new Error(errorDetails));
      }
    });
  });
};
