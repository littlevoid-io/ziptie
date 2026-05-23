import { parseCLI } from '../src/utils/cli.js';
import chalk from 'chalk';

// Utility for deep assertions
function assertEqual(actual: any, expected: any, message: string): void {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `${message}\nExpected: ${JSON.stringify(expected, null, 2)}\nActual: ${JSON.stringify(actual, null, 2)}`
    );
  }
}

interface TestDefinition {
  name: string;
  argv: string[];
  verify: (ctx: ReturnType<typeof parseCLI>) => void;
}

const tests: TestDefinition[] = [
  {
    name: 'Standard flags parsing',
    argv: ['-d', '-u', '-y', '-c', 'my-custom-config.json'],
    verify: (ctx) => {
      assertEqual(ctx.dryRun, true, 'dryRun should be true');
      assertEqual(ctx.undo, true, 'undo should be true');
      assertEqual(ctx.autoConfirm, true, 'autoConfirm should be true');
      assertEqual(ctx.customConfigPath, 'my-custom-config.json', 'customConfigPath should match');
      assertEqual(ctx.overrides, {}, 'overrides should be empty when only standard flags are passed');
    },
  },
  {
    name: 'Flat shortcut overrides with auto type-casting',
    argv: [
      '--computerName', 'TEST-EXHIBIT-99',
      '--timezone', 'Tokyo Standard Time',
      '--enableDailyReboot', 'false',
      '--disableScreensaver', 'true',
      '--disableFirewall', '1',
      '--apps', 'Node.js,Git.Git,VSCode',
    ],
    verify: (ctx) => {
      assertEqual(
        ctx.overrides.system?.computerName,
        'TEST-EXHIBIT-99',
        'computerName should map to system.computerName'
      );
      assertEqual(
        ctx.overrides.system?.timezone,
        'Tokyo Standard Time',
        'timezone should map to system.timezone'
      );
      assertEqual(
        ctx.overrides.system?.enableDailyReboot,
        false,
        'enableDailyReboot "false" should be cast to boolean false'
      );
      assertEqual(
        ctx.overrides.lockdown?.disableScreensaver,
        true,
        'disableScreensaver "true" should be cast to boolean true'
      );
      assertEqual(
        ctx.overrides.lockdown?.disableFirewall,
        true,
        'disableFirewall "1" should be cast to boolean true'
      );
      assertEqual(
        ctx.overrides.packageManager?.apps,
        ['Node.js', 'Git.Git', 'VSCode'],
        'apps string list should be cast to array of strings'
      );
    },
  },
  {
    name: 'Native yargs dot-notation overrides',
    argv: [
      '--system.rebootTime', '04:00',
      '--lockdown.disableScreensaver', 'false',
      '--lockdown.solidColorBackground', '#000000',
    ],
    verify: (ctx) => {
      assertEqual(
        ctx.overrides.system?.rebootTime,
        '04:00',
        'system.rebootTime should be parsed and matched'
      );
      assertEqual(
        ctx.overrides.lockdown?.disableScreensaver,
        false,
        'lockdown.disableScreensaver "false" should be cast to boolean false'
      );
      assertEqual(
        ctx.overrides.lockdown?.solidColorBackground,
        '#000000',
        'lockdown.solidColorBackground should keep string hex value'
      );
    },
  },
  {
    name: 'Hybrid flat shortcuts and dot-notation overrides combined',
    argv: [
      '--computerName', 'HYBRID-EXHIBIT',
      '--lockdown.disableScreensaver', 'true',
      '--disableEdgeSwipes', 'false',
    ],
    verify: (ctx) => {
      assertEqual(
        ctx.overrides.system?.computerName,
        'HYBRID-EXHIBIT',
        'computerName should resolve to system.computerName'
      );
      assertEqual(
        ctx.overrides.lockdown?.disableScreensaver,
        true,
        'lockdown.disableScreensaver should be true'
      );
      assertEqual(
        ctx.overrides.lockdown?.disableEdgeSwipes,
        false,
        'disableEdgeSwipes should resolve to lockdown.disableEdgeSwipes and cast to false'
      );
    },
  },
];

console.log(chalk.bold.cyan('\n🧪 Starting Ziptie CLI Override Parser Unit Tests\n'));

let passed = 0;
const originalArgv = process.argv;

try {
  for (const t of tests) {
    console.log(chalk.yellow(`🏃 Running: ${t.name}...`));
    // Override process.argv for testing
    process.argv = ['node', 'dist/index.js', ...t.argv];
    
    try {
      const ctx = parseCLI();
      t.verify(ctx);
      console.log(chalk.green(`✅ Passed: ${t.name}\n`));
      passed++;
    } catch (e: any) {
      console.error(chalk.red(`❌ Failed: ${t.name}`));
      console.error(chalk.red(e.stack || e.message));
      process.exit(1);
    }
  }

  console.log(chalk.bold.green(`🎉 Success: All ${passed}/${tests.length} tests passed successfully!`));
  process.exit(0);
} finally {
  process.argv = originalArgv;
}
