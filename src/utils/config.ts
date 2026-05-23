import * as fs from 'node:fs';
import * as path from 'node:path';
import chalk from 'chalk';
import deepmerge from 'deepmerge';
import { resolveProjectRoot } from './project.js';

export interface ConfigContext {
  projectRoot: string;
  resolvedConfigPath: string;
  config: any;
}

/**
 * Loads the default configuration, deep-merges it with user overrides
 * using the robust deepmerge library, and writes a temporary merged JSON payload.
 */
export function loadAndMergeConfig(
  customConfigPath: string | null,
  cliOverrides?: Record<string, any>
): ConfigContext {
  const projectRoot = resolveProjectRoot();
  const defaultConfigPath = path.join(projectRoot, 'ziptie.default.config.json');
  if (!fs.existsSync(defaultConfigPath)) {
    console.error(chalk.red(`Error: Missing default configuration at ${defaultConfigPath}`));
    process.exit(1);
  }

  let defaultConfig: any = {};
  try {
    defaultConfig = JSON.parse(fs.readFileSync(defaultConfigPath, 'utf8'));
  } catch (e: any) {
    console.error(chalk.red(`Error parsing default configuration: ${e.message}`));
    process.exit(1);
  }

  const configFilePath = customConfigPath
    ? path.resolve(customConfigPath)
    : path.resolve(process.cwd(), 'ziptie.config.json');

  let userConfig: any = {};
  if (fs.existsSync(configFilePath)) {
    try {
      userConfig = JSON.parse(fs.readFileSync(configFilePath, 'utf8'));
    } catch (e: any) {
      console.error(chalk.red(`Error parsing user config file: ${e.message}`));
      process.exit(1);
    }
  }

  const overwriteMerge = (destinationArray: any[], sourceArray: any[]) => sourceArray;
  let mergedConfig = deepmerge(defaultConfig, userConfig, { arrayMerge: overwriteMerge });
  if (cliOverrides && Object.keys(cliOverrides).length > 0) {
    mergedConfig = deepmerge(mergedConfig, cliOverrides, { arrayMerge: overwriteMerge });
  }

  const configDir = path.dirname(configFilePath);
  if (mergedConfig.packageManager && typeof mergedConfig.packageManager.localInstallersPath === 'string') {
    if (!path.isAbsolute(mergedConfig.packageManager.localInstallersPath)) {
      mergedConfig.packageManager.localInstallersPath = path.resolve(
        configDir,
        mergedConfig.packageManager.localInstallersPath
      );
    }
  }

  if (mergedConfig.startupTask && typeof mergedConfig.startupTask.workingDir === 'string') {
    if (!path.isAbsolute(mergedConfig.startupTask.workingDir)) {
      mergedConfig.startupTask.workingDir = path.resolve(
        configDir,
        mergedConfig.startupTask.workingDir
      );
    }
  }

  const tmpDir = path.resolve(process.cwd(), '.tmp');
  if (!fs.existsSync(tmpDir)) {
    fs.mkdirSync(tmpDir, { recursive: true });
  }

  const resolvedConfigPath = path.join(tmpDir, 'ziptie-temp-config.json');
  fs.writeFileSync(resolvedConfigPath, JSON.stringify(mergedConfig, null, 2), 'utf8');

  return {
    projectRoot,
    resolvedConfigPath,
    config: mergedConfig,
  };
}

export { resolveProjectRoot } from './project.js';
export { printConfig } from './printer.js';
export { handleAutoConfirmTimeout } from './timeout.js';
