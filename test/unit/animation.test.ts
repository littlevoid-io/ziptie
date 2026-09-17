import { describe, test, expect, afterEach } from 'bun:test';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { loadConfig, loadVersion } from '../../src/utils/animation.js';

describe('Animation Utility', () => {
  const tempDirs: string[] = [];

  afterEach(() => {
    for (const dir of tempDirs) {
      if (fs.existsSync(dir)) {
        fs.rmSync(dir, { recursive: true, force: true });
      }
    }
    tempDirs.length = 0;
  });

  test('loadVersion returns defined version string', () => {
    const version = loadVersion();
    expect(typeof version).toBe('string');
    expect(version.length).toBeGreaterThan(0);
  });

  test('loads animation config from disk when present', () => {
    const testDir = fs.mkdtempSync(path.join(os.tmpdir(), 'ziptie-anim-test-'));
    tempDirs.push(testDir);

    const customConfig = {
      metadata: { speedMs: 50, width: 30 },
      frames: [['custom frame 1'], ['custom frame 2']],
    };
    fs.writeFileSync(
      path.join(testDir, 'ziptie.animation.json'),
      JSON.stringify(customConfig),
      'utf8'
    );

    const loaded = loadConfig(testDir);
    expect(loaded.metadata.speedMs).toBe(50);
    expect(loaded.metadata.width).toBe(30);
    expect(loaded.frames).toHaveLength(2);
  });

  test('falls back to embedded assets when file is absent on disk', () => {
    const emptyDir = fs.mkdtempSync(path.join(os.tmpdir(), 'ziptie-anim-empty-'));
    tempDirs.push(emptyDir);

    const loaded = loadConfig(emptyDir);
    expect(loaded).toBeDefined();
    expect(loaded.metadata.speedMs).toBe(100);
    expect(loaded.metadata.width).toBe(25);
    expect(loaded.frames.length).toBeGreaterThan(10);
  });

  test('falls back to defaultAnimation when config is corrupted on disk and embedded is unavailable', () => {
    const corruptedDir = fs.mkdtempSync(path.join(os.tmpdir(), 'ziptie-anim-bad-'));
    tempDirs.push(corruptedDir);

    fs.writeFileSync(path.join(corruptedDir, 'ziptie.animation.json'), 'invalid json{{{', 'utf8');
    const loaded = loadConfig(corruptedDir);
    expect(loaded).toBeDefined();
    expect(loaded.frames.length).toBeGreaterThan(0);
  });
});
