import { describe, test, expect, spyOn, mock, afterEach } from 'bun:test';
import * as child_process from 'node:child_process';
import { isAdmin, ensureElevated } from '../../src/utils/elevation.js';

describe('Elevation Checker', () => {
  afterEach(() => {
    mock.restore();
  });

  test('isAdmin returns true when net session succeeds', () => {
    const execSpy = spyOn(child_process, 'execSync').mockImplementation(() => Buffer.from(''));
    
    const result = isAdmin();
    
    expect(result).toBe(true);
    expect(execSpy).toHaveBeenCalledWith('net session', { stdio: 'ignore', windowsHide: true });
  });

  test('isAdmin returns false when net session throws an error', () => {
    spyOn(child_process, 'execSync').mockImplementation(() => {
      throw new Error('Access is denied.');
    });
    
    const result = isAdmin();
    
    expect(result).toBe(false);
  });

  test('ensureElevated bypasses logic on non-Windows platforms', () => {
    const originalPlatform = process.platform;
    Object.defineProperty(process, 'platform', { value: 'darwin' });

    const execSpy = spyOn(child_process, 'execSync').mockImplementation(() => Buffer.from(''));

    try {
      ensureElevated(false);
      // Verify that net session checks were bypassed
      expect(execSpy).not.toHaveBeenCalled();
    } finally {
      Object.defineProperty(process, 'platform', { value: originalPlatform });
    }
  });

  test('ensureElevated bypasses logic in dry-run mode', () => {
    const execSpy = spyOn(child_process, 'execSync').mockImplementation(() => {
      throw new Error('Access is denied.');
    });
    
    const exitSpy = spyOn(process, 'exit').mockImplementation(() => undefined as never);

    // Should return immediately without UAC spawning or exit since dry-run is safe
    ensureElevated(true);
    
    // Net session is called to check isAdmin, but UAC is not spawned and exit is not called
    expect(execSpy).toHaveBeenCalledWith('net session', { stdio: 'ignore', windowsHide: true });
    expect(exitSpy).not.toHaveBeenCalled();
  });

  test('ensureElevated UAC triggers UAC self-spawn and exits when non-admin', () => {
    const originalPlatform = process.platform;
    Object.defineProperty(process, 'platform', { value: 'win32' });

    // Mock console.log to avoid polluting test output
    spyOn(console, 'log').mockImplementation(() => {});

    // Mock non-admin state
    const execSpy = spyOn(child_process, 'execSync').mockImplementation((cmd: any) => {
      if (cmd === 'net session') throw new Error('Not admin');
      return Buffer.from('');
    });

    const exitSpy = spyOn(process, 'exit').mockImplementation(() => undefined as never);

    try {
      ensureElevated(false);

      // Verify that execSync was called to spawn elevated process
      expect(execSpy).toHaveBeenCalled();
      
      const lastCallCmd = execSpy.mock.calls[execSpy.mock.calls.length - 1][0] as string;
      expect(lastCallCmd).toContain('Start-Process');
      expect(lastCallCmd).toContain('-Verb RunAs');

      // Verify it terminated current process safely
      expect(exitSpy).toHaveBeenCalledWith(0);
    } finally {
      Object.defineProperty(process, 'platform', { value: originalPlatform });
    }
  });
});
