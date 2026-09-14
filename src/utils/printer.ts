import * as fs from 'node:fs';
import * as path from 'node:path';
import chalk from 'chalk';
import { resolveProjectRoot } from './project.js';

function toUserFriendlyLabel(key: string): string {
  const spaced = key.replace(/([A-Z])/g, ' $1');
  const result = spaced.replace(/([A-Z])\s(?=[A-Z])/g, '$1');
  return result.charAt(0).toUpperCase() + result.slice(1).trim();
}

function isEqual(val1: any, val2: any, key?: string): boolean {
  if (Array.isArray(val1) && Array.isArray(val2)) {
    if (val1.length !== val2.length) return false;
    if (key === 'apps') {
      const s1 = [...val1].sort((a, b) => String(a).localeCompare(String(b)));
      const s2 = [...val2].sort((a, b) => String(a).localeCompare(String(b)));
      return s1.every((item, index) => item === s2[index]);
    }
    return val1.every((item, index) => item === val2[index]);
  }
  return val1 === val2;
}

function formatValue(value: any): string {
  if (typeof value === 'string') return `"${value}"`;
  if (typeof value === 'boolean') return String(value);
  if (typeof value === 'number') return String(value);
  if (Array.isArray(value)) {
    const formatted = value.map((v) => (typeof v === 'string' ? `"${v}"` : String(v)));
    return `[${formatted.join(', ')}]`;
  }
  if (value === undefined || value === null) return 'undefined';
  return JSON.stringify(value);
}

function formatSettingLine(
  key: string,
  val: any,
  defaultVal: any,
  isCustom: boolean,
  padding: string,
): string {
  const label = toUserFriendlyLabel(key);
  const formattedVal = formatValue(val);
  if (isCustom) {
    const customText = chalk.yellow(`${label}:${padding} ${formattedVal}`);
    const defaultText = chalk.dim(` (default: ${formatValue(defaultVal)})`);
    return `  ${customText}${defaultText}`;
  }
  return chalk.dim(`  ${label}:${padding} ${formattedVal}`);
}

function printCategory(title: string, configCat: any, defaultCat: any): void {
  console.log(`\n${chalk.bold(`${title}:`)}`);
  const keys = Object.keys(configCat);
  if (keys.length === 0) return;
  const customs = keys.filter((k) => !isEqual(configCat[k], defaultCat[k], k));
  const defaults = keys.length - customs.length;
  if (customs.length > 0) {
    const maxLen = Math.max(...customs.map((k) => toUserFriendlyLabel(k).length));
    for (const k of customs) {
      const pad = ' '.repeat(maxLen - toUserFriendlyLabel(k).length);
      console.log(formatSettingLine(k, configCat[k], defaultCat[k], true, pad));
    }
  }
  if (defaults > 0) {
    console.log(chalk.dim(`  Applying ${defaults} default setting${defaults === 1 ? '' : 's'}`));
  }
}

function loadDefaultConfig(): any {
  const projectRoot = resolveProjectRoot();
  const configPath = path.join(projectRoot, 'ziptie.default.config.json');
  if (fs.existsSync(configPath)) {
    try {
      return JSON.parse(fs.readFileSync(configPath, 'utf8'));
    } catch {}
  }
  return {};
}

function resolveDefaultConfigPaths(defaultConfig: any, customConfigPath: string | null): void {
  const configFilePath = customConfigPath
    ? path.resolve(customConfigPath)
    : path.resolve(process.cwd(), 'ziptie.config.json');
  const configDir = path.dirname(configFilePath);
  const pm = defaultConfig.packageManager;
  if (pm && typeof pm.localInstallersPath === 'string' && !path.isAbsolute(pm.localInstallersPath)) {
    pm.localInstallersPath = path.resolve(configDir, pm.localInstallersPath);
  }
  const st = defaultConfig.startupTask;
  if (st && typeof st.workingDir === 'string' && !path.isAbsolute(st.workingDir)) {
    st.workingDir = path.resolve(configDir, st.workingDir);
  }
}

export function printConfig(config: any, customConfigPath: string | null = null): void {
  console.log(chalk.bold.cyan('\n⚙️  Settings Overview:'));
  const defaultConfig = loadDefaultConfig();
  resolveDefaultConfigPaths(defaultConfig, customConfigPath);
  const categories = [
    { key: 'system', title: 'System' },
    { key: 'autologon', title: 'Autologon' },
    { key: 'startupTask', title: 'Startup Task' },
    { key: 'packageManager', title: 'Package Manager' },
    { key: 'windows', title: 'Windows' },
  ];
  for (const { key, title } of categories) {
    printCategory(title, config[key] || {}, defaultConfig[key] || {});
  }
  console.log('');
}
