import * as fs from 'node:fs';
import * as path from 'node:path';

export interface DetectedStartup {
  executable: string;
  args: string[];
  offerBatch: boolean;
}

export function detectProjectName(targetDirectory: string): string {
  const packagePath = path.join(targetDirectory, 'package.json');
  if (fs.existsSync(packagePath)) {
    try {
      const pkg = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
      if (pkg.name) {
        return pkg.name.replace(/^@[^/]+\//, '').replace(/[^a-zA-Z0-9-]/g, '-');
      }
    } catch {
      // Fallback on read failure
    }
  }
  const baseName = path.basename(targetDirectory).replace(/[^a-zA-Z0-9-]/g, '-');
  return baseName && baseName !== '.' ? baseName : 'exhibit';
}

export function loadExistingConfig(targetDirectory: string): any | null {
  const configPath = path.join(targetDirectory, 'ziptie.config.json');
  if (fs.existsSync(configPath)) {
    try {
      return JSON.parse(fs.readFileSync(configPath, 'utf8'));
    } catch {
      return null;
    }
  }
  return null;
}

function checkBatchFiles(targetDirectory: string): string | null {
  const candidateBatchFiles = ['launch.bat', 'start.bat', 'run.bat'];
  for (const file of candidateBatchFiles) {
    if (fs.existsSync(path.join(targetDirectory, file))) {
      return file;
    }
  }
  return null;
}

function checkPackageLaunch(targetDirectory: string): boolean {
  const packagePath = path.join(targetDirectory, 'package.json');
  const eggshellPath = path.join(targetDirectory, 'eggshell.config.ts');
  if (fs.existsSync(eggshellPath)) return true;
  if (fs.existsSync(packagePath)) {
    try {
      const pkg = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
      return Boolean(pkg.scripts?.start || pkg.dependencies?.['@littlevoid/eggshell']);
    } catch {
      return false;
    }
  }
  return false;
}

export function detectStartupDetails(targetDirectory: string): DetectedStartup {
  const existingBatch = checkBatchFiles(targetDirectory);
  if (existingBatch) {
    return {
      executable: existingBatch,
      args: [],
      offerBatch: false,
    };
  }

  const hasPackageLaunch = checkPackageLaunch(targetDirectory);
  return {
    executable: 'launch.bat',
    args: [],
    offerBatch: hasPackageLaunch || !fs.existsSync(path.join(targetDirectory, 'launch.bat')),
  };
}
