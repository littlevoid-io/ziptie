import * as fs from 'node:fs';
import * as path from 'node:path';
import { intro, outro, select, isCancel, note } from '@clack/prompts';
import chalk from 'chalk';
import { SetupMode } from '../utils/templates.js';
import {
  detectStartupDetails,
  loadExistingConfig,
  DetectedStartup,
} from '../utils/initDetection.js';
import {
  promptComputerName,
  promptConfirmLaunchBatch,
  promptConfirmConfigUpdate,
  promptStartupTask,
} from '../utils/promptHelpers.js';
import { writeScaffoldFiles, handleModeSetup, createInitNote } from './scaffold.js';

export interface InitOptions {
  projectRoot?: string;
  mode?: SetupMode;
  force?: boolean;
  autoConfirm?: boolean;
  interactive?: boolean;
}

const MODE_OPTIONS = [
  { value: 'online', label: 'Online bootstrap', hint: 'PowerShell downloads latest release' },
  {
    value: 'offline',
    label: 'Offline standalone',
    hint: 'Download ziptie.exe for air-gapped setup',
  },
  { value: 'npm', label: 'npm package', hint: 'Execute via npx @littlevoid/ziptie' },
];

async function resolveSetupMode(options: InitOptions): Promise<SetupMode | null> {
  if (options.mode && ['offline', 'online', 'npm'].includes(options.mode)) {
    return options.mode;
  }
  if (options.autoConfirm || options.interactive === false) return 'online';
  const selected = await select({
    message: 'Select target execution mode:',
    options: MODE_OPTIONS,
  });
  return isCancel(selected) ? null : (selected as SetupMode);
}

function getInitialConfig(existingConfig: any | null, startup: DetectedStartup) {
  return {
    system: { computerName: existingConfig?.system?.computerName || 'auto' },
    startupTask: {
      executable: existingConfig?.startupTask?.executable || startup.executable,
      args: existingConfig?.startupTask?.args || startup.args,
      workingDir: existingConfig?.startupTask?.workingDir || 'auto',
    },
  };
}

async function promptInitAnswers(
  targetDir: string,
  startup: DetectedStartup,
  existingConfig: any | null
): Promise<{ config: any; createLaunchBatch: boolean } | null> {
  const defaultComputer = existingConfig?.system?.computerName || 'auto';
  const computerName = await promptComputerName(defaultComputer);
  if (computerName === null) return null;

  const task = await promptStartupTask({
    executable: existingConfig?.startupTask?.executable || startup.executable,
    args: existingConfig?.startupTask?.args || startup.args,
    workingDir: existingConfig?.startupTask?.workingDir || 'auto',
  });
  if (!task) return null;

  let createLaunchBatch = false;
  if (startup.offerBatch && task.executable === 'launch.bat') {
    const existing = fs.existsSync(path.join(targetDir, 'launch.bat'));
    if (!existing) {
      const confirmed = await promptConfirmLaunchBatch('launch.bat');
      if (confirmed === null) return null;
      createLaunchBatch = confirmed;
    }
  }

  return {
    config: { system: { computerName }, startupTask: task },
    createLaunchBatch,
  };
}

async function resolveInitConfig(
  targetDir: string,
  options: InitOptions,
  existingConfig: any | null
): Promise<{ config: any; createLaunchBatch: boolean; updateExisting: boolean } | null> {
  const startup = detectStartupDetails(targetDir);
  const isInteractive = !options.autoConfirm && options.interactive !== false;
  let updateExisting = Boolean(options.force);
  if (!isInteractive) {
    return {
      config: getInitialConfig(existingConfig, startup),
      createLaunchBatch: false,
      updateExisting,
    };
  }
  if (existingConfig && !options.force) {
    const confirmUpdate = await promptConfirmConfigUpdate();
    if (confirmUpdate === null) return null;
    updateExisting = confirmUpdate;
  }
  const answers = await promptInitAnswers(targetDir, startup, existingConfig);
  return answers ? { ...answers, updateExisting } : null;
}

export async function runInit(options: InitOptions = {}): Promise<number> {
  intro(chalk.bold.cyan(' 🪢 Ziptie Initialization'));
  const targetDir = path.resolve(options.projectRoot || process.cwd());
  if (!fs.existsSync(targetDir)) fs.mkdirSync(targetDir, { recursive: true });

  const mode = await resolveSetupMode(options);
  if (!mode) {
    outro(chalk.yellow('Initialization cancelled.'));
    return 0;
  }

  const existingConfig = loadExistingConfig(targetDir);
  const resolved = await resolveInitConfig(targetDir, options, existingConfig);
  if (!resolved) {
    outro(chalk.yellow('Initialization cancelled.'));
    return 0;
  }

  const result = writeScaffoldFiles(
    targetDir,
    mode,
    resolved.config,
    resolved.createLaunchBatch,
    Boolean(options.force),
    resolved.updateExisting
  );
  await handleModeSetup(targetDir, mode, options.force);
  note(createInitNote(mode, result), 'Scaffold Summary');
  outro(chalk.bold.green(' ✅ Project initialized for Ziptie.'));
  return 0;
}
