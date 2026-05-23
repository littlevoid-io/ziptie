import * as fs from 'node:fs';
import * as path from 'node:path';
import yargs from 'yargs';
import { hideBin } from 'yargs/helpers';
import chalk from 'chalk';
import { resolveProjectRoot } from './config.js';

export interface CLIContext {
  dryRun: boolean;
  undo: boolean;
  customConfigPath: string | null;
  autoConfirm: boolean;
  overrides: Record<string, any>;
}

interface DefaultConfigLeaf {
  path: string[];
  key: string;
  type: 'string' | 'boolean' | 'number' | 'array' | 'unknown';
}

/**
 * Recursively traverses the default configuration to find all leaf properties and their types.
 */
function getLeafProperties(obj: any, currentPath: string[] = []): DefaultConfigLeaf[] {
  let leaves: DefaultConfigLeaf[] = [];

  for (const key of Object.keys(obj)) {
    if (key === '$schema') continue;

    const val = obj[key];
    const newPath = [...currentPath, key];

    if (val !== null && typeof val === 'object' && !Array.isArray(val)) {
      leaves = leaves.concat(getLeafProperties(val, newPath));
    } else {
      let type: DefaultConfigLeaf['type'] = 'unknown';
      if (typeof val === 'boolean') type = 'boolean';
      else if (typeof val === 'number') type = 'number';
      else if (typeof val === 'string') type = 'string';
      else if (Array.isArray(val)) type = 'array';

      leaves.push({
        path: newPath,
        key,
        type,
      });
    }
  }

  return leaves;
}

/**
 * Casts a raw value to the expected type defined by the default configuration.
 */
function castValue(value: any, targetType: DefaultConfigLeaf['type']): any {
  if (targetType === 'boolean') {
    if (value === 'true' || value === '1' || value === true || value === '') return true;
    if (value === 'false' || value === '0' || value === false) return false;
    return Boolean(value);
  }
  if (targetType === 'number') {
    const num = Number(value);
    return isNaN(num) ? value : num;
  }
  if (targetType === 'array') {
    if (Array.isArray(value)) return value;
    if (typeof value === 'string') {
      return value.split(',').map(s => s.trim()).filter(Boolean);
    }
    return [value];
  }
  if (targetType === 'string') {
    return String(value);
  }
  return value;
}

/**
 * Generates an elegant, dynamic CLI help documentation block using Chalk and the JSON schema.
 */
export function showHelp(): void {
  const root = resolveProjectRoot();
  const schemaPath = path.join(root, 'ziptie.schema.json');
  const defaultPath = path.join(root, 'ziptie.default.config.json');

  let schema: any = null;
  let defaultConfig: any = null;

  try {
    if (fs.existsSync(schemaPath)) schema = JSON.parse(fs.readFileSync(schemaPath, 'utf8'));
    if (fs.existsSync(defaultPath)) defaultConfig = JSON.parse(fs.readFileSync(defaultPath, 'utf8'));
  } catch {
    // Fallback if files aren't found/readable
  }

  console.log(chalk.bold.cyan('\n 🪢 Ziptie System Setup & Lockdown CLI'));
  console.log(`\n ${chalk.bold('Usage:')} ziptie [options] [overrides]`);

  console.log(`\n ${chalk.bold.yellow('Standard Options:')}`);
  console.log(`   -c, --config <path>    ${chalk.dim('Path to a custom ziptie.config.json file')}`);
  console.log(`   -d, --dry-run          ${chalk.dim('Safe, read-only verification mode (no changes made)')}`);
  console.log(`   -u, --undo             ${chalk.dim('Reverts all active system tweaks and lockdowns')}`);
  console.log(`   -y, --yes              ${chalk.dim('Auto-confirm all prompts (non-interactive / silent)')}`);
  console.log(`   -h, --help             ${chalk.dim('Show this help documentation')}`);

  if (schema && schema.properties && defaultConfig) {
    console.log(`\n ${chalk.bold.yellow('Dynamic Configuration Overrides:')}`);
    console.log(`   ${chalk.dim('Override any parameter in the config. Values are automatically cast to target types.')}`);
    console.log(`   ${chalk.dim('Format: --<category>.<setting> <value>  OR  --<setting> <value> (shortcut)')}\n`);

    const categories = Object.keys(schema.properties);
    for (const cat of categories) {
      if (cat === '$schema') continue;
      const catSchema = schema.properties[cat];
      const catTitle = catSchema.description || cat;
      console.log(`   ${chalk.bold.green(`[${catTitle}]`)} ${chalk.dim(`(--${cat}.*)`)}`);

      if (catSchema.properties) {
        for (const key of Object.keys(catSchema.properties)) {
          const prop = catSchema.properties[key];
          const desc = prop.description || '';
          const defVal = defaultConfig[cat] ? defaultConfig[cat][key] : undefined;
          
          let formattedDefault = '';
          if (defVal !== undefined) {
            formattedDefault = chalk.dim(`(Default: ${JSON.stringify(defVal)})`);
          }

          // Format description wrapping to align beautifully
          const prefix = `     --${key}`;
          const spaceCount = Math.max(1, 26 - prefix.length);
          const spaces = ' '.repeat(spaceCount);
          console.log(`${chalk.cyan(prefix)}${spaces}${desc} ${formattedDefault}`);
        }
      }
      console.log('');
    }
  } else {
    console.log(`\n ${chalk.bold.yellow('Dynamic Configuration Overrides:')}`);
    console.log(`   Refer to the ziptie.schema.json or ziptie.default.config.json files for list of available parameters.`);
  }

  process.exit(0);
}

