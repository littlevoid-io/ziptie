import * as fs from 'node:fs';
import * as path from 'node:path';
import { spawn, execSync } from 'node:child_process';
import { intro, outro, confirm } from '@clack/prompts';
import { Listr } from 'listr2';
import chalk from 'chalk';

// Helper to determine if current session runs elevated (Admin)
function isAdmin(): boolean {
  try {
    execSync('net session', { stdio: 'ignore' });
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
      '-Command', `"${scriptCmd}"`
    ];

    const child = spawn('powershell.exe', args, {
      shell: true,
      stdio: 'pipe'
    });

    let stdout = '';
    let stderr = '';

    child.stdout.on('data', (data) => { stdout += data.toString(); });
    child.stderr.on('data', (data) => { stderr += data.toString(); });

    child.on('close', (code) => {
      if (process.platform === 'win32') {
        try {
          execSync('chcp 65001', { stdio: 'ignore' });
        } catch {}
      }
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

async function main() {
  if (process.platform !== 'win32') {
    console.error(chalk.red('Error: Slab currently only supports Windows.'));
    process.exit(1);
  }

  try {
    execSync('chcp 65001', { stdio: 'ignore' });
  } catch {}

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
        if (!dryRun) {
          // Initialize HKU drive provider scoping helper
          execSync('powershell -Command "New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -ErrorAction SilentlyContinue | Out-Null"', { stdio: 'ignore' });
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
      task: (ctx, task) => task.newListr([
        {
          title: 'Disabling Windows Widgets',
          task: () => runPowerShellScript(path.join(scriptsDir, 'disable-windows-widgets.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Disabling Copilot & Recall AI',
          task: () => runPowerShellScript(path.join(scriptsDir, 'disable-copilot-recall.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Configuring Windows Update Policies',
          task: () => runPowerShellScript(path.join(scriptsDir, 'disable-update-service.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Disabling Screensaver & Standby',
          task: () => runPowerShellScript(path.join(scriptsDir, 'disable-screensaver.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Disabling Accessibility Shortcuts',
          task: () => runPowerShellScript(path.join(scriptsDir, 'disable-accessibility.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Disabling Screen Edge Swipes',
          task: () => runPowerShellScript(path.join(scriptsDir, 'disable-edge-swipes.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Disabling Visual Touch Feedback',
          task: () => runPowerShellScript(path.join(scriptsDir, 'disable-touch-feedback.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Disabling Setup Prompts & OOBE',
          task: () => runPowerShellScript(path.join(scriptsDir, 'disable-win-setup-prompts.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Clearing Default Desktop Icons',
          task: () => runPowerShellScript(path.join(scriptsDir, 'clear-desktop-shortcuts.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Applying Solid Color Background',
          task: () => runPowerShellScript(path.join(scriptsDir, 'set-desktop-background.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Configuring Windows Dark Mode',
          task: () => runPowerShellScript(path.join(scriptsDir, 'enable-dark-mode.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Configuring File Explorer Defaults',
          task: () => runPowerShellScript(path.join(scriptsDir, 'config-explorer.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Disabling Automatic App Installs',
          task: () => runPowerShellScript(path.join(scriptsDir, 'disable-app-installs.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Disabling App Restore Features',
          task: () => runPowerShellScript(path.join(scriptsDir, 'disable-app-restore.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Disabling Windows Error Reporting',
          task: () => runPowerShellScript(path.join(scriptsDir, 'disable-error-reporting.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Disabling Network Firewalls',
          task: () => runPowerShellScript(path.join(scriptsDir, 'disable-firewall.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Enabling Win32 Long Paths Support',
          task: () => runPowerShellScript(path.join(scriptsDir, 'disable-max-path-length.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Disabling New Network Dialog Popups',
          task: () => runPowerShellScript(path.join(scriptsDir, 'disable-new-network-window.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Disabling Toast Notifications',
          task: () => runPowerShellScript(path.join(scriptsDir, 'disable-notifications.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Disabling Touchpad Edge Gestures',
          task: () => runPowerShellScript(path.join(scriptsDir, 'disable-touch-gestures.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Enabling PowerShell Script Execution',
          task: () => runPowerShellScript(path.join(scriptsDir, 'enable-script-execution.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Resetting Desktop Text Scale Factor',
          task: () => runPowerShellScript(path.join(scriptsDir, 'reset-text-scale.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Uninstalling Windows Bloatware',
          task: () => runPowerShellScript(path.join(scriptsDir, 'uninstall-bloatware.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Uninstalling Microsoft OneDrive',
          task: () => runPowerShellScript(path.join(scriptsDir, 'uninstall-one-drive.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Unpinning Default Start Menu Apps',
          task: () => runPowerShellScript(path.join(scriptsDir, 'unpin-start-menu-apps.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Configuring Active Power Scheme',
          task: () => runPowerShellScript(path.join(scriptsDir, 'set-power-settings.ps1'), resolvedConfigPath, undo, dryRun)
        }
      ], { concurrent: false })
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
          execSync('powershell -Command "Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue"', { stdio: 'ignore' });
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
        execSync('shutdown /r /t 0 /f', { stdio: 'ignore' });
      } else {
        outro(chalk.yellow('Restart skipped. Please restart manually for all changes to apply.'));
      }
    }
  } catch (err: any) {
    // Attempt rescue unmounting in case of failure
    if (hiveMounted && !dryRun) {
      try {
        execSync(`powershell -Command "& '${path.join(utilsDir, 'slab-unmount-hive.ps1')}' -MountName 'HKU\\DefaultUser'"`, { stdio: 'ignore' });
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
