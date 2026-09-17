import * as fs from 'node:fs';
import * as path from 'node:path';
import deepmerge from 'deepmerge';
import { resolveProjectRoot } from './project.js';

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

function loadDefaultConfig(): any {
  const root = resolveProjectRoot();
  const defaultPath = path.join(root, 'ziptie.default.config.json');
  if (fs.existsSync(defaultPath)) {
    try {
      return JSON.parse(fs.readFileSync(defaultPath, 'utf8'));
    } catch {
      // Fall back to empty object
    }
  }
  return {};
}

export function mergeConfig(existingConfig: any, overrides: any): string {
  const merged = deepmerge(existingConfig, overrides, {
    arrayMerge: (_dest, source) => source,
  });
  return JSON.stringify(merged, null, 2) + '\n';
}

export function getConfigTemplate(overrides?: string | Record<string, any>): string {
  const baseConfig = loadDefaultConfig();
  let customOverrides: Record<string, any> = {};
  if (typeof overrides === 'string') {
    customOverrides = { system: { computerName: overrides } };
  } else if (overrides && typeof overrides === 'object') {
    customOverrides = overrides;
  }

  return mergeConfig(baseConfig, customOverrides);
}

export function getLaunchBatchTemplate(targetDirectory: string): string {
  const eggshellPath = path.join(targetDirectory, 'eggshell.config.ts');
  if (fs.existsSync(eggshellPath)) {
    return ['@echo off', 'cd /D "%~dp0"', 'call npx eggshell start', ''].join('\r\n');
  }

  const packagePath = path.join(targetDirectory, 'package.json');
  if (fs.existsSync(packagePath)) {
    try {
      const pkg = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
      if (pkg.scripts?.start) {
        return ['@echo off', 'cd /D "%~dp0"', 'call npm start', ''].join('\r\n');
      }
    } catch {
      // Fall through to default
    }
  }

  return ['@echo off', 'cd /D "%~dp0"', 'echo Launching exhibit...', ''].join('\r\n');
}