/**
 * Safely extracts CLI arguments depending on the runtime context (standard node/bun vs standalone compiled binary).
 */
export function getArgs(): string[] {
  const args = process.argv;
  if (!args || args.length === 0) return [];
  
  const isJS = args[1] && (args[1].endsWith('.js') || args[1].endsWith('.ts'));
  const isBinary = args[0] && (args[0].endsWith('.exe') || (!args[0].includes('node') && !args[0].includes('bun')));
  
  if (isBinary && !isJS) {
    return args.slice(1);
  }
  return args.slice(2);
}

/**
 * Main parser entry point. Parses yargs command line parameters and maps flat/nested overrides dynamically.
 */
export function parseCLI(): CLIContext {
  const root = resolveProjectRoot();
  const defaultPath = path.join(root, 'ziptie.default.config.json');

  let defaultConfig: any = {};
  if (fs.existsSync(defaultPath)) {
    try {
      defaultConfig = JSON.parse(fs.readFileSync(defaultPath, 'utf8'));
    } catch (e: any) {
      console.error(chalk.red(`Error parsing default config in CLI parser: ${e.message}`));
    }
  }

  const leafProps = getLeafProperties(defaultConfig);

  // Initialize yargs parser with dot-notation enabled (yargs parses dot-notation natively)
  const argvInstance = yargs(getArgs())
    .parserConfiguration({
      'dot-notation': true,
      'boolean-negation': true,
    })
    .help(false) // Handle help output manually for custom styling
    .alias('h', 'help')
    .alias('d', 'dry-run')
    .alias('u', 'undo')
    .alias('c', 'config')
    .alias('y', 'yes');

  const argv = argvInstance.parseSync() as Record<string, any>;

  if (argv.help) {
    showHelp();
  }

  const dryRun = Boolean(argv['dry-run'] || argv.d);
  const undo = Boolean(argv.undo || argv.u);
  const autoConfirm = Boolean(argv.yes || argv.y);
  const customConfigPath = typeof argv.config === 'string' ? argv.config : null;

  // Process dynamic configuration overrides
  const overrides: Record<string, any> = {};

  const standardFlags = ['_', '$0', 'dry-run', 'dryRun', 'd', 'undo', 'u', 'config', 'c', 'yes', 'y', 'help', 'h'];
  const categories = ['system', 'autologon', 'startupTask', 'packageManager', 'lockdown'];

  for (const argKey of Object.keys(argv)) {
    if (standardFlags.includes(argKey)) continue;

    const value = argv[argKey];

    // Case A: Nested/Categorized override (e.g. --lockdown.disableScreensaver=false)
    if (categories.includes(argKey) && typeof value === 'object' && value !== null) {
      for (const nestedKey of Object.keys(value)) {
        const nestedPath = [argKey, nestedKey];
        const leaf = leafProps.find(l => l.path[0] === argKey && l.path[1] === nestedKey);
        
        if (leaf) {
          const casted = castValue(value[nestedKey], leaf.type);
          if (!overrides[argKey]) overrides[argKey] = {};
          overrides[argKey][nestedKey] = casted;
        } else {
          console.warn(chalk.yellow(`Warning: Unknown property '${nestedKey}' in category '${argKey}'.`));
        }
      }
    }
    // Case B: Flat key override (e.g. --disableScreensaver=false)
    else {
      // Find all leaf properties with a matching key
      const matches = leafProps.filter(l => l.key === argKey);

      if (matches.length === 1) {
        const leaf = matches[0];
        const [cat, prop] = leaf.path;
        const casted = castValue(value, leaf.type);

        if (!overrides[cat]) overrides[cat] = {};
        overrides[cat][prop] = casted;
      } else if (matches.length > 1) {
        console.warn(
          chalk.red(`Error: Ambiguous parameter '--${argKey}'. Matches multiple paths: ${matches.map(m => m.path.join('.')).join(', ')}. Use direct dot-notation instead (e.g. --${matches[0].path.join('.')}).`)
        );
      } else {
        console.warn(chalk.yellow(`Warning: Unknown CLI configuration parameter '--${argKey}'.`));
      }
    }
  }

  return {
    dryRun,
    undo,
    customConfigPath,
    autoConfirm,
    overrides,
  };
}
