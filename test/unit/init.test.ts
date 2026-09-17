import { describe, test, expect, beforeEach, afterEach, spyOn, mock } from 'bun:test';
import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import * as prompts from '@clack/prompts';
import { runInit } from '../../src/commands/init.js';
import * as downloadModule from '../../src/utils/download.js';

describe('Init Command', () => {
  let tempDir: string;

  beforeEach(() => {
    tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'ziptie-init-test-'));
  });

  afterEach(() => {
    mock.restore();
    try {
      fs.rmSync(tempDir, { recursive: true, force: true });
    } catch {
      // Ignore cleanup error
    }
  });

  test('scaffolds online mode with auto defaults in non-interactive mode', async () => {
    const code = await runInit({ projectRoot: tempDir, mode: 'online', autoConfirm: true });
    expect(code).toBe(0);

    const configPath = path.join(tempDir, 'ziptie.config.json');
    const batchPath = path.join(tempDir, 'ziptie-setup.bat');

    expect(fs.existsSync(configPath)).toBe(true);
    expect(fs.existsSync(batchPath)).toBe(true);

    const batchContent = fs.readFileSync(batchPath, 'utf8');
    expect(batchContent).toContain('bootstrap.ps1');

    const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    expect(config.system.computerName).toBe('auto');
    expect(config.autologon.username).toBe('auto');
    expect(config.startupTask.workingDir).toBe('auto');
    expect(config.startupTask.executable).toBe('launch.bat');
  });

  test('updates package.json in npm mode', async () => {
    const pkgPath = path.join(tempDir, 'package.json');
    fs.writeFileSync(pkgPath, JSON.stringify({ name: '@my-scope/kiosk-display' }), 'utf8');

    const code = await runInit({ projectRoot: tempDir, mode: 'npm', autoConfirm: true });
    expect(code).toBe(0);

    const batchContent = fs.readFileSync(path.join(tempDir, 'ziptie-setup.bat'), 'utf8');
    expect(batchContent).toContain('npx @littlevoid/ziptie');

    const updatedPkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
    expect(updatedPkg.devDependencies['@littlevoid/ziptie']).toBeDefined();
  });

  test('configures startup task interactively and generates launch.bat', async () => {
    const pkgPath = path.join(tempDir, 'package.json');
    fs.writeFileSync(
      pkgPath,
      JSON.stringify({ name: 'river-display', scripts: { start: 'eggshell start' } }),
      'utf8'
    );

    spyOn(prompts, 'text')
      .mockResolvedValueOnce('exhibit-01') // computerName
      .mockResolvedValueOnce('launch.bat') // executable
      .mockResolvedValueOnce('') // args
      .mockResolvedValueOnce('auto'); // workingDir
    spyOn(prompts, 'confirm').mockResolvedValueOnce(true); // create launch.bat

    const code = await runInit({ projectRoot: tempDir, mode: 'online' });
    expect(code).toBe(0);

    const config = JSON.parse(fs.readFileSync(path.join(tempDir, 'ziptie.config.json'), 'utf8'));
    expect(config.system.computerName).toBe('exhibit-01');
    expect(config.startupTask.executable).toBe('launch.bat');
    expect(config.startupTask.workingDir).toBe('auto');

    const launchPath = path.join(tempDir, 'launch.bat');
    expect(fs.existsSync(launchPath)).toBe(true);
    const launchContent = fs.readFileSync(launchPath, 'utf8');
    expect(launchContent).toContain('npm start');
  });

  test('does not overwrite existing files without force flag', async () => {
    const configPath = path.join(tempDir, 'ziptie.config.json');
    const batchPath = path.join(tempDir, 'ziptie-setup.bat');

    fs.writeFileSync(configPath, '{"custom": true}', 'utf8');
    fs.writeFileSync(batchPath, 'REM CUSTOM BATCH', 'utf8');

    await runInit({ projectRoot: tempDir, mode: 'online', autoConfirm: true });

    expect(fs.readFileSync(configPath, 'utf8')).toBe('{"custom": true}');
    expect(fs.readFileSync(batchPath, 'utf8')).toBe('REM CUSTOM BATCH');

    await runInit({ projectRoot: tempDir, mode: 'online', force: true, autoConfirm: true });

    expect(fs.readFileSync(configPath, 'utf8')).not.toBe('{"custom": true}');
    expect(fs.readFileSync(batchPath, 'utf8')).not.toBe('REM CUSTOM BATCH');
  });

  test('invokes binary downloader in offline mode', async () => {
    const downloadSpy = spyOn(downloadModule, 'downloadBinary').mockImplementation(
      async (dest: string) => {
        fs.writeFileSync(dest, 'MOCK_BINARY');
      }
    );

    const code = await runInit({ projectRoot: tempDir, mode: 'offline', autoConfirm: true });
    expect(code).toBe(0);
    expect(downloadSpy).toHaveBeenCalled();

    const exePath = path.join(tempDir, 'ziptie.exe');
    expect(fs.existsSync(exePath)).toBe(true);

    const batchContent = fs.readFileSync(path.join(tempDir, 'ziptie-setup.bat'), 'utf8');
    expect(batchContent).toContain('ziptie.exe');
  });

  test('merges updated answers into existing config when confirmed', async () => {
    const configPath = path.join(tempDir, 'ziptie.config.json');
    const existing = {
      packageManager: { apps: ['Custom.Package'] },
      startupTask: { workingDir: 'C:\\OldDir', executable: 'old.exe' },
    };
    fs.writeFileSync(configPath, JSON.stringify(existing, null, 2), 'utf8');

    spyOn(prompts, 'confirm').mockResolvedValue(true as any);
    spyOn(prompts, 'text')
      .mockResolvedValueOnce('custom-pc')
      .mockResolvedValueOnce('launch.bat')
      .mockResolvedValueOnce('')
      .mockResolvedValueOnce('auto');

    const code = await runInit({ projectRoot: tempDir, mode: 'online' });
    expect(code).toBe(0);

    const merged = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    expect(merged.packageManager.apps).toEqual(['Custom.Package']);
    expect(merged.startupTask.workingDir).toBe('auto');
    expect(merged.startupTask.executable).toBe('launch.bat');
  });
});
