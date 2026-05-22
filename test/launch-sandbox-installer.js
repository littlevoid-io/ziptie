import * as fs from "node:fs";
import * as path from "node:path";
import { exec } from "node:child_process";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Project root is one level up from "test"
const projectRoot = path.resolve(__dirname, "..");
const wsbPath = path.join(projectRoot, ".tmp", "slab-sandbox-installer.wsb");

// Ensure .tmp exists
const tmpDir = path.join(projectRoot, ".tmp");
if (!fs.existsSync(tmpDir)) {
  fs.mkdirSync(tmpDir, { recursive: true });
}

// Generate the Windows Sandbox XML content dynamically without mapped folders
const wsbContent = `<Configuration>
  <Networking>Default</Networking>
  <LogonCommand>
    <Command>powershell.exe -ExecutionPolicy Bypass -NoExit -Command "Start-Process powershell.exe -ArgumentList '-ExecutionPolicy Bypass -NoExit -Command \\\"irm https://raw.githubusercontent.com/littlevoid-io/slab/main/scripts/bootstrap.ps1 | iex\\\"' -Verb RunAs"</Command>
  </LogonCommand>
</Configuration>
`;

try {
  fs.writeFileSync(wsbPath, wsbContent, "utf8");
  console.log(`\x1b[32mSuccessfully generated dynamic installer Sandbox WSB file at:\x1b[0m ${wsbPath}`);
  console.log("Launching clean Windows Sandbox... Please wait.");

  // Launch WSB via OS shell file association
  exec(`start "" "${wsbPath}"`, (error) => {
    if (error) {
      console.error(`\x1b[31mFailed to launch Windows Sandbox:\x1b[0m ${error.message}`);
      process.exit(1);
    }
    console.log("\x1b[32mClean Windows Sandbox spawned successfully! The one-line installer will execute inside the guest context directly fetching from GitHub.\x1b[0m");
  });
} catch (err) {
  console.error(`\x1b[31mError generating Sandbox file:\x1b[0m ${err.message}`);
  process.exit(1);
}
