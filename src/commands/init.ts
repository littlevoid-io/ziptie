import * as fs from 'node:fs';
import * as path from 'node:path';
import { intro, outro, select, isCancel, spinner, note } from '@clack/prompts';
import chalk from 'chalk';
import { SetupMode, getBatchTemplate, getConfigTemplate } from '../utils/templates.js';
import { downloadBinary } from '../utils/download.js';
import { VERSION } from '../version.js';

export interface InitOptions {
  projectRoot?: string;
  mode?: SetupMode;
  force?: boolean;
  autoConfirm?: boolean;
}

const MODE_OPTIONS = [
  {
    value: 'online',
    label: 'Online bootstrap',
    hint: 'PowerShell downloads latest release on exhibit PC',
  },
  {
    value: 'offline',
    label: 'Offline standalone',
    hint: 'Download ziptie.exe now for air-gapped installation',
  },
  { value: 'npm', label: 'npm package', hint: 'Execute via npx @littlevoid/ziptie' },
];

function detectComputerName(targetDirectory: string): string {
  const packagePath = path.join(targetDirectory, 'package.json');
  if (fs.existsSync(packagePath)) {
    try {
      const pkg = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
      if (pkg.name) {
        const cleanName = pkg.name.replace(/^@[^/]+\//, '').replace(/[^a-zA-Z0-9-]/g, '-');
        return `${cleanName}-01`;
      }
    } catch {
      // Fall back to default
    }
  }
  return 'exhibit-pc-01';
}

function updatePackageManifest(targetDirectory: string): void {
  const packagePath = path.join(targetDirectory, 'package.json');
  if (!fs.existsSync(packagePath)) return;
  try {
    const pkg = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
    pkg.devDependencies = pkg.devDependencies || {};
    pkg.devDependencies['@littlevoid/ziptie'] = `^${VERSION}`;
    fs.writeFileSync(packagePath, JSON.stringify(pkg, null, 2) + '\n', 'utf8');
  } catch {
    // Suppress write failures
  }
}

async function resolveSetupMode(options: InitOptions): Promise<SetupMode | null> {
  if (options.mode && ['offline', 'online', 'npm'].includes(options.mode)) {
    return options.mode;
  }
  if (options.autoConfirm) return 'online';
  const selected = await select({
    message: 'Select target execution mode:',
    options: MODE_OPTIONS,
  });
  return isCancel(selected) ? null : (selected as SetupMode);
}

function writeScaffoldFiles(
  targetDir: string,
  mode: SetupMode,
  force: boolean
): { configCreated: boolean; batchCreated: boolean } {
  const configPath = path.join(targetDir, 'ziptie.config.json');
  const batchPath = path.join(targetDir, 'ziptie-setup.bat');
  let configCreated = false;
  if (!fs.existsSync(configPath) || force) {
    fs.writeFileSync(configPath, getConfigTemplate(detectComputerName(targetDir)), 'utf8');
    configCreated = true;
  }
  let batchCreated = false;
  if (!fs.existsSync(batchPath) || force) {
    fs.writeFileSync(batchPath, getBatchTemplate(mode), 'utf8');
    batchCreated = true;
  }
  return { configCreated, batchCreated };
}

async function handleModeSetup(targetDir: string, mode: SetupMode, force?: boolean): Promise<void> {
  if (mode === 'offline') {
    const exePath = path.join(targetDir, 'ziptie.exe');
    if (!fs.existsSync(exePath) || force) {
      const s = spinner();
      s.start('Downloading standalone ziptie.exe release...');
      try {
        await downloadBinary(exePath);
        s.stop('Downloaded ziptie.exe');
      } catch (err: any) {
        s.stop(chalk.red(`Failed to download binary: ${err.message}`));
      }
    }
  } else if (mode === 'npm') {
    updatePackageManifest(targetDir);
  }
}

export async function runInit(options: InitOptions = {}): Promise<number> {
  intro(chalk.bold.cyan(' 🪢 Ziptie Initialization'));
  const targetDir = path.resolve(options.projectRoot || process.cwd());
  if (!fs.existsSync(targetDir)) {
    fs.mkdirSync(targetDir, { recursive: true });
  }
  const mode = await resolveSetupMode(options);
  if (!mode) {
    outro(chalk.yellow('Initialization cancelled.'));
    return 0;
  }
  const { configCreated, batchCreated } = writeScaffoldFiles(
    targetDir,
    mode,
    Boolean(options.force)
  );
  await handleModeSetup(targetDir, mode, options.force);
  note(
    `Mode: ${mode}\n` +
      `Config: ${configCreated ? 'created ziptie.config.json' : 'skipped (already exists)'}\n` +
      `Batch:  ${batchCreated ? 'created ziptie-setup.bat' : 'skipped (already exists)'}`,
    'Scaffold Summary'
  );
  outro(chalk.bold.green(' ✅ Project initialized for Ziptie.'));
  return 0;
}
