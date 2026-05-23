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
      lockdown: { disableScreensaver: false }
    });

    // Asserts:
    // 1. Defaults loaded
    expect(config.lockdown.disableWidgets).toBe(true);
    // 2. User config merged over defaults
    expect(config.system.computerName).toBe('USER-CUSTOM');
    // 3. CLI overrides merged over user config and defaults
    expect(config.system.timezone).toBe('Tokyo Standard Time');
    expect(config.lockdown.disableScreensaver).toBe(false);
    // 4. Arrays are combined uniquely and sorted alphabetically
    expect(config.packageManager.apps).toEqual(['App1', 'App2', 'App3']);

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

