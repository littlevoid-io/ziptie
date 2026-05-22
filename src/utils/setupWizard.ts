import * as fs from 'node:fs';
import { execSync } from 'node:child_process';
import { select, text, outro, note } from '@clack/prompts';
import chalk from 'chalk';
import deepmerge from 'deepmerge';

/**
 * Runs an interactive setup wizard if no user configuration is present.
 *
 * @param defaultConfigPath Path to the default slab configuration JSON file.
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
    message: 'How would you like to configure Slab?',
    options: [
      { value: 'defaults', label: 'Use defaults (quick start)', hint: 'Runs Slab with pre-configured stable settings' },
      { value: 'cli', label: 'Edit settings in the CLI', hint: 'Configure computer name, timezone, user, and startup task now' },
      { value: 'file', label: 'Create a config file', hint: 'Creates slab.config.json and opens it in your default editor' }
    ]
  });

  if (typeof action === 'symbol') {
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
        'Opening config file in your default editor...\nPlease customize your settings and run Slab again.',
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
      defaultValue: defaultConfig.system.computerName,
      validate(value) {
        if (value.trim().length === 0) return 'Computer name cannot be empty.';
        if (/[^a-zA-Z0-9-]/.test(value)) return 'Computer name can only contain alphanumeric characters and hyphens.';
      }
    });

    if (typeof computerName === 'symbol') {
      outro(chalk.yellow('Setup wizard cancelled.'));
      process.exit(0);
    }

    const timezone = await text({
      message: 'Enter system timezone (or "auto" to automatically detect):',
      placeholder: defaultConfig.system.timezone,
      defaultValue: defaultConfig.system.timezone,
      validate(value) {
        if (value.trim().length === 0) return 'Timezone cannot be empty.';
      }
    });

    if (typeof timezone === 'symbol') {
      outro(chalk.yellow('Setup wizard cancelled.'));
      process.exit(0);
    }

    const username = await text({
      message: 'Enter autologon low-privilege username:',
      placeholder: defaultConfig.autologon.username,
      defaultValue: defaultConfig.autologon.username,
      validate(value) {
        if (value.trim().length === 0) return 'Username cannot be empty.';
      }
    });

    if (typeof username === 'symbol') {
      outro(chalk.yellow('Setup wizard cancelled.'));
      process.exit(0);
    }

    const executable = await text({
      message: 'Enter exhibit startup executable/batch file name (relative to C:\\Exhibit):',
      placeholder: defaultConfig.startupTask.executable,
      defaultValue: defaultConfig.startupTask.executable,
      validate(value) {
        if (value.trim().length === 0) return 'Executable name cannot be empty.';
      }
    });

    if (typeof executable === 'symbol') {
      outro(chalk.yellow('Setup wizard cancelled.'));
      process.exit(0);
    }

    const workingDir = await text({
      message: 'Enter exhibit startup working directory:',
      placeholder: defaultConfig.startupTask.workingDir,
      defaultValue: defaultConfig.startupTask.workingDir,
      validate(value) {
        if (value.trim().length === 0) return 'Working directory cannot be empty.';
      }
    });

    if (typeof workingDir === 'symbol') {
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
