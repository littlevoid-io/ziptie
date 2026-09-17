import * as fs from 'node:fs';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, '..');

// Helper to recursively list files in a directory
function getFilesRecursive(dir, fileList = []) {
  const files = fs.readdirSync(dir);
  for (const file of files) {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);
    if (stat.isDirectory()) {
      getFilesRecursive(filePath, fileList);
    } else {
      fileList.push(filePath);
    }
  }
  return fileList;
}

const assets = {};

// 1. Scan scripts directory
const scriptsDir = path.join(projectRoot, 'scripts');
if (fs.existsSync(scriptsDir)) {
  const files = getFilesRecursive(scriptsDir);
  for (const file of files) {
    const relPath = path.relative(projectRoot, file).replace(/\\/g, '/');
    // Ignore build/release scripts that are not run on target machines
    if (relPath === 'scripts/release.js' || relPath === 'scripts/build-assets.js') {
      continue;
    }
    const content = fs.readFileSync(file);
    assets[relPath] = content.toString('base64');
  }
}

// 2. Add config and schema files
const configFiles = ['ziptie.default.config.json', 'ziptie.schema.json', 'ziptie.animation.json'];
for (const confFile of configFiles) {
  const filePath = path.join(projectRoot, confFile);
  if (fs.existsSync(filePath)) {
    const content = fs.readFileSync(filePath);
    assets[confFile] = content.toString('base64');
  }
}

// 3. Generate the output JSON file content in dist/
const outputDir = path.join(projectRoot, 'dist');
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

const pkg = JSON.parse(fs.readFileSync(path.join(projectRoot, 'package.json'), 'utf8'));
const version = pkg.version || '1.0.0';

// Ensure src/version.ts is synchronized with package.json
const versionFilePath = path.join(projectRoot, 'src', 'version.ts');
const versionContent = `export const VERSION = '${version}';\n`;
if (
  !fs.existsSync(versionFilePath) ||
  fs.readFileSync(versionFilePath, 'utf8') !== versionContent
) {
  fs.writeFileSync(versionFilePath, versionContent, 'utf8');
}

fs.writeFileSync(path.join(outputDir, 'assets.json'), JSON.stringify(assets, null, 2), 'utf8');
console.log(
  `Successfully generated dist/assets.json with ${Object.keys(assets).length} embedded assets (version ${version})!`
);
