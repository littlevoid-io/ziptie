import { describe, test, expect, afterEach } from 'bun:test';
import { parseCLI } from '../src/utils/cli.js';

describe('CLI Override Parser', () => {
  const originalArgv = process.argv;

  afterEach(() => {
    process.argv = originalArgv;
  });

  test('parses standard flags correctly', () => {
    process.argv = ['node', 'dist/index.js', '-d', '-u', '-y', '-c', 'my-custom-config.json'];
    const ctx = parseCLI();

    expect(ctx.dryRun).toBe(true);
    expect(ctx.undo).toBe(true);
    expect(ctx.autoConfirm).toBe(true);
    expect(ctx.customConfigPath).toBe('my-custom-config.json');
    expect(ctx.overrides).toEqual({});
  });

  test('maps flat shortcut overrides with auto type-casting', () => {
    process.argv = [
      'node',
      'dist/index.js',
      '--computerName', 'TEST-EXHIBIT-99',
      '--timezone', 'Tokyo Standard Time',
      '--enableDailyReboot', 'false',
      '--autoRestart', 'true',
      '--disableScreensaver', 'true',
      '--disableFirewall', '1',
      '--apps', 'Node.js,Git.Git,VSCode',
    ];
    const ctx = parseCLI();

    expect(ctx.overrides.system?.computerName).toBe('TEST-EXHIBIT-99');
    expect(ctx.overrides.system?.timezone).toBe('Tokyo Standard Time');
    expect(ctx.overrides.system?.enableDailyReboot).toBe(false);
    expect(ctx.overrides.system?.autoRestart).toBe(true);
    expect(ctx.overrides.lockdown?.disableScreensaver).toBe(true);
    expect(ctx.overrides.lockdown?.disableFirewall).toBe(true);
    expect(ctx.overrides.packageManager?.apps).toEqual(['Node.js', 'Git.Git', 'VSCode']);
  });

  test('handles native yargs dot-notation overrides', () => {
    process.argv = [
      'node',
      'dist/index.js',
      '--system.rebootTime', '04:00',
      '--system.autoRestart', 'false',
      '--lockdown.disableScreensaver', 'false',
      '--lockdown.solidColorBackground', '#000000',
    ];
    const ctx = parseCLI();

    expect(ctx.overrides.system?.rebootTime).toBe('04:00');
    expect(ctx.overrides.system?.autoRestart).toBe(false);
    expect(ctx.overrides.lockdown?.disableScreensaver).toBe(false);
    expect(ctx.overrides.lockdown?.solidColorBackground).toBe('#000000');
  });

  test('combines hybrid flat shortcuts and dot-notation overrides', () => {
    process.argv = [
      'node',
      'dist/index.js',
      '--computerName', 'HYBRID-EXHIBIT',
      '--lockdown.disableScreensaver', 'true',
      '--disableEdgeSwipes', 'false',
    ];
    const ctx = parseCLI();

    expect(ctx.overrides.system?.computerName).toBe('HYBRID-EXHIBIT');
    expect(ctx.overrides.lockdown?.disableScreensaver).toBe(true);
    expect(ctx.overrides.lockdown?.disableEdgeSwipes).toBe(false);
  });
});
