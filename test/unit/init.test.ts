import { describe, test, expect, beforeEach, afterEach, spyOn } from 'bun:test';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { runInit } from '../../src/commands/init.js';
import * as downloadModule from '../../src/utils/download.js';

describe('Init Command', () => {
  let tempDir: string;

  beforeEach(() => {
    tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'ziptie-init-test-'));
  });

  afterEach(() => {
    try {
      fs.rmSync(tempDir, { recursive: true, force: true });
    } catch {
      // Ignore cleanup error
    }
  });

  test('scaffolds online mode with bootstrap script and default config', async () => {
    const code = await runInit({ projectRoot: tempDir, mode: 'online' });
    expect(code).toBe(0);

    const configPath = path.join(tempDir, 'ziptie.config.json');
    const batchPath = path.join(tempDir, 'ziptie.bat');

    expect(fs.existsSync(configPath)).toBe(true);
    expect(fs.existsSync(batchPath)).toBe(true);

    const batchContent = fs.readFileSync(batchPath, 'utf8');
    expect(batchContent).toContain('bootstrap.ps1');

    const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    expect(config.system.computerName).toBe('exhibit-pc-01');
    expect(config.autologon.username).toBe('auto');
  });

  test('derives computer name from package.json and configures npm mode', async () => {
    const pkgPath = path.join(tempDir, 'package.json');
    fs.writeFileSync(pkgPath, JSON.stringify({ name: '@my-scope/kiosk-display' }), 'utf8');

    const code = await runInit({ projectRoot: tempDir, mode: 'npm' });
    expect(code).toBe(0);

    const config = JSON.parse(fs.readFileSync(path.join(tempDir, 'ziptie.config.json'), 'utf8'));
    expect(config.system.computerName).toBe('kiosk-display-01');

    const batchContent = fs.readFileSync(path.join(tempDir, 'ziptie.bat'), 'utf8');
    expect(batchContent).toContain('npx @littlevoid/ziptie');

    const updatedPkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
    expect(updatedPkg.devDependencies['@littlevoid/ziptie']).toBeDefined();
  });

  test('does not overwrite existing files without force flag', async () => {
    const configPath = path.join(tempDir, 'ziptie.config.json');
    const batchPath = path.join(tempDir, 'ziptie.bat');

    fs.writeFileSync(configPath, '{"custom": true}', 'utf8');
    fs.writeFileSync(batchPath, 'REM CUSTOM BATCH', 'utf8');

    await runInit({ projectRoot: tempDir, mode: 'online' });

    expect(fs.readFileSync(configPath, 'utf8')).toBe('{"custom": true}');
    expect(fs.readFileSync(batchPath, 'utf8')).toBe('REM CUSTOM BATCH');

    await runInit({ projectRoot: tempDir, mode: 'online', force: true });

    expect(fs.readFileSync(configPath, 'utf8')).not.toBe('{"custom": true}');
    expect(fs.readFileSync(batchPath, 'utf8')).not.toBe('REM CUSTOM BATCH');
  });

  test('invokes binary downloader in offline mode', async () => {
    const downloadSpy = spyOn(downloadModule, 'downloadBinary').mockImplementation(
      async (dest: string) => {
        fs.writeFileSync(dest, 'MOCK_BINARY');
      }
    );

    const code = await runInit({ projectRoot: tempDir, mode: 'offline' });
    expect(code).toBe(0);
    expect(downloadSpy).toHaveBeenCalled();

    const exePath = path.join(tempDir, 'ziptie.exe');
    expect(fs.existsSync(exePath)).toBe(true);

    const batchContent = fs.readFileSync(path.join(tempDir, 'ziptie.bat'), 'utf8');
    expect(batchContent).toContain('ziptie.exe');
  });
});
