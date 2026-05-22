import { spawn } from 'child_process';
import { existsSync } from 'fs';
import { join } from 'path';

// Load .env if it exists
if (existsSync('.env')) {
  try {
    process.loadEnvFile();
  } catch (err) {
    console.warn('Warning: Failed to load .env file:', err.message);
  }
}

// Spawn release-it as a child process so it has full terminal control
const releaseItPath = join('node_modules', 'release-it', 'bin', 'release-it.js');
const child = spawn('node', [releaseItPath, ...process.argv.slice(2)], {
  stdio: 'inherit',
  shell: false
});

child.on('exit', (code) => {
  process.exit(code ?? 0);
});
