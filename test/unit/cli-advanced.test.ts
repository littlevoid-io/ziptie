import { describe, test, expect, spyOn, mock, afterEach } from 'bun:test';
import * as fs from 'node:fs';
import { parseCLI } from '../../src/utils/cli.js';

describe('CLI Advanced Parser', () => {
  const originalArgv = process.argv;

  afterEach(() => {
    process.argv = originalArgv;
    mock.restore();
  });

  test('handles negated boolean flags dynamically', () => {
    // Mock default config to allow schema traversal
    spyOn(fs, 'existsSync').mockImplementation(() => true);
    spyOn(fs, 'readFileSync').mockImplementation(() => JSON.stringify({
      lockdown: { disableScreensaver: true }
    }));

    // Mock CLI argument inputs (yargs dot-notation negation)
    process.argv = ['node', 'index.js', '--no-lockdown.disableScreensaver', '--no-dry-run'];

    const ctx = parseCLI();

    expect(ctx.dryRun).toBe(false);
    expect(ctx.overrides.lockdown?.disableScreensaver).toBe(false);
  });

  test('parses comma-separated app lists to clean arrays', () => {
    spyOn(fs, 'existsSync').mockImplementation(() => true);
    spyOn(fs, 'readFileSync').mockImplementation(() => JSON.stringify({
      packageManager: { apps: [] }
    }));

    process.argv = ['node', 'index.js', '--apps', 'Node.js, Git.Git, VSCode,,'];

    const ctx = parseCLI();

    expect(ctx.overrides.packageManager?.apps).toEqual(['Node.js', 'Git.Git', 'VSCode']);
  });

  test('gracefully ignores unknown config parameters and flags', () => {
    spyOn(fs, 'existsSync').mockImplementation(() => true);
    spyOn(fs, 'readFileSync').mockImplementation(() => JSON.stringify({
      system: { computerName: 'DEFAULT' }
    }));

    const consoleWarnSpy = spyOn(console, 'warn').mockImplementation(() => {});

    process.argv = ['node', 'index.js', '--garbage-param', 'value'];

    const ctx = parseCLI();

    // Unknown CLI config parameters should not populate into overrides
    expect(ctx.overrides).toEqual({});
    expect(consoleWarnSpy).toHaveBeenCalled();
  });
});
