import * as fs from 'node:fs';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';

/**
 * Resolves the absolute project root directory by scanning standard locations.
 */
export function resolveProjectRoot(): string {
  let currentFileDir = '';
  try {
    currentFileDir = path.dirname(fileURLToPath(import.meta.url));
  } catch {
    currentFileDir = __dirname;
  }

  let projectRoot = path.resolve(currentFileDir, '..');

  if (!fs.existsSync(path.join(projectRoot, 'ziptie.default.config.json'))) {
    const exeDir = path.dirname(process.execPath);
    projectRoot = path.resolve(exeDir, '..');
    if (!fs.existsSync(path.join(projectRoot, 'ziptie.default.config.json'))) {
      projectRoot = exeDir;
    }
  }

  if (!fs.existsSync(path.join(projectRoot, 'ziptie.default.config.json'))) {
    projectRoot = process.cwd();
  }

  return projectRoot;
}
