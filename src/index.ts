import * as fs from 'node:fs';
import * as path from 'node:path';
import { spawn, execSync } from 'node:child_process';
import { intro, outro, confirm } from '@clack/prompts';
import { Listr } from 'listr2';
import chalk from 'chalk';

// Helper to determine if current session runs elevated (Admin)
function isAdmin(): boolean {
  try {
    execSync('net session', { stdio: 'ignore', windowsHide: true });
    return true;
  } catch {
    return false;
  }
}

// Helper to silently execute modular PowerShell scripts and return console output on failure
const runPowerShellScript = (
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
    const isLockdownScript = resolvedPath.includes('scripts/windows') || resolvedPath.includes('scripts\\windows');

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

    child.stdout.on('data', (data) => { stdout += data.toString(); });
    child.stderr.on('data', (data) => { stderr += data.toString(); });

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

const args = process.argv.slice(2);
const hasFlag = (flag: string, short: string) => args.includes(flag) || args.includes(short);
const getArgValue = (flag: string, short: string): string | null => {
  const idx = args.findIndex(a => a === flag || a === short);
  if (idx !== -1 && idx + 1 < args.length) {
    return args[idx + 1];
  }
  return null;
};

const dryRun = hasFlag('--dry-run', '-d');
const undo = hasFlag('--undo', '-u');
const customConfigPath = getArgValue('--config', '-c');
const autoConfirm = hasFlag('--yes', '-y');

interface LockdownTaskSpec {
  title: string;
  file: string;
  action?: string;
  undoAction?: string;
}

const OS_LOCKDOWN_TASKS: LockdownTaskSpec[] = [
  { title: 'Windows Widgets', file: 'disable-windows-widgets.ps1' },
  { title: 'Copilot & Recall AI', file: 'disable-copilot-recall.ps1' },
  { title: 'Windows Update Policies', file: 'disable-update-service.ps1', action: 'Configuring', undoAction: 'Restoring' },
  { title: 'Screensaver & Standby', file: 'disable-screensaver.ps1' },
  { title: 'Accessibility Shortcuts', file: 'disable-accessibility.ps1' },
  { title: 'Screen Edge Swipes', file: 'disable-edge-swipes.ps1' },
  { title: 'Visual Touch Feedback', file: 'disable-touch-feedback.ps1' },
  { title: 'Setup Prompts & OOBE', file: 'disable-win-setup-prompts.ps1' },
  { title: 'Default Desktop Icons', file: 'clear-desktop-shortcuts.ps1', action: 'Clearing', undoAction: 'Restoring' },
  { title: 'Solid Color Background', file: 'set-desktop-background.ps1', action: 'Applying', undoAction: 'Restoring' },
  { title: 'Windows Dark Mode', file: 'enable-dark-mode.ps1', action: 'Configuring', undoAction: 'Restoring' },
  { title: 'File Explorer Defaults', file: 'config-explorer.ps1', action: 'Configuring', undoAction: 'Restoring' },
  { title: 'Automatic App Installs', file: 'disable-app-installs.ps1' },
  { title: 'App Restore Features', file: 'disable-app-restore.ps1' },
  { title: 'Windows Error Reporting', file: 'disable-error-reporting.ps1' },
  { title: 'Network Firewalls', file: 'disable-firewall.ps1', action: 'Disabling', undoAction: 'Enabling' },
  { title: 'Win32 Long Paths Support', file: 'disable-max-path-length.ps1', action: 'Enabling', undoAction: 'Disabling' },
  { title: 'New Network Dialog Popups', file: 'disable-new-network-window.ps1' },
  { title: 'Toast Notifications', file: 'disable-notifications.ps1' },
  { title: 'Touchpad Edge Gestures', file: 'disable-touch-gestures.ps1' },
  { title: 'PowerShell Script Execution', file: 'enable-script-execution.ps1', action: 'Enabling', undoAction: 'Restoring' },
  { title: 'Desktop Text Scale Factor', file: 'reset-text-scale.ps1', action: 'Resetting', undoAction: 'Restoring' },
  { title: 'Windows Bloatware', file: 'uninstall-bloatware.ps1', action: 'Uninstalling', undoAction: 'Restoring' },
  { title: 'Microsoft OneDrive', file: 'uninstall-one-drive.ps1', action: 'Uninstalling', undoAction: 'Restoring' },
  { title: 'Default Start Menu Apps', file: 'unpin-start-menu-apps.ps1', action: 'Unpinning', undoAction: 'Restoring' },
  { title: 'Active Power Scheme', file: 'set-power-settings.ps1', action: 'Configuring', undoAction: 'Restoring' }
];

async function main() {
  if (process.platform !== 'win32') {
    console.error(chalk.red('Error: Slab currently only supports Windows.'));
    process.exit(1);
  }


  // 1. Elevate process if not Administrator
  if (!isAdmin() && !dryRun) {
    console.log(chalk.yellow('Elevation required. Spawning administrative UAC prompt...'));
    const nodeExecutable = process.argv[0];
    const nodeArgs = process.argv.slice(1);
    const formattedArgs = nodeArgs.map(arg => arg.includes(' ') ? `"${arg}"` : arg).join(' ');
    
    const runCmd = `powershell -Command "Start-Process -FilePath '${nodeExecutable}' -ArgumentList '${formattedArgs}' -Verb RunAs"`;
    try {
      execSync(runCmd);
      process.exit(0);
    } catch (e: any) {
      console.error(chalk.red(`Elevation request failed: ${e.message}`));
      process.exit(1);
    }
  }

  intro(chalk.bold.cyan(' 🚀 SLAB SYSTEM LOCKDOWN ENGINE '));

  // Determine configuration file paths
  let projectRoot = path.resolve(__dirname, '..');
  
  // If not found relative to __dirname, check relative to the physical executable path (for compiled standalone binaries)
  if (!fs.existsSync(path.join(projectRoot, 'slab.default.config.json'))) {
    const exeDir = path.dirname(process.execPath);
    projectRoot = path.resolve(exeDir, '..');
    if (!fs.existsSync(path.join(projectRoot, 'slab.default.config.json'))) {
      projectRoot = exeDir;
    }
  }

  // Fallback to current working directory if still not found
  if (!fs.existsSync(path.join(projectRoot, 'slab.default.config.json'))) {
    projectRoot = process.cwd();
  }

  const defaultConfigPath = path.join(projectRoot, 'slab.default.config.json');
  if (!fs.existsSync(defaultConfigPath)) {
    console.error(chalk.red(`Error: Missing default configuration at ${defaultConfigPath}`));
    process.exit(1);
  }

  // Load defaultConfig
  let defaultConfig: any = {};
  try {
    defaultConfig = JSON.parse(fs.readFileSync(defaultConfigPath, 'utf8'));
  } catch (e: any) {
    console.error(chalk.red(`Error parsing default configuration: ${e.message}`));
    process.exit(1);
  }

  const configFilePath = customConfigPath 
    ? path.resolve(customConfigPath) 
    : path.resolve(process.cwd(), 'slab.config.json');

  let userConfig: any = {};
  if (fs.existsSync(configFilePath)) {
    try {
      userConfig = JSON.parse(fs.readFileSync(configFilePath, 'utf8'));
    } catch (e: any) {
      console.error(chalk.red(`Error parsing user config file: ${e.message}`));
      process.exit(1);
    }
  }

  // Merge default config with user config
  const mergedConfig = {
    ...defaultConfig,
    ...userConfig,
    system: { ...defaultConfig.system, ...userConfig.system },
    autologon: { ...defaultConfig.autologon, ...userConfig.autologon },
    startupTask: { ...defaultConfig.startupTask, ...userConfig.startupTask },
    packageManager: { ...defaultConfig.packageManager, ...userConfig.packageManager },
    lockdown: { ...defaultConfig.lockdown, ...userConfig.lockdown }
  };

  // Write temporary config file
  const tmpDir = path.resolve(process.cwd(), '.tmp');
  if (!fs.existsSync(tmpDir)) {
    fs.mkdirSync(tmpDir, { recursive: true });
  }

  const resolvedConfigPath = path.join(tmpDir, 'slab-temp-config.json');
  fs.writeFileSync(resolvedConfigPath, JSON.stringify(mergedConfig, null, 2), 'utf8');

  // Verify and confirm
  const actionName = undo ? 'Undo Kiosk Lockdown' : 'Pour Concrete Slab & Lock Down PC';
  let proceed: boolean | symbol = true;
  if (!autoConfirm) {
    proceed = await confirm({
      message: `Ready to execute: ${chalk.bold.yellow(actionName)}?`,
      initialValue: true,
    });
  }

  if (typeof proceed === 'symbol' || !proceed) {
    outro(chalk.yellow('Operation cancelled by the user. No changes were made.'));
    process.exit(0);
  }

  let hiveMounted = false;
  const scriptsDir = path.join(projectRoot, 'scripts', 'windows');
  const utilsDir = path.join(projectRoot, 'src', 'powershell', 'utils');

  // Define tasks
  const tasks = new Listr([
    {
      title: 'Environment Verification',
      task: () => {
        if (process.platform !== 'win32') {
          throw new Error('Slab only supports Windows.');
        }
      }
    },
    {
      title: 'Core System Configuration',
      task: (ctx, task) => task.newListr([
        {
          title: 'Configuring System Timezone',
          task: () => runPowerShellScript(path.join(scriptsDir, 'set-timezone.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Setting Computer Hostname',
          task: () => runPowerShellScript(path.join(scriptsDir, 'set-computer-name.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Configuring Scheduled Daily Reboot',
          task: () => runPowerShellScript(path.join(scriptsDir, 'enable-daily-reboot.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Configuring Passwordless Autologon',
          task: () => runPowerShellScript(path.join(scriptsDir, 'enable-auto-login.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Configuring Exhibit Startup Task',
          task: () => runPowerShellScript(path.join(scriptsDir, 'enable-startup-task.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Provisioning Offline/Local Apps',
          task: () => runPowerShellScript(path.join(scriptsDir, 'install-local-apps.ps1'), resolvedConfigPath, undo, dryRun)
        }
      ], { concurrent: false })
    },
    {
      title: 'Mounting Default User Registry Hive',
      skip: () => dryRun,
      task: async () => {
        await runPowerShellScript(
          path.join(utilsDir, 'slab-mount-hive.ps1'),
          resolvedConfigPath,
          undo,
          dryRun,
          ['-MountName', 'HKU\\DefaultUser', '-HivePath', 'C:\\Users\\Default\\NTUSER.DAT']
        );
        hiveMounted = true;
      }
    },
    {
      title: 'OS Lockdowns & Shell Policies',
      task: (ctx, task) => task.newListr(
        OS_LOCKDOWN_TASKS.map(spec => ({
          title: undo
            ? `${spec.undoAction || 'Restoring'} ${spec.title}`
            : `${spec.action || 'Disabling'} ${spec.title}`,
          task: () => runPowerShellScript(path.join(scriptsDir, spec.file), resolvedConfigPath, undo, dryRun)
        })),
        { concurrent: false }
      )
    },
    {
      title: 'Unmounting Default User Registry Hive',
      skip: () => dryRun || !hiveMounted,
      task: async () => {
        await runPowerShellScript(
          path.join(utilsDir, 'slab-unmount-hive.ps1'),
          resolvedConfigPath,
          undo,
          dryRun,
          ['-MountName', 'HKU\\DefaultUser']
        );
        hiveMounted = false;
      }
    },
    {
      title: 'Applying Shell Modifications',
      skip: () => dryRun,
      task: () => {
        try {
          execSync('powershell -Command "Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue"', { stdio: 'ignore', windowsHide: true });
        } catch {
          // Explorer restart fails occasionally if already stopped; ignore failure
        }
      }
    }
  ]);

  try {
    await tasks.run();
    outro(chalk.bold.green(' ✔ Slab kiosk lockdown pipeline completed successfully! '));

    if (!dryRun && !autoConfirm) {
      console.log('');
      const result = await confirm({
        message: 'Would you like to restart the computer now to finalize all changes?',
        initialValue: false
      });

      if (typeof result === 'boolean' && result) {
        outro(chalk.bold.green(' 🔄 Restarting computer now... '));
        execSync('shutdown /r /t 0 /f', { stdio: 'ignore', windowsHide: true });
      } else {
        outro(chalk.yellow('Restart skipped. Please restart manually for all changes to apply.'));
      }
    }
  } catch (err: any) {
    // Attempt rescue unmounting in case of failure
    if (hiveMounted && !dryRun) {
      try {
        execSync(`powershell -Command "& '${path.join(utilsDir, 'slab-unmount-hive.ps1')}' -MountName 'HKU\\DefaultUser'"`, { stdio: 'ignore', windowsHide: true });
      } catch {
        // Suppress secondary failures
      }
    }
    outro(chalk.bold.red(` ✘ Slab execution encountered errors: ${err.message}`));
    process.exit(1);
  }
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
