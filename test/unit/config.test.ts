import { describe, test, expect, spyOn, mock, afterEach } from 'bun:test';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { loadAndMergeConfig, resolveProjectRoot } from '../../src/utils/config.js';

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
          lockdown: { disableScreensaver: true, disableWidgets: true }
        });
      }
      if (target.endsWith('ziptie.config.json')) {
        return JSON.stringify({
          system: { computerName: 'USER-CUSTOM' }
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

    // Assert that temporary config was written
    expect(fsWriteSpy).toHaveBeenCalled();
  });
});
