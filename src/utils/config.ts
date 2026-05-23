import * as fs from 'node:fs';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';
import chalk from 'chalk';
import deepmerge from 'deepmerge';

export interface ConfigContext {
  projectRoot: string;
  resolvedConfigPath: string;
  config: any;
}

/**
 * Resolves the absolute project root directory by scanning standard locations.
 */
export function resolveProjectRoot(): string {
  let currentFileDir = '';
  try {
    // Standard ESM resolution
    currentFileDir = path.dirname(fileURLToPath(import.meta.url));
  } catch {
    // CommonJS fallback if bundled differently
    currentFileDir = __dirname;
  }

  // Determine starting projectRoot (dist/ is nested in the root, so resolve parent)
  let projectRoot = path.resolve(currentFileDir, '..');

  // If ziptie.default.config.json isn't found, check relative to compiled standalone binary location
  if (!fs.existsSync(path.join(projectRoot, 'ziptie.default.config.json'))) {
    const exeDir = path.dirname(process.execPath);
    projectRoot = path.resolve(exeDir, '..');
    if (!fs.existsSync(path.join(projectRoot, 'ziptie.default.config.json'))) {
      projectRoot = exeDir;
    }
  }

  // Fallback to CWD if still not found
  if (!fs.existsSync(path.join(projectRoot, 'ziptie.default.config.json'))) {
    projectRoot = process.cwd();
  }

  return projectRoot;
}

/**
 * Loads the default configuration, deep-merges it with user overrides
 * using the robust deepmerge library, and writes a temporary merged JSON payload.
 *
 * @param customConfigPath Optional path to a user-provided configuration file.
 * @param cliOverrides Optional CLI configuration overrides.
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

  // Load defaults
  let defaultConfig: any = {};
  try {
    defaultConfig = JSON.parse(fs.readFileSync(defaultConfigPath, 'utf8'));
  } catch (e: any) {
    console.error(chalk.red(`Error parsing default configuration: ${e.message}`));
    process.exit(1);
  }

  // Resolve user config path
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

  // Perform a clean recursive deep merge of defaults and user configuration
  let mergedConfig = deepmerge(defaultConfig, userConfig);

  // Apply CLI overrides with highest precedence if provided
  if (cliOverrides && Object.keys(cliOverrides).length > 0) {
    mergedConfig = deepmerge(mergedConfig, cliOverrides);
  }

  // Resolve relative configuration paths (localInstallersPath, workingDir)
  // relative to the parent directory of the configuration file instead of CWD/projectRoot
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

  // Ensure .tmp directory exists in CWD
  const tmpDir = path.resolve(process.cwd(), '.tmp');
  if (!fs.existsSync(tmpDir)) {
    fs.mkdirSync(tmpDir, { recursive: true });
  }

  // Write temporary config file
  const resolvedConfigPath = path.join(tmpDir, 'ziptie-temp-config.json');
  fs.writeFileSync(resolvedConfigPath, JSON.stringify(mergedConfig, null, 2), 'utf8');

  return {
    projectRoot,
    resolvedConfigPath,
    config: mergedConfig,
  };
}

/**
 * Beautifully pretty-prints the loaded configuration to the console with basic colorized syntax highlighting.
 */
export function printConfig(config: any): void {
  console.log(chalk.bold.cyan('\n⚙️  Composited Configuration Settings:'));

  const jsonString = JSON.stringify(config, null, 2);
  const lines = jsonString.split('\n');

  for (const line of lines) {
    const match = line.match(/^(\s*)("([^"]+)")(\s*:\s*)(.*)$/);
    if (match) {
      const indent = match[1];
      const key = match[2];
      const colon = match[4];
      const value = match[5];

      let highlightedValue = value;
      if (value.startsWith('"')) {
        const endsWithComma = value.endsWith(',');
        const strVal = endsWithComma ? value.slice(0, -1) : value;
        highlightedValue = chalk.yellow(strVal) + (endsWithComma ? ',' : '');
      } else if (value.startsWith('true') || value.startsWith('false')) {
        const endsWithComma = value.endsWith(',');
        const boolVal = endsWithComma ? value.slice(0, -1) : value;
        highlightedValue = chalk.magenta(boolVal) + (endsWithComma ? ',' : '');
      } else if (/^\d/.test(value)) {
        const endsWithComma = value.endsWith(',');
        const numVal = endsWithComma ? value.slice(0, -1) : value;
        highlightedValue = chalk.blue(numVal) + (endsWithComma ? ',' : '');
      } else if (value === '[]' || value === '{}' || value.startsWith('[') || value.startsWith('{')) {
        highlightedValue = chalk.white(value);
      }

      console.log(`${indent}${chalk.green(key)}${colon}${highlightedValue}`);
    } else {
      console.log(chalk.white(line));
    }
  }
  console.log('');
}

/**
 * Initiates a non-blocking console countdown timeout before automatically proceeding.
 */
export async function handleAutoConfirmTimeout(seconds: number = 10): Promise<void> {
  return new Promise((resolve) => {
    let remaining = seconds;

    const interval = setInterval(() => {
      if (remaining <= 0) {
        clearInterval(interval);
        process.stdout.write('\r\x1b[K'); // clear the countdown line
        resolve();
        return;
      }
      process.stdout.write(
        `\r${chalk.cyan('⏱️  Automatically applying configurations in')} ${chalk.bold.yellow(remaining)} ${chalk.cyan('seconds... Press Ctrl+C to abort.')}`
      );
      remaining--;
    }, 1000);

    // Initial print
    process.stdout.write(
      `\r${chalk.cyan('⏱️  Automatically applying configurations in')} ${chalk.bold.yellow(remaining)} ${chalk.cyan('seconds... Press Ctrl+C to abort.')}`
    );
    remaining--;
  });
}

