import * as fs from 'node:fs';
import * as path from 'node:path';
import { execSync } from 'node:child_process';
import { intro, outro, confirm } from '@clack/prompts';
import { Listr } from 'listr2';
import chalk from 'chalk';

import { ensureElevated } from './utils/elevation.js';
import { runPowerShellScript } from './utils/powershell.js';
import { loadAndMergeConfig, resolveProjectRoot } from './utils/config.js';
import { runSetupWizard } from './utils/setupWizard.js';
import { OS_LOCKDOWN_TASKS } from './tasks.js';

// Parse command line arguments
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

  // 1. Elevate process if not Administrator and not a DryRun
  ensureElevated(dryRun);

  intro(chalk.bold.cyan('----------------------------'));
  intro(chalk.bold.cyan(' 🧱 SLAB SYSTEM LOCKDOWN 🧱'));
  intro(chalk.bold.cyan('----------------------------'));

  // Check if no user config exists and we are run interactively
  const expectedConfigPath = customConfigPath
    ? path.resolve(customConfigPath)
    : path.resolve(process.cwd(), 'slab.config.json');

  if (!fs.existsSync(expectedConfigPath) && !customConfigPath && !autoConfirm) {
    const rootDir = resolveProjectRoot();
    const defaultConfigPath = path.join(rootDir, 'slab.default.config.json');
    await runSetupWizard(defaultConfigPath, expectedConfigPath);
  }

  // 2. Load and deep-merge default/user configurations
  const { projectRoot, resolvedConfigPath, config } = loadAndMergeConfig(customConfigPath);

  // Verify and confirm
  const actionName = undo ? 'Undo Lockdown ↩️' : 'Start Lockdown 🔒';
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
  const utilsDir = path.join(projectRoot, 'scripts', 'utils');

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
    outro(chalk.bold.green(' ✅ Slab lockdown done! '));

    if (!dryRun && !autoConfirm) {
      console.log('');
      const result = await confirm({
        message: 'Restart computer now?',
        initialValue: true
      });

      if (typeof result === 'boolean' && result) {
        outro(chalk.bold.green(' 🔄 Restarting now... '));
        execSync('shutdown /r /t 0 /f', { stdio: 'ignore', windowsHide: true });
      } else {
        outro(chalk.yellow('Restart skipped. Restart manually for changes to apply.'));
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
    outro(chalk.bold.red(` ❌ Slab execution encountered errors: ${err.message}`));
    process.exit(1);
  }
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
