import * as fs from 'node:fs';
import * as path from 'node:path';
import { execSync } from 'node:child_process';
import { intro, outro, confirm } from '@clack/prompts';
import { Listr } from 'listr2';
import chalk from 'chalk';

import { ensureElevated } from './utils/elevation.js';
import { runPowerShellScript } from './utils/powershell.js';
import { loadAndMergeConfig, resolveProjectRoot, printConfig, handleAutoConfirmTimeout } from './utils/config.js';
import { runSetupWizard } from './utils/setupWizard.js';
import { OS_LOCKDOWN_TASKS } from './tasks.js';
import { parseCLI } from './utils/cli.js';

// Parse command line arguments and overrides using yargs
const { dryRun, undo, customConfigPath, autoConfirm, overrides } = parseCLI();

async function main() {
  if (process.platform !== 'win32') {
    console.error(chalk.red('Error: Ziptie currently only supports Windows.'));
    process.exit(1);
  }


  // 1. Elevate process if not Administrator and not a DryRun
  ensureElevated(dryRun);

  if (dryRun) {
    intro(chalk.bold.yellow(' 🪢 Ziptie Setup (DRY RUN MODE - Read Only)'));
  } else {
    intro(chalk.bold.cyan(' 🪢 Ziptie Setup'));
  }

  // Check if no user config exists and we are run interactively
  const expectedConfigPath = customConfigPath
    ? path.resolve(customConfigPath)
    : path.resolve(process.cwd(), 'ziptie.config.json');

  if (!fs.existsSync(expectedConfigPath) && !customConfigPath && !autoConfirm) {
    const rootDir = resolveProjectRoot();
    const defaultConfigPath = path.join(rootDir, 'ziptie.default.config.json');
    await runSetupWizard(defaultConfigPath, expectedConfigPath);
  }

  // 2. Load and deep-merge default/user configurations with CLI overrides
  const { projectRoot, resolvedConfigPath, config } = loadAndMergeConfig(customConfigPath, overrides);

  // Print final composited config settings
  printConfig(config);

  // Verify and confirm
  const actionMessage = dryRun
    ? 'Ready to perform a safe dry-run validation?'
    : (undo ? 'Ready to revert all configurations?' : 'Ready to lock down this system?');
  let proceed: boolean | symbol = true;
  if (!autoConfirm) {
    proceed = await confirm({
      message: actionMessage,
      initialValue: true,
    });
  } else {
    await handleAutoConfirmTimeout(10);
  }

  if (typeof proceed === 'symbol' || !proceed) {
    outro(chalk.yellow('Operation cancelled. No changes were made.'));
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
          throw new Error('Ziptie only supports Windows.');
        }
      }
    },
    {
      title: 'System Setup',
      task: (ctx, task) => task.newListr([
        {
          title: 'Configuring timezone',
          task: () => runPowerShellScript(path.join(scriptsDir, 'set-timezone.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Configuring computer name',
          task: () => runPowerShellScript(path.join(scriptsDir, 'set-computer-name.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Scheduling daily reboot',
          task: () => runPowerShellScript(path.join(scriptsDir, 'enable-daily-reboot.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Configuring autologon',
          task: () => runPowerShellScript(path.join(scriptsDir, 'enable-auto-login.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Setting up startup task',
          task: () => runPowerShellScript(path.join(scriptsDir, 'enable-startup-task.ps1'), resolvedConfigPath, undo, dryRun)
        },
        {
          title: 'Installing local apps',
          task: () => runPowerShellScript(path.join(scriptsDir, 'install-local-apps.ps1'), resolvedConfigPath, undo, dryRun)
        }
      ], { concurrent: false })
    },
    {
      title: 'Mounting default user registry',
      skip: () => dryRun,
      task: async () => {
        await runPowerShellScript(
          path.join(utilsDir, 'ziptie-mount-hive.ps1'),
          resolvedConfigPath,
          undo,
          dryRun,
          ['-MountName', 'HKU\\DefaultUser', '-HivePath', 'C:\\Users\\Default\\NTUSER.DAT']
        );
        hiveMounted = true;
      }
    },
    {
      title: 'Applying lockdowns',
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
      title: 'Unmounting default user registry',
      skip: () => dryRun || !hiveMounted,
      task: async () => {
        await runPowerShellScript(
          path.join(utilsDir, 'ziptie-unmount-hive.ps1'),
          resolvedConfigPath,
          undo,
          dryRun,
          ['-MountName', 'HKU\\DefaultUser']
        );
        hiveMounted = false;
      }
    },
    {
      title: 'Restarting Windows Shell',
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
    if (dryRun) {
      outro(chalk.bold.yellow(' ✅ Dry run verification complete. No system changes were made.'));
    } else if (undo) {
      outro(chalk.bold.green(' ✅ Revert complete.'));
    } else {
      outro(chalk.bold.green(' ✅ System locked down.'));
    }

    if (!dryRun && !autoConfirm) {
      console.log('');
      const result = await confirm({
        message: 'Reboot computer now?',
        initialValue: true
      });

      if (typeof result === 'boolean' && result) {
        outro(chalk.bold.green(' 🔄 Rebooting... '));
        execSync('shutdown /r /t 0 /f', { stdio: 'ignore', windowsHide: true });
      } else {
        outro(chalk.yellow('Reboot skipped. Please reboot manually.'));
      }
    }
  } catch (err: any) {
    // Attempt rescue unmounting in case of failure
    if (hiveMounted && !dryRun) {
      try {
        execSync(`powershell -Command "& '${path.join(utilsDir, 'ziptie-unmount-hive.ps1')}' -MountName 'HKU\\DefaultUser'"`, { stdio: 'ignore', windowsHide: true });
      } catch {
        // Suppress secondary failures
      }
    }
    outro(chalk.bold.red(` ❌ Execution failed: ${err.message}`));
    process.exit(1);
  }
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
