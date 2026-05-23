import * as fs from 'node:fs';
import { execSync } from 'node:child_process';
import { select, text, outro, note, isCancel } from '@clack/prompts';
import chalk from 'chalk';
import deepmerge from 'deepmerge';

/**
 * Runs an interactive setup wizard if no user configuration is present.
 *
 * @param defaultConfigPath Path to the default ziptie configuration JSON file.
 * @param userConfigPath Path to write the user-customized config to.
 */
export async function runSetupWizard(defaultConfigPath: string, userConfigPath: string): Promise<any> {
  // Load defaults
  let defaultConfig: any = {};
  try {
    defaultConfig = JSON.parse(fs.readFileSync(defaultConfigPath, 'utf8'));
  } catch (e: any) {
    console.error(chalk.red(`Error reading default configuration: ${e.message}`));
    process.exit(1);
  }

  note(
    chalk.yellow(`No local configuration file found at:\n${userConfigPath}`),
    'Initial Setup Assistant'
  );

  const action = await select({
    message: 'How would you like to configure Ziptie?',
    options: [
      { value: 'defaults', label: 'Use defaults (quick start)', hint: 'Runs Ziptie with pre-configured stable settings' },
      { value: 'cli', label: 'Edit settings in the CLI', hint: 'Configure computer name, timezone, user, and startup task now' },
      { value: 'file', label: 'Create a config file', hint: 'Creates ziptie.config.json and opens it in your default editor' }
    ]
  });

  if (isCancel(action)) {
    outro(chalk.yellow('Setup wizard cancelled.'));
    process.exit(0);
  }

  if (action === 'defaults') {
    return defaultConfig;
  }

  if (action === 'file') {
    try {
      fs.copyFileSync(defaultConfigPath, userConfigPath);
      outro(chalk.green(`Created configuration file at: ${userConfigPath}`));
      
      note(
        'Opening config file in your default editor...\nPlease customize your settings and run Ziptie again.',
        'File Created Successfully'
      );
      
      // Open in default editor using Windows 'start' command
      try {
        execSync(`start "" "${userConfigPath}"`, { shell: 'cmd.exe', stdio: 'ignore' });
      } catch {
        // Fallback or ignore if open fails
      }
      
      process.exit(0);
    } catch (e: any) {
      console.error(chalk.red(`Error creating configuration file: ${e.message}`));
      process.exit(1);
    }
  }

  if (action === 'cli') {
    const computerName = await text({
      message: 'Enter computer name:',
      placeholder: defaultConfig.system.computerName,
      initialValue: defaultConfig.system.computerName,
      validate(value) {
        if (value.trim().length === 0) return 'Computer name cannot be empty.';
        if (/[^a-zA-Z0-9-]/.test(value)) return 'Computer name can only contain alphanumeric characters and hyphens.';
      }
    });

    if (isCancel(computerName)) {
      outro(chalk.yellow('Setup wizard cancelled.'));
      process.exit(0);
    }

    const timezone = await text({
      message: 'Enter system timezone (or "auto" to automatically detect):',
      placeholder: defaultConfig.system.timezone,
      initialValue: defaultConfig.system.timezone,
      validate(value) {
        if (value.trim().length === 0) return 'Timezone cannot be empty.';
      }
    });

    if (isCancel(timezone)) {
      outro(chalk.yellow('Setup wizard cancelled.'));
      process.exit(0);
    }

    const username = await text({
      message: 'Enter autologon low-privilege username:',
      placeholder: defaultConfig.autologon.username,
      initialValue: defaultConfig.autologon.username,
      validate(value) {
        if (value.trim().length === 0) return 'Username cannot be empty.';
      }
    });

    if (isCancel(username)) {
      outro(chalk.yellow('Setup wizard cancelled.'));
      process.exit(0);
    }

    const executable = await text({
      message: 'Enter exhibit startup executable/batch file name (relative to C:\\Exhibit):',
      placeholder: defaultConfig.startupTask.executable,
      initialValue: defaultConfig.startupTask.executable,
      validate(value) {
        if (value.trim().length === 0) return 'Executable name cannot be empty.';
      }
    });

    if (isCancel(executable)) {
      outro(chalk.yellow('Setup wizard cancelled.'));
      process.exit(0);
    }

    const workingDir = await text({
      message: 'Enter exhibit startup working directory:',
      placeholder: defaultConfig.startupTask.workingDir,
      initialValue: defaultConfig.startupTask.workingDir,
      validate(value) {
        if (value.trim().length === 0) return 'Working directory cannot be empty.';
      }
    });

    if (isCancel(workingDir)) {
      outro(chalk.yellow('Setup wizard cancelled.'));
      process.exit(0);
    }

    // Merge answers into defaultConfig
    const customConfig = {
      system: {
        computerName,
        timezone,
      },
      autologon: {
        username,
      },
      startupTask: {
        executable,
        workingDir,
      }
    };

    const finalConfig = deepmerge(defaultConfig, customConfig);

    try {
      fs.writeFileSync(userConfigPath, JSON.stringify(finalConfig, null, 2), 'utf8');
      note(
        `Successfully wrote customized settings to:\n${userConfigPath}`,
        'Configuration Saved'
      );
      return finalConfig;
    } catch (e: any) {
      console.error(chalk.red(`Error writing user configuration: ${e.message}`));
      process.exit(1);
    }
  }
}
