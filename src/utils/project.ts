import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { fileURLToPath } from 'node:url';
import { EMBEDDED_ASSETS } from '../assets.js';

/**
 * Extracts all embedded assets to the target directory.
 */
function extractAssets(targetDir: string): void {
  for (const [relPath, base64Content] of Object.entries(EMBEDDED_ASSETS)) {
    const fullPath = path.join(targetDir, relPath);
    const parentDir = path.dirname(fullPath);
    
    if (!fs.existsSync(parentDir)) {
      fs.mkdirSync(parentDir, { recursive: true });
    }
    
    const buffer = Buffer.from(base64Content, 'base64');
    fs.writeFileSync(fullPath, buffer);
  }
}

/**
 * Resolves the absolute project root directory by scanning standard locations.
 * If running in standalone compiled mode, it extracts embedded assets to a temporary directory.
 */
export function resolveProjectRoot(): string {
  let currentFileDir = '';
  try {
    currentFileDir = path.dirname(fileURLToPath(import.meta.url));
  } catch {
    currentFileDir = __dirname;
  }

  // Define potential local project roots (useful in development or if zip is extracted)
  const exeDir = path.dirname(process.execPath);
  const potentialRoots = [
    path.resolve(currentFileDir, '..', '..'), // repo root relative to dist/utils or src/utils
    path.resolve(currentFileDir, '..'),       // repo root relative to dist or src
    exeDir,                                    // next to executable
    path.resolve(exeDir, '..'),                // parent of executable dir
    process.cwd()                              // current working directory
  ];

  // Try to find a local project root that has both the scripts folder and ziptie.default.config.json
  if (process.env.ZIPTIE_USE_EMBEDDED !== 'true') {
    for (const root of potentialRoots) {
      if (
        fs.existsSync(path.join(root, 'scripts')) &&
        fs.existsSync(path.join(root, 'ziptie.default.config.json'))
      ) {
        return root;
      }
    }
  }

  // If no local project root is found (standalone mode), extract embedded assets to temp dir
  const tempExtractDir = path.join(os.tmpdir(), 'ziptie-extracted');
  
  // Extract all assets
  extractAssets(tempExtractDir);

  return tempExtractDir;
}
