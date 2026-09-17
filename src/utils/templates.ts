export type SetupMode = 'offline' | 'online' | 'npm';

export function getBatchTemplate(mode: SetupMode): string {
  if (mode === 'offline') {
    return [
      '@echo off',
      'cd /D "%~dp0"',
      'if exist "%~dp0ziptie.exe" (',
      '    "%~dp0ziptie.exe" %*',
      '    exit /b %ERRORLEVEL%',
      ')',
      'echo Error: ziptie.exe not found in %~dp0',
      'exit /b 1',
      '',
    ].join('\r\n');
  }

  if (mode === 'npm') {
    return ['@echo off', 'cd /D "%~dp0"', 'call npx @littlevoid/ziptie %*', ''].join('\r\n');
  }

  return [
    '@echo off',
    'cd /D "%~dp0"',
    'powershell -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((irm https://raw.githubusercontent.com/littlevoid-io/ziptie/main/scripts/bootstrap.ps1))) -WorkingDir \'%~dp0\' %*"',
    '',
  ].join('\r\n');
}

export function getConfigTemplate(computerName?: string): string {
  const name = computerName || 'exhibit-pc-01';
  return (
    JSON.stringify(
      {
        $schema: 'https://raw.githubusercontent.com/littlevoid-io/ziptie/main/ziptie.schema.json',
        system: {
          computerName: name,
          timezone: 'auto',
          dailyReboot: true,
          rebootTime: '06:00',
          rebootOnFinish: false,
        },
        autologon: {
          enabled: true,
          username: 'auto',
          disablePasswordlessHello: true,
        },
        startupTask: {
          enabled: true,
          workingDir: 'C:\\Exhibit',
          executable: 'launch.bat',
          args: [],
          trigger: 'AtLogon',
          delay: 'PT1M',
        },
        packageManager: {
          provider: 'winget',
          allowOfflineFallback: true,
          localInstallersPath: '.\\installers',
          apps: ['CoreyButler.NVMforWindows', 'Microsoft.VisualStudioCode', 'Git.Git'],
        },
        windows: {
          disableScreensaver: true,
          disableAccessibilityShortcuts: true,
          disableEdgeSwipes: true,
          disableTouchFeedback: true,
          disableSystemSounds: true,
          disableWindowsUpdate: true,
          disableWindowsWidgets: true,
          disableCopilotRecall: true,
          disableOOBEPrompts: true,
          clearDesktopIcons: true,
          solidColorBackground: '#333333',
          enableDarkMode: true,
          configureExplorer: true,
          disableAppInstalls: true,
          disableAppRestore: true,
          disableErrorReporting: true,
          disableFirewall: false,
          disableMaxPathLength: true,
          disableNewNetworkWindow: true,
          disableNotifications: true,
          disableTouchGestures: true,
          enableScriptExecution: true,
          resetTextScale: true,
          uninstallBloatware: true,
          uninstallOneDrive: true,
          unpinStartMenuApps: true,
          setPowerSettings: true,
        },
      },
      null,
      2
    ) + '\n'
  );
}
