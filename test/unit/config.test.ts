import { describe, test, expect, spyOn, mock, afterEach } from 'bun:test';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { loadAndMergeConfig, resolveProjectRoot, printConfig, handleAutoConfirmTimeout } from '../../src/utils/config.js';

describe('Config Utility', () => {
  afterEach(() => {
    mock.restore();
  });

  test('resolveProjectRoot resolves successfully', () => {
    const root = resolveProjectRoot();
    expect(root).toBeTypeOf('string');
    expect(root.length).toBeGreaterThan(0);
  });

  test('loadAndMergeConfig performs deep recursive merge with CLI precedence', () => {
    const fsExistsSpy = spyOn(fs, 'existsSync').mockImplementation((p: any) => {
      const target = String(p);
      if (target.endsWith('ziptie.default.config.json')) return true;
      if (target.endsWith('ziptie.config.json')) return true;
      return false;
    });

    const fsReadSpy = spyOn(fs, 'readFileSync').mockImplementation((p: any) => {
      const target = String(p);
      if (target.endsWith('ziptie.default.config.json')) {
        return JSON.stringify({
          system: { computerName: 'DEFAULT-EXHIBIT', timezone: 'UTC' },
          packageManager: { apps: ['App1', 'App2'] },
          lockdown: { disableScreensaver: true, disableWidgets: true }
        });
      }
      if (target.endsWith('ziptie.config.json')) {
        return JSON.stringify({
          system: { computerName: 'USER-CUSTOM' },
          packageManager: { apps: ['App3', 'App1'] }
        });
      }
      return '';
    });

    const fsWriteSpy = spyOn(fs, 'writeFileSync').mockImplementation(() => {});
    const fsMkdirSpy = spyOn(fs, 'mkdirSync').mockImplementation(() => undefined);

    // Call loadAndMergeConfig with custom CLI overrides
    const { config } = loadAndMergeConfig(null, {
      system: { timezone: 'Tokyo Standard Time' },
      lockdown: { disableScreensaver: false },
      packageManager: { apps: ['App4'] }
    });

    // Asserts:
    // 1. Defaults loaded
    expect(config.lockdown.disableWidgets).toBe(true);
    // 2. User config merged over defaults
    expect(config.system.computerName).toBe('USER-CUSTOM');
    // 3. CLI overrides merged over user config and defaults
    expect(config.system.timezone).toBe('Tokyo Standard Time');
    expect(config.lockdown.disableScreensaver).toBe(false);
    // 4. Apps array is overwritten instead of merged (user config and then CLI override)
    expect(config.packageManager.apps).toEqual(['App4']);

    // Assert that temporary config was written
    expect(fsWriteSpy).toHaveBeenCalled();
  });

  test('printConfig prints configuration to console', () => {
    const consoleSpy = spyOn(console, 'log').mockImplementation(() => {});
    const sampleConfig = {
      system: { computerName: 'TEST-PC' },
      lockdown: { disableFirewall: true }
    };

    printConfig(sampleConfig);

    expect(consoleSpy).toHaveBeenCalled();
    const calls = consoleSpy.mock.calls.map(call => call.join(' '));
    expect(calls.some(c => c.includes('TEST-PC'))).toBe(true);
    expect(calls.some(c => c.includes('disableFirewall'))).toBe(true);

    consoleSpy.mockRestore();
  });

  test('printConfig does not print array if elements match default regardless of order', () => {
    const consoleSpy = spyOn(console, 'log').mockImplementation(() => {});
    const sampleConfig = {
      packageManager: {
        apps: ["Git.Git", "CoreyButler.NVMforWindows", "Microsoft.VisualStudioCode"]
      }
    };

    printConfig(sampleConfig);

    const calls = consoleSpy.mock.calls.map(call => call.join(' '));
    expect(calls.some(c => c.includes('[PackageManager Settings]'))).toBe(false);

    consoleSpy.mockRestore();
  });

  test('loadAndMergeConfig preserves exact args order in startupTask and does not sort/union them', () => {
    const fsExistsSpy = spyOn(fs, 'existsSync').mockImplementation((p: any) => {
      const target = String(p);
      if (target.endsWith('ziptie.default.config.json')) return true;
      if (target.endsWith('ziptie.config.json')) return true;
      return false;
    });

    const fsReadSpy = spyOn(fs, 'readFileSync').mockImplementation((p: any) => {
      const target = String(p);
      if (target.endsWith('ziptie.default.config.json')) {
        return JSON.stringify({
          startupTask: { args: [] }
        });
      }
      if (target.endsWith('ziptie.config.json')) {
        return JSON.stringify({
          startupTask: { args: ['run', 'dev:drawing-room'] }
        });
      }
      return '';
    });

    const fsWriteSpy = spyOn(fs, 'writeFileSync').mockImplementation(() => {});
    const fsMkdirSpy = spyOn(fs, 'mkdirSync').mockImplementation(() => undefined);

    const { config } = loadAndMergeConfig(null, {});

    // Asserts: exact order and content is preserved
    expect(config.startupTask.args).toEqual(['run', 'dev:drawing-room']);
  });

  test('loadAndMergeConfig overwrites and sorts packageManager.apps array instead of merging/uniting it', () => {
    const fsExistsSpy = spyOn(fs, 'existsSync').mockImplementation((p: any) => {
      const target = String(p);
      if (target.endsWith('ziptie.default.config.json')) return true;
      if (target.endsWith('ziptie.config.json')) return true;
      return false;
    });

    const fsReadSpy = spyOn(fs, 'readFileSync').mockImplementation((p: any) => {
      const target = String(p);
      if (target.endsWith('ziptie.default.config.json')) {
        return JSON.stringify({
          packageManager: { apps: ['App1', 'App2'] }
        });
      }
      if (target.endsWith('ziptie.config.json')) {
        return JSON.stringify({
          packageManager: { apps: ['App3', 'App1'] }
        });
      }
      return '';
    });

    const fsWriteSpy = spyOn(fs, 'writeFileSync').mockImplementation(() => {});
    const fsMkdirSpy = spyOn(fs, 'mkdirSync').mockImplementation(() => undefined);

    const { config } = loadAndMergeConfig(null, {});

    // Asserts: Apps from user config completely overwrite defaults, sorted and uniqued
    expect(config.packageManager.apps).toEqual(['App1', 'App3']);
  });

  test('printConfig is order-dependent for startupTask.args', () => {
    const consoleSpy = spyOn(console, 'log').mockImplementation(() => {});
    const sampleConfig = {
      startupTask: {
        args: ["run", "dev:drawing-room"]
      }
    };

    const fsExistsSpy = spyOn(fs, 'existsSync').mockImplementation((p: any) => {
      return String(p).endsWith('ziptie.default.config.json');
    });
    const fsReadSpy = spyOn(fs, 'readFileSync').mockImplementation((p: any) => {
      return JSON.stringify({
        startupTask: {
          args: ["dev:drawing-room", "run"]
        }
      });
    });

    printConfig(sampleConfig);

    const calls = consoleSpy.mock.calls.map(call => call.join(' '));
    expect(calls.some(c => c.includes('[StartupTask Settings]'))).toBe(true);

    consoleSpy.mockRestore();
    fsExistsSpy.mockRestore();
    fsReadSpy.mockRestore();
  });

  test('handleAutoConfirmTimeout runs countdown and resolves', async () => {
    let callback: (() => void) | null = null;
    
    // Mock setInterval to capture the callback
    const setIntervalSpy = spyOn(global, 'setInterval').mockImplementation((cb: any, ms) => {
      callback = cb;
      return 123 as any;
    });
    
    const clearIntervalSpy = spyOn(global, 'clearInterval').mockImplementation(() => {});
    const writeSpy = spyOn(process.stdout, 'write').mockImplementation(() => true);

    const promise = handleAutoConfirmTimeout(3);

    // Initial print has happened
    expect(writeSpy).toHaveBeenCalled();
    expect(callback).not.toBeNull();

    // Trigger the interval callback manually to simulate ticks
    if (callback) {
      (callback as () => void)(); // Tick 1 (remaining = 2)
      (callback as () => void)(); // Tick 2 (remaining = 1)
      (callback as () => void)(); // Tick 3 (remaining = 0, clears and resolves)
    }

    await promise;

    expect(clearIntervalSpy).toHaveBeenCalledWith(123 as any);
    
    setIntervalSpy.mockRestore();
    clearIntervalSpy.mockRestore();
    writeSpy.mockRestore();
  });
});

