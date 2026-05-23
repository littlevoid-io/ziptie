import * as fs from "node:fs";
import * as path from "node:path";
import { exec } from "node:child_process";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Project root is one level up from "test"
const projectRoot = path.resolve(__dirname, "..");
const wsbPath = path.join(projectRoot, ".tmp", "ziptie-sandbox.wsb");

// Ensure .tmp exists
const tmpDir = path.join(projectRoot, ".tmp");
if (!fs.existsSync(tmpDir)) {
  fs.mkdirSync(tmpDir, { recursive: true });
}

// Determine if we should automatically execute the test script
const runTests = process.argv.includes("--run-tests");
const targetFolder = "C:\\Users\\WDAGUtilityAccount\\Desktop\\ziptie";

// Logon Command configuration
const commandToRun = runTests
  ? `Start-Process powershell.exe -ArgumentList '-ExecutionPolicy Bypass -NoExit -File ${targetFolder}\\test\\run-sandbox-tests.ps1' -WorkingDirectory ${targetFolder} -Verb RunAs`
  : `Start-Process powershell.exe -ArgumentList '-ExecutionPolicy Bypass -NoExit' -WorkingDirectory ${targetFolder} -Verb RunAs`;

// Generate the Windows Sandbox XML content dynamically
const wsbContent = `<Configuration>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>${projectRoot}</HostFolder>
      <SandboxFolder>${targetFolder}</SandboxFolder>
      <ReadOnly>false</ReadOnly>
    </MappedFolder>
  </MappedFolders>
  <LogonCommand>
    <Command>powershell.exe -ExecutionPolicy Bypass -NoExit -Command "${commandToRun}"</Command>
  </LogonCommand>
</Configuration>
`;

try {
  fs.writeFileSync(wsbPath, wsbContent, "utf8");
  console.log(`\x1b[32mSuccessfully generated dynamic Sandbox WSB file at:\x1b[0m ${wsbPath}`);
  console.log(`\x1b[36mHost folder mapped to Desktop:\x1b[0m ${projectRoot}`);
  if (runTests) {
    console.log("\x1b[33mConfiguration: Automatically running automated integration tests at logon.\x1b[0m");
  } else {
    console.log("\x1b[33mConfiguration: Interactive session. Test script will NOT run automatically (open elevated terminal ready).\x1b[0m");
  }
  console.log("Launching Windows Sandbox... Please wait.");

  // Launch WSB via OS shell file association
  exec(`start "" "${wsbPath}"`, (error) => {
    if (error) {
      console.error(`\x1b[31mFailed to launch Windows Sandbox:\x1b[0m ${error.message}`);
      process.exit(1);
    }
    console.log("\x1b[32mWindows Sandbox spawned successfully!\x1b[0m");
  });
} catch (err) {
  console.error(`\x1b[31mError generating Sandbox file:\x1b[0m ${err.message}`);
  process.exit(1);
}
