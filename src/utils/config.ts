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

  // If slab.default.config.json isn't found, check relative to compiled standalone binary location
  if (!fs.existsSync(path.join(projectRoot, 'slab.default.config.json'))) {
    const exeDir = path.dirname(process.execPath);
    projectRoot = path.resolve(exeDir, '..');
    if (!fs.existsSync(path.join(projectRoot, 'slab.default.config.json'))) {
      projectRoot = exeDir;
    }
  }

  // Fallback to CWD if still not found
  if (!fs.existsSync(path.join(projectRoot, 'slab.default.config.json'))) {
    projectRoot = process.cwd();
  }

  return projectRoot;
}

/**
 * Loads the default configuration, deep-merges it with user overrides
 * using the robust deepmerge library, and writes a temporary merged JSON payload.
 *
 * @param customConfigPath Optional path to a user-provided configuration file.
 */
export function loadAndMergeConfig(customConfigPath: string | null): ConfigContext {
  const projectRoot = resolveProjectRoot();

  const defaultConfigPath = path.join(projectRoot, 'slab.default.config.json');
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
    : path.resolve(process.cwd(), 'slab.config.json');

  let userConfig: any = {};
  if (fs.existsSync(configFilePath)) {
    try {
      userConfig = JSON.parse(fs.readFileSync(configFilePath, 'utf8'));
    } catch (e: any) {
      console.error(chalk.red(`Error parsing user config file: ${e.message}`));
      process.exit(1);
    }
  }

  // Perform a clean recursive deep merge using the deepmerge package
  const mergedConfig = deepmerge(defaultConfig, userConfig);

  // Ensure .tmp directory exists in CWD
  const tmpDir = path.resolve(process.cwd(), '.tmp');
  if (!fs.existsSync(tmpDir)) {
    fs.mkdirSync(tmpDir, { recursive: true });
  }

  // Write temporary config file
  const resolvedConfigPath = path.join(tmpDir, 'slab-temp-config.json');
  fs.writeFileSync(resolvedConfigPath, JSON.stringify(mergedConfig, null, 2), 'utf8');

  return {
    projectRoot,
    resolvedConfigPath,
    config: mergedConfig,
  };
}
