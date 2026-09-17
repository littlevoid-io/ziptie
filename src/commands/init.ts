import * as fs from 'node:fs';
import * as path from 'node:path';
import { intro, outro, select, isCancel, note } from '@clack/prompts';
import chalk from 'chalk';
import { SetupMode } from '../utils/templates.js';
import { detectStartupDetails, DetectedStartup } from '../utils/initDetection.js';
import {
  promptComputerName,
  promptExecutable,
  promptArgs,
  promptWorkingDir,
  promptConfirmLaunchBatch,
} from '../utils/promptHelpers.js';
import { writeScaffoldFiles, handleModeSetup } from './scaffold.js';

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

async function promptInitAnswers(
  targetDir: string,
  startup: DetectedStartup
): Promise<{ config: any; createLaunchBatch: boolean } | null> {
  const computerName = await promptComputerName('auto');
  if (computerName === null) return null;

  const executable = await promptExecutable(startup.executable);
  if (executable === null) return null;

  const args = await promptArgs(startup.args.join(' '));
  if (args === null) return null;

  const workingDir = await promptWorkingDir('auto');
  if (workingDir === null) return null;

  let createLaunchBatch = false;
  if (startup.offerBatch && executable === 'launch.bat') {
    const existing = fs.existsSync(path.join(targetDir, 'launch.bat'));
    if (!existing) {
      const confirmed = await promptConfirmLaunchBatch('launch.bat');
      if (confirmed === null) return null;
      createLaunchBatch = confirmed;
    }
  }

  return {
    config: {
      system: { computerName },
      startupTask: { executable, args, workingDir },
    },
    createLaunchBatch,
  };
}

function createInitNote(
  mode: SetupMode,
  res: { configCreated: boolean; batchCreated: boolean; launchCreated: boolean }
): string {
  return (
    `Mode: ${mode}\n` +
    `Config: ${res.configCreated ? 'created ziptie.config.json' : 'skipped (already exists)'}\n` +
    `Batch:  ${res.batchCreated ? 'created ziptie-setup.bat' : 'skipped (already exists)'}` +
    (res.launchCreated ? '\nLaunch: created launch.bat' : '')
  );
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

  const startup = detectStartupDetails(targetDir);
  let initAnswers = {
    config: {
      system: { computerName: 'auto' },
      startupTask: { executable: startup.executable, args: startup.args, workingDir: 'auto' },
    },
    createLaunchBatch: false,
  };

  const isInteractive = !options.autoConfirm && options.interactive !== false;
  if (isInteractive) {
    const answers = await promptInitAnswers(targetDir, startup);
    if (!answers) {
      outro(chalk.yellow('Initialization cancelled.'));
      return 0;
    }
    initAnswers = answers;
  }

  const result = writeScaffoldFiles(
    targetDir,
    mode,
    initAnswers.config,
    initAnswers.createLaunchBatch,
    Boolean(options.force)
  );

  await handleModeSetup(targetDir, mode, options.force);
  note(createInitNote(mode, result), 'Scaffold Summary');
  outro(chalk.bold.green(' ✅ Project initialized for Ziptie.'));
  return 0;
}
