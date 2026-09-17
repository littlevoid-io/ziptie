import * as fs from 'node:fs';
import * as path from 'node:path';
import { spinner } from '@clack/prompts';
import chalk from 'chalk';
import {
  SetupMode,
  getBatchTemplate,
  getConfigTemplate,
  getLaunchBatchTemplate,
  mergeConfig,
} from '../utils/templates.js';
import { downloadBinary } from '../utils/download.js';
import { loadExistingConfig } from '../utils/initDetection.js';
import { VERSION } from '../version.js';

export interface ScaffoldResult {
  configStatus: 'created' | 'updated' | 'skipped';
  batchCreated: boolean;
  launchCreated: boolean;
}

export function createInitNote(mode: SetupMode, res: ScaffoldResult): string {
  const configText =
    res.configStatus === 'created'
      ? 'created ziptie.config.json'
      : res.configStatus === 'updated'
        ? 'updated ziptie.config.json'
        : 'skipped (already exists)';
  return (
    `Mode: ${mode}\n` +
    `Config: ${configText}\n` +
    `Batch:  ${res.batchCreated ? 'created ziptie-setup.bat' : 'skipped (already exists)'}` +
    (res.launchCreated ? '\nLaunch: created launch.bat' : '')
  );
}

export function updatePackageManifest(targetDirectory: string): void {
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

export function writeScaffoldFiles(
  targetDir: string,
  mode: SetupMode,
  configOverrides: any,
  writeLaunchBatch: boolean,
  force: boolean,
  updateExisting = false
): ScaffoldResult {
  const configPath = path.join(targetDir, 'ziptie.config.json');
  const batchPath = path.join(targetDir, 'ziptie-setup.bat');
  const launchPath = path.join(targetDir, 'launch.bat');

  let configStatus: 'created' | 'updated' | 'skipped' = 'skipped';
  if (!fs.existsSync(configPath)) {
    fs.writeFileSync(configPath, getConfigTemplate(configOverrides), 'utf8');
    configStatus = 'created';
  } else if (force) {
    fs.writeFileSync(configPath, getConfigTemplate(configOverrides), 'utf8');
    configStatus = 'updated';
  } else if (updateExisting) {
    const existing = loadExistingConfig(targetDir) || {};
    fs.writeFileSync(configPath, mergeConfig(existing, configOverrides), 'utf8');
    configStatus = 'updated';
  }

  let batchCreated = false;
  if (!fs.existsSync(batchPath) || force) {
    fs.writeFileSync(batchPath, getBatchTemplate(mode), 'utf8');
    batchCreated = true;
  }
  let launchCreated = false;
  if (writeLaunchBatch && (!fs.existsSync(launchPath) || force)) {
    fs.writeFileSync(launchPath, getLaunchBatchTemplate(targetDir), 'utf8');
    launchCreated = true;
  }
  return { configStatus, batchCreated, launchCreated };
}

export async function handleModeSetup(
  targetDir: string,
  mode: SetupMode,
  force?: boolean
): Promise<void> {
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
