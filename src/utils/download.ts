import * as fs from 'node:fs';
import * as path from 'node:path';
import * as os from 'node:os';
import { execSync } from 'node:child_process';

export const LATEST_BINARY_URL =
  'https://github.com/littlevoid-io/ziptie/releases/latest/download/ziptie.exe';
export const LATEST_ZIP_URL =
  'https://github.com/littlevoid-io/ziptie/releases/latest/download/ziptie.zip';

function extractExeFromZip(zipPath: string, extractDir: string, destExe: string): void {
  const isWindows = process.platform === 'win32';
  if (isWindows) {
    execSync(
      `powershell -Command "Expand-Archive -Path '${zipPath}' -DestinationPath '${extractDir}' -Force"`,
      { stdio: 'ignore', windowsHide: true }
    );
  } else {
    execSync(`unzip -o "${zipPath}" -d "${extractDir}"`, { stdio: 'ignore' });
  }
  const extractedExe = path.join(extractDir, 'ziptie.exe');
  if (fs.existsSync(extractedExe)) {
    fs.copyFileSync(extractedExe, destExe);
  } else {
    throw new Error('ziptie.exe was not found inside release zip archive.');
  }
}

async function downloadAndExtractZip(destExe: string): Promise<void> {
  const response = await fetch(LATEST_ZIP_URL);
  if (!response.ok) {
    throw new Error(`Failed to download release zip: ${response.status} ${response.statusText}`);
  }
  const tempZip = path.join(os.tmpdir(), `ziptie-${Date.now()}.zip`);
  const tempDir = path.join(os.tmpdir(), `ziptie-${Date.now()}`);
  try {
    fs.writeFileSync(tempZip, Buffer.from(await response.arrayBuffer()));
    extractExeFromZip(tempZip, tempDir, destExe);
  } finally {
    fs.rmSync(tempZip, { force: true });
    fs.rmSync(tempDir, { recursive: true, force: true });
  }
}

export async function downloadBinary(
  destinationPath: string,
  downloadUrl: string = LATEST_BINARY_URL
): Promise<void> {
  const response = await fetch(downloadUrl);
  if (response.ok) {
    fs.writeFileSync(destinationPath, Buffer.from(await response.arrayBuffer()));
    return;
  }
  await downloadAndExtractZip(destinationPath);
}
