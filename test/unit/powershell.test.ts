import { describe, test, expect, spyOn, mock, afterEach } from 'bun:test';
import * as child_process from 'node:child_process';
import { runPowerShellScript } from '../../src/utils/powershell.js';

describe('PowerShell Executor', () => {
  afterEach(() => {
    mock.restore();
  });

  test('assembles and runs standard lockdown commands safely', async () => {
    const spawnSpy = spyOn(child_process, 'spawn').mockImplementation((cmd: any, args: any) => {
      const mockProcess: any = {
        stdout: { on: (event: string, cb: Function) => cb(Buffer.from('')) },
        stderr: { on: (event: string, cb: Function) => cb(Buffer.from('')) },
        on: (event: string, cb: Function) => {
          if (event === 'close') cb(0);
        }
      };
      return mockProcess;
    });

    const scriptPath = 'scripts/windows/disable-widgets.ps1';
    const tempConfigPath = "C:\\path\\with'quotes\\temp.json";

    await runPowerShellScript(scriptPath, tempConfigPath, true, true, ['-CustomParam', 'Value']);

    // Assert spawn was called
    expect(spawnSpy).toHaveBeenCalled();

    const [spawnedCmd, spawnedArgs] = spawnSpy.mock.calls[0] as [string, string[]];
    expect(spawnedCmd).toBe('powershell.exe');

    // Confirm that the Command argument block was compiled properly
    const cmdIndex = spawnedArgs.indexOf('-Command');
    expect(cmdIndex).toBeGreaterThan(-1);
    
    const commandContent = spawnedArgs[cmdIndex + 1];
    
    // Quotes must be escaped to double single-quotes for PowerShell strings
    expect(commandContent).toContain("with''quotes");
    
    // Standard parameters must be propagated
    expect(commandContent).toContain('-Config $config');
    expect(commandContent).toContain('-DryRun');
    expect(commandContent).toContain('-Undo');
    expect(commandContent).toContain('-CustomParam Value');
  });

  test('rejects execution cleanly if child process returns a non-zero exit code', async () => {
    spyOn(child_process, 'spawn').mockImplementation((cmd: any, args: any) => {
      const mockProcess: any = {
        stdout: { on: (event: string, cb: Function) => {} },
        stderr: { on: (event: string, cb: Function) => cb(Buffer.from('Access is denied.')) },
        on: (event: string, cb: Function) => {
          if (event === 'close') cb(1); // Exited with error code
        }
      };
      return mockProcess;
    });

    expect(runPowerShellScript('script.ps1', 'config.json', false, false)).rejects.toThrow('Access is denied.');
  });
});
