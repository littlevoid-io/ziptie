import * as fs from 'node:fs';
import * as path from 'node:path';
import chalk from 'chalk';
import { resolveProjectRoot } from './project.js';

function readConfigMetadata(): { schema: any; defaultConfig: any } {
  const root = resolveProjectRoot();
  let schema: any = null;
  let defaultConfig: any = null;
  try {
    const schemaPath = path.join(root, 'ziptie.schema.json');
    if (fs.existsSync(schemaPath)) schema = JSON.parse(fs.readFileSync(schemaPath, 'utf8'));
    const defaultPath = path.join(root, 'ziptie.default.config.json');
    if (fs.existsSync(defaultPath))
      defaultConfig = JSON.parse(fs.readFileSync(defaultPath, 'utf8'));
  } catch {
    // Suppress metadata read errors
  }
  return { schema, defaultConfig };
}

function printPropertyHelp(key: string, prop: any, defaultValue: any): void {
  const desc = prop.description || '';
  let formattedDefault = '';
  if (defaultValue !== undefined) {
    formattedDefault = chalk.dim(`(Default: ${JSON.stringify(defaultValue)})`);
  }
  const prefix = `     --${key}`;
  const spaceCount = Math.max(1, 26 - prefix.length);
  const spaces = ' '.repeat(spaceCount);
  console.log(`${chalk.cyan(prefix)}${spaces}${desc} ${formattedDefault}`);
}

function printSchemaOverrides(schema: any, defaultConfig: any): void {
  console.log(`\n ${chalk.bold.yellow('Settings Overrides:')}`);
  console.log(`   ${chalk.dim('Override config settings directly from the command line.')}`);
  console.log(`   ${chalk.dim('Format: --<setting> <value> (e.g. --computerName EXHIBIT-01)')}\n`);

  for (const cat of Object.keys(schema.properties)) {
    if (cat === '$schema') continue;
    const catSchema = schema.properties[cat];
    const catTitle = catSchema.description || cat;
    console.log(`   ${chalk.bold.green(`[${catTitle}]`)} ${chalk.dim(`(--${cat}.*)`)}`);
    if (catSchema.properties) {
      for (const key of Object.keys(catSchema.properties)) {
        const defVal = defaultConfig[cat] ? defaultConfig[cat][key] : undefined;
        printPropertyHelp(key, catSchema.properties[key], defVal);
      }
    }
    console.log('');
  }
}

function printCommandHelp(): void {
  console.log(`\n ${chalk.bold.yellow('Commands:')}`);
  console.log(
    `   init                   ${chalk.dim('Initialize ziptie.config.json and ziptie.bat')}`
  );
  console.log(
    `     -m, --mode <mode>    ${chalk.dim('Setup mode: online, offline, npm (default: prompt)')}`
  );
  console.log(`     -f, --force          ${chalk.dim('Overwrite existing files')}`);
  console.log(`     --project-root <dir> ${chalk.dim('Target directory (default: cwd)')}`);
}

export function showHelp(): void {
  const { schema, defaultConfig } = readConfigMetadata();
  console.log(chalk.bold.cyan('\n 🪢 Ziptie System Setup CLI'));
  console.log(
    `\n ${chalk.bold('Usage:')}\n   ziptie [options] [overrides]\n   ziptie init [options]`
  );
  printCommandHelp();
  console.log(`\n ${chalk.bold.yellow('Options:')}`);
  console.log(`   -c, --config <path>    ${chalk.dim('Path to custom config file')}`);
  console.log(`   -d, --dry-run          ${chalk.dim('Safe dry-run mode (no changes are made)')}`);
  console.log(
    `   -u, --undo             ${chalk.dim('Reverts all changes and restores defaults')}`
  );
  console.log(`   -y, --yes              ${chalk.dim('Auto-confirm all prompts (silent mode)')}`);
  console.log(`   -h, --help             ${chalk.dim('Show help menu')}`);

  if (schema && schema.properties && defaultConfig) {
    printSchemaOverrides(schema, defaultConfig);
  }
  process.exit(0);
}
