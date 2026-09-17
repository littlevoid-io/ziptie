import * as fs from 'node:fs';
import * as path from 'node:path';
import yargs from 'yargs';
import chalk from 'chalk';
import { resolveProjectRoot } from './project.js';
import { showHelp } from './help.js';
import {
  DefaultConfigLeaf,
  getLeafProperties,
  getLeafPropertiesFromSchema,
  castValue,
} from './schemaLeaves.js';
import { SetupMode } from './templates.js';

export interface CLIContext {
  command?: string;
  mode?: SetupMode;
  projectRoot?: string;
  force: boolean;
  dryRun: boolean;
  undo: boolean;
  customConfigPath: string | null;
  autoConfirm: boolean;
  overrides: Record<string, any>;
}

export function getArgs(): string[] {
  const args = process.argv;
  if (!args || args.length === 0) return [];
  const isJS = args[1] && (args[1].endsWith('.js') || args[1].endsWith('.ts'));
  const isBinary =
    args[0] &&
    (args[0].endsWith('.exe') || (!args[0].includes('node') && !args[0].includes('bun')));
  if (isBinary && !isJS) return args.slice(1);
  return args.slice(2);
}

function loadConfigLeaves(): DefaultConfigLeaf[] {
  const root = resolveProjectRoot();
  const defaultPath = path.join(root, 'ziptie.default.config.json');
  const schemaPath = path.join(root, 'ziptie.schema.json');
  let defaultConfig: any = {};
  let schema: any = null;
  try {
    if (fs.existsSync(defaultPath))
      defaultConfig = JSON.parse(fs.readFileSync(defaultPath, 'utf8'));
    if (fs.existsSync(schemaPath)) schema = JSON.parse(fs.readFileSync(schemaPath, 'utf8'));
  } catch {
    // Suppress config load errors
  }
  const schemaLeaves = getLeafPropertiesFromSchema(schema);
  const defaultLeaves = getLeafProperties(defaultConfig);
  const leavesMap = new Map<string, DefaultConfigLeaf>();
  for (const leaf of schemaLeaves) leavesMap.set(leaf.path.join('.'), leaf);
  for (const leaf of defaultLeaves) {
    if (!leavesMap.has(leaf.path.join('.'))) leavesMap.set(leaf.path.join('.'), leaf);
  }
  return Array.from(leavesMap.values());
}

function applyCategorizedOverride(
  overrides: Record<string, any>,
  category: string,
  nested: Record<string, any>,
  leaves: DefaultConfigLeaf[]
): void {
  for (const nestedKey of Object.keys(nested)) {
    const leaf = leaves.find(l => l.path[0] === category && l.path[1] === nestedKey);
    if (leaf) {
      if (!overrides[category]) overrides[category] = {};
      overrides[category][nestedKey] = castValue(nested[nestedKey], leaf.type);
    } else {
      console.warn(
        chalk.yellow(`Warning: Unknown property '${nestedKey}' in category '${category}'.`)
      );
    }
  }
}

function applyFlatOverride(
  overrides: Record<string, any>,
  argKey: string,
  value: any,
  leaves: DefaultConfigLeaf[]
): void {
  const matches = leaves.filter(l => l.key === argKey);
  if (matches.length === 1) {
    const [cat, prop] = matches[0].path;
    if (!overrides[cat]) overrides[cat] = {};
    overrides[cat][prop] = castValue(value, matches[0].type);
  } else if (matches.length > 1) {
    console.warn(chalk.red(`Error: Ambiguous parameter '--${argKey}'. Use dot-notation instead.`));
  } else {
    console.warn(chalk.yellow(`Warning: Unknown CLI configuration parameter '--${argKey}'.`));
  }
}

function extractOverrides(
  argv: Record<string, any>,
  leafProps: DefaultConfigLeaf[]
): Record<string, any> {
  const overrides: Record<string, any> = {};
  const standardFlags = [
    '_',
    '$0',
    'dry-run',
    'dryRun',
    'd',
    'undo',
    'u',
    'config',
    'c',
    'yes',
    'y',
    'mode',
    'm',
    'force',
    'f',
    'project-root',
    'projectRoot',
    'help',
    'h',
  ];
  const categories = Array.from(new Set(leafProps.map(l => l.path[0])));
  for (const argKey of Object.keys(argv)) {
    if (standardFlags.includes(argKey)) continue;
    const val = argv[argKey];
    if (categories.includes(argKey) && typeof val === 'object' && val !== null) {
      applyCategorizedOverride(overrides, argKey, val, leafProps);
    } else {
      applyFlatOverride(overrides, argKey, val, leafProps);
    }
  }
  return overrides;
}

export function parseCLI(): CLIContext {
  const leafProps = loadConfigLeaves();
  const argvInstance = yargs(getArgs())
    .parserConfiguration({ 'dot-notation': true, 'boolean-negation': true })
    .help(false)
    .alias('h', 'help')
    .alias('d', 'dry-run')
    .alias('u', 'undo')
    .alias('c', 'config')
    .alias('y', 'yes')
    .alias('m', 'mode')
    .alias('f', 'force');

  const argv = argvInstance.parseSync() as Record<string, any>;
  if (argv.help) showHelp();

  const command = typeof argv._[0] === 'string' ? argv._[0] : undefined;
  const isInit = command === 'init';

  if (!isInit) {
    if (argv.mode || argv.m) {
      console.warn(chalk.yellow("Warning: '--mode' is only valid with the 'init' command."));
    }
    if (argv.force || argv.f) {
      console.warn(chalk.yellow("Warning: '--force' is only valid with the 'init' command."));
    }
  }

  const rawMode =
    isInit &&
    (typeof argv.mode === 'string' ? argv.mode : typeof argv.m === 'string' ? argv.m : undefined);
  const mode = ['offline', 'online', 'npm'].includes(rawMode as any)
    ? (rawMode as SetupMode)
    : undefined;
  const projectRoot =
    isInit && typeof argv['project-root'] === 'string' ? argv['project-root'] : undefined;

  return {
    command,
    mode,
    projectRoot,
    force: isInit && Boolean(argv.force || argv.f),
    dryRun: Boolean(argv['dry-run'] || argv.d),
    undo: Boolean(argv.undo || argv.u),
    autoConfirm: Boolean(argv.yes || argv.y),
    customConfigPath: typeof argv.config === 'string' ? argv.config : null,
    overrides: extractOverrides(argv, leafProps),
  };
}

export { showHelp } from './help.js';
