import * as fs from 'node:fs';
import * as path from 'node:path';
import { execSync } from 'node:child_process';
import { select, outro, note, isCancel } from '@clack/prompts';
import chalk from 'chalk';
import deepmerge from 'deepmerge';
import {
  promptComputerName,
  promptTimezone,
  promptUsername,
  promptExecutable,
  promptWorkingDir,
} from './promptHelpers.js';

function ensureParentDirectory(filePath: string): void {
  try {
    const parentDir = path.dirname(filePath);
    if (parentDir && !fs.existsSync(parentDir)) {
      fs.mkdirSync(parentDir, { recursive: true });
    }
  } catch {
    // Fail silently, error handled during write
  }
}

function handleFileAction(defaultConfigPath: string, userConfigPath: string): void {
  try {
    fs.copyFileSync(defaultConfigPath, userConfigPath);
    outro(chalk.green(`Created configuration file at: ${userConfigPath}`));
    note(
      'Opening config file in your default editor...\nPlease customize your settings and run Ziptie again.',
      'File Created Successfully'
    );
    try {
      execSync(`start "" "${userConfigPath}"`, { shell: 'cmd.exe', stdio: 'ignore' });
    } catch {
      // Ignore editor open failure
    }
    process.exit(0);
  } catch (e: any) {
    console.error(chalk.red(`Error creating configuration file: ${e.message}`));
    process.exit(1);
  }
}

async function promptCliConfiguration(defaultConfig: any): Promise<any> {
  const computerName = await promptComputerName(defaultConfig.system?.computerName);
  if (computerName === null) return null;

  const timezone = await promptTimezone(defaultConfig.system?.timezone);
  if (timezone === null) return null;

  const username = await promptUsername(defaultConfig.autologon?.username);
  if (username === null) return null;

  const executable = await promptExecutable(defaultConfig.startupTask?.executable);
  if (executable === null) return null;

  const workingDir = await promptWorkingDir(defaultConfig.startupTask?.workingDir);
  if (workingDir === null) return null;

  return {
    system: { computerName, timezone },
    autologon: { username },
    startupTask: { executable, workingDir },
  };
}

export async function runSetupWizard(
  defaultConfigPath: string,
  userConfigPath: string
): Promise<any> {
  ensureParentDirectory(userConfigPath);
  let defaultConfig: any = {};
  try {
    defaultConfig = JSON.parse(fs.readFileSync(defaultConfigPath, 'utf8'));
  } catch (e: any) {
    console.error(chalk.red(`Error reading default configuration: ${e.message}`));
    process.exit(1);
  }

  note(chalk.yellow(`No configuration found at:\n${userConfigPath}`), '🪢 Ziptie Setup');

  const action = await select({
    message: 'How would you like to configure Ziptie?',
    options: [
      {
        value: 'defaults',
        label: 'Use default settings',
        hint: 'Apply standard pre-configured settings',
      },
      {
        value: 'cli',
        label: 'Configure interactively',
        hint: 'Set computer name, timezone, user, and startup task',
      },
      {
        value: 'file',
        label: 'Create config file',
        hint: 'Generate ziptie.config.json and open in editor',
      },
    ],
  });

  if (isCancel(action)) {
    outro(chalk.yellow('Setup cancelled.'));
    process.exit(0);
  }
  if (action === 'defaults') return defaultConfig;
  if (action === 'file') handleFileAction(defaultConfigPath, userConfigPath);

  const customConfig = await promptCliConfiguration(defaultConfig);
  if (!customConfig) {
    outro(chalk.yellow('Setup cancelled.'));
    process.exit(0);
  }

  const finalConfig = deepmerge(defaultConfig, customConfig);
  try {
    fs.writeFileSync(userConfigPath, JSON.stringify(finalConfig, null, 2), 'utf8');
    note(`Successfully saved settings to:\n${userConfigPath}`, '🪢 Configuration Saved');
    return finalConfig;
  } catch (e: any) {
    console.error(chalk.red(`Error writing user configuration: ${e.message}`));
    process.exit(1);
  }
}
