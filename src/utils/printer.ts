import * as fs from 'node:fs';
import * as path from 'node:path';
import chalk from 'chalk';
import { resolveProjectRoot } from './project.js';

/**
 * Helper to recursively or shallowly compare two configuration values (supports arrays).
 */
function isEqual(val1: any, val2: any): boolean {
  if (Array.isArray(val1) && Array.isArray(val2)) {
    if (val1.length !== val2.length) return false;
    return val1.every((item, index) => item === val2[index]);
  }
  return val1 === val2;
}

/**
 * Formats a configuration value with premium Chalk coloring.
 */
function formatValue(value: any): string {
  if (typeof value === 'string') {
    return chalk.yellow(`"${value}"`);
  }
  if (typeof value === 'boolean') {
    return chalk.magenta(value);
  }
  if (typeof value === 'number') {
    return chalk.blue(value);
  }
  if (Array.isArray(value)) {
    return chalk.white(`[${value.map(v => typeof v === 'string' ? `"${v}"` : String(v)).join(', ')}]`);
  }
  if (value === undefined || value === null) {
    return chalk.dim('undefined');
  }
  return chalk.white(JSON.stringify(value));
}

/**
 * Beautifully pretty-prints only the configuration settings that differ from the defaults.
 */
export function printConfig(config: any, customConfigPath: string | null = null): void {
  console.log(chalk.bold.cyan('\n⚙️  Composited Configuration Settings (Overrides from Defaults):'));

  const projectRoot = resolveProjectRoot();
  const defaultConfigPath = path.join(projectRoot, 'ziptie.default.config.json');

  let defaultConfig: any = {};
  if (fs.existsSync(defaultConfigPath)) {
    try {
      defaultConfig = JSON.parse(fs.readFileSync(defaultConfigPath, 'utf8'));
    } catch {
      // ignore
    }
  }

  const configFilePath = customConfigPath
    ? path.resolve(customConfigPath)
    : path.resolve(process.cwd(), 'ziptie.config.json');
  const configDir = path.dirname(configFilePath);

  if (defaultConfig.packageManager && typeof defaultConfig.packageManager.localInstallersPath === 'string') {
    if (!path.isAbsolute(defaultConfig.packageManager.localInstallersPath)) {
      defaultConfig.packageManager.localInstallersPath = path.resolve(
        configDir,
        defaultConfig.packageManager.localInstallersPath
      );
    }
  }

  if (defaultConfig.startupTask && typeof defaultConfig.startupTask.workingDir === 'string') {
    if (!path.isAbsolute(defaultConfig.startupTask.workingDir)) {
      defaultConfig.startupTask.workingDir = path.resolve(
        configDir,
        defaultConfig.startupTask.workingDir
      );
    }
  }

  const categories = ['system', 'autologon', 'startupTask', 'packageManager', 'lockdown'];
  let totalChanges = 0;

  for (const cat of categories) {
    const defaultCat = defaultConfig[cat] || {};
    const configCat = config[cat] || {};

    const differingKeys = Object.keys(configCat).filter(key => {
      return !isEqual(configCat[key], defaultCat[key]);
    });

    if (differingKeys.length > 0) {
      totalChanges += differingKeys.length;
      
      const catTitle = cat.charAt(0).toUpperCase() + cat.slice(1);
      console.log(`\n  ${chalk.bold.blue(`[${catTitle} Settings]`)}`);

      const maxKeyLen = Math.max(...differingKeys.map(k => k.length));

      for (const key of differingKeys) {
        const val = configCat[key];
        const defaultVal = defaultCat[key];
        const padding = ' '.repeat(maxKeyLen - key.length);

        console.log(
          `    ${chalk.green(key)}:${padding} ${formatValue(val)}   ${chalk.dim(`(Default: ${formatValue(defaultVal)})`)}`
        );
      }
    }
  }

  if (totalChanges === 0) {
    console.log(chalk.dim('\n   (Using all default system and lockdown settings - no overrides detected)'));
  }
  console.log('');
}
