import { describe, test, expect, spyOn, mock, afterEach } from 'bun:test';
import * as fs from 'node:fs';
import * as child_process from 'node:child_process';
import * as prompts from '@clack/prompts';
import { runSetupWizard } from '../../src/utils/setupWizard.js';

describe('Setup Wizard', () => {
  afterEach(() => {
    mock.restore();
  });

  test('returns default configuration if user chooses defaults', async () => {
    // Mock fs functions
    const mockDefaultConfig = {
      system: { computerName: 'DEFAULT-PC', timezone: 'UTC' }
    };
    spyOn(fs, 'readFileSync').mockImplementation(() => JSON.stringify(mockDefaultConfig));

    // Mock clack prompts to select 'defaults'
    const selectSpy = spyOn(prompts, 'select').mockResolvedValue('defaults' as any);
    const noteSpy = spyOn(prompts, 'note').mockImplementation(() => {});

    const result = await runSetupWizard('defaultConfig.json', 'userConfig.json');

    expect(selectSpy).toHaveBeenCalled();
    expect(result).toEqual(mockDefaultConfig);
  });

  test('saves customized settings when user goes through interactive CLI path', async () => {
    const mockDefaultConfig = {
      system: { computerName: 'DEFAULT-PC', timezone: 'UTC' },
      autologon: { username: 'exhibit' },
      startupTask: { executable: 'launch.bat', workingDir: 'C:\\Exhibit' }
    };
    spyOn(fs, 'readFileSync').mockImplementation(() => JSON.stringify(mockDefaultConfig));
    const writeSpy = spyOn(fs, 'writeFileSync').mockImplementation(() => {});

    // Mock prompt functions
    const selectSpy = spyOn(prompts, 'select').mockResolvedValue('cli' as any);
    const noteSpy = spyOn(prompts, 'note').mockImplementation(() => {});
    
    // Simulate user answering CLI questions
    const textSpy = spyOn(prompts, 'text')
      .mockResolvedValueOnce('CUSTOM-EXHIBIT-PC') // computerName
      .mockResolvedValueOnce('Tokyo Standard Time') // timezone
      .mockResolvedValueOnce('kiosk-user')          // username
      .mockResolvedValueOnce('exhibit.exe')         // executable
      .mockResolvedValueOnce('C:\\ExhibitPath');     // workingDir

    const result = await runSetupWizard('defaultConfig.json', 'userConfig.json');

    expect(selectSpy).toHaveBeenCalled();
    expect(textSpy).toHaveBeenCalledTimes(5);
    expect(writeSpy).toHaveBeenCalled();

    // Verify written data matches expected merge results
    const lastCallArg = JSON.parse(writeSpy.mock.calls[0][1] as string);
    expect(lastCallArg.system.computerName).toBe('CUSTOM-EXHIBIT-PC');
    expect(lastCallArg.system.timezone).toBe('Tokyo Standard Time');
    expect(lastCallArg.autologon.username).toBe('kiosk-user');
    expect(lastCallArg.startupTask.executable).toBe('exhibit.exe');
    expect(lastCallArg.startupTask.workingDir).toBe('C:\\ExhibitPath');
  });

  test('validates computer name input formats correctly', async () => {
    const mockDefaultConfig = {
      system: { computerName: 'DEFAULT-PC', timezone: 'UTC' },
      autologon: { username: 'exhibit' },
      startupTask: { executable: 'launch.bat', workingDir: 'C:\\Exhibit' }
    };
    spyOn(fs, 'readFileSync').mockImplementation(() => JSON.stringify(mockDefaultConfig));

    // Retrieve the validation function for computer name
    let validator: any = null;
    spyOn(prompts, 'select').mockResolvedValue('cli' as any);
    spyOn(prompts, 'note').mockImplementation(() => {});
    spyOn(prompts, 'text').mockImplementation((options: any) => {
      if (options.message === 'Computer name:') {
        validator = options.validate;
      }
      return Promise.resolve('VALID-NAME');
    });
    // Mock the exit call to prevent termination
    spyOn(process, 'exit').mockImplementation(() => undefined as never);

    await runSetupWizard('defaultConfig.json', 'userConfig.json');

    expect(validator).toBeTypeOf('function');
    
    // Verify validator assertions
    expect(validator('')).toBe('Computer name cannot be empty.');
    expect(validator(' ')).toBe('Computer name cannot be empty.');
    expect(validator('INVALID NAME!')).toBe('Computer name can only contain alphanumeric characters and hyphens.');
    expect(validator('VALID-PC-01')).toBeUndefined();
  });
});
