import * as fs from "node:fs";
import * as path from "node:path";
import * as http from "node:http";
import { exec, execSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const projectRoot = path.resolve(__dirname, "..");
const wsbPath = path.join(projectRoot, ".tmp", "slab-sandbox-installer.wsb");

// Ensure .tmp exists
const tmpDir = path.join(projectRoot, ".tmp");
if (!fs.existsSync(tmpDir)) {
  fs.mkdirSync(tmpDir, { recursive: true });
}

console.log("\x1b[36m[Local Release Packaging]\x1b[0m Compiling dist/slab.exe...");
try {
  execSync("npm run package", { cwd: projectRoot, stdio: "inherit" });
} catch (err) {
  console.error(`\x1b[31mFailed to compile slab.exe:\x1b[0m ${err.message}`);
  process.exit(1);
}

console.log("\x1b[36m[Local Release Packaging]\x1b[0m Packaging dist/slab.zip...");
try {
  execSync(
    'powershell -Command "Compress-Archive -Path dist/slab.exe, scripts, src/powershell, slab.default.config.json, slab-schema.json, setup.bat -DestinationPath dist/slab.zip -Force"',
    { cwd: projectRoot, stdio: "inherit" }
  );
  console.log("\x1b[32mSuccessfully packaged dist/slab.zip locally.\x1b[0m\n");
} catch (err) {
  console.error(`\x1b[31mFailed to package slab.zip:\x1b[0m ${err.message}`);
  process.exit(1);
}

// Start a local HTTP server to serve the bootstrap script and the zip archive
const server = http.createServer((req, res) => {
  const host = req.headers.host || "10.0.3.2:8080";
  
  if (req.url === "/bootstrap.ps1") {
    console.log(`\x1b[36m[Server]\x1b[0m Serving bootstrap.ps1 to guest...`);
    const filepath = path.join(projectRoot, "scripts", "bootstrap.ps1");
    let content = fs.readFileSync(filepath, "utf8");
    
    // Dynamically replace remote URLs with our local HTTP server addresses
    content = content.replace(
      /https:\/\/raw\.githubusercontent\.com\/littlevoid-io\/slab\/main\/scripts\/bootstrap\.ps1/g,
      `http://${host}/bootstrap.ps1`
    );
    content = content.replace(
      /https:\/\/github\.com\/littlevoid-io\/slab\/releases\/latest\/download\/slab\.zip/g,
      `http://${host}/slab.zip`
    );
    
    res.writeHead(200, { "Content-Type": "text/plain" });
    res.end(content);
  } else if (req.url === "/slab.zip") {
    console.log(`\x1b[36m[Server]\x1b[0m Serving slab.zip download to guest...`);
    const filepath = path.join(projectRoot, "dist", "slab.zip");
    const stat = fs.statSync(filepath);
    
    res.writeHead(200, {
      "Content-Type": "application/zip",
      "Content-Length": stat.size
    });
    
    const stream = fs.createReadStream(filepath);
    stream.pipe(res);
  } else {
    res.writeHead(404);
    res.end();
  }
});

server.listen(8080, "0.0.0.0", () => {
  console.log("\x1b[32m[Server] Local HTTP server is running on port 8080.\x1b[0m");
  
  // Generate WSB config that fetches from the host's default gateway IP dynamically
  const wsbContent = `<Configuration>
  <Networking>Default</Networking>
  <LogonCommand>
    <Command>powershell.exe -ExecutionPolicy Bypass -NoExit -Command "Start-Process powershell.exe -ArgumentList '-ExecutionPolicy Bypass -NoExit -Command \\\"$gw = (Get-NetRoute -DestinationPrefix ''0.0.0.0/0'' | Select-Object -First 1).NextHop; Write-Host ''Fetching bootstrap installer from host gateway (http://$gw:8080/bootstrap.ps1)...'' -ForegroundColor Cyan; irm http://$gw:8080/bootstrap.ps1 | iex\\\"' -Verb RunAs"</Command>
  </LogonCommand>
</Configuration>
`;

  try {
    fs.writeFileSync(wsbPath, wsbContent, "utf8");
    console.log(`\x1b[32mSuccessfully generated dynamic installer Sandbox WSB file at:\x1b[0m ${wsbPath}`);
    console.log("Launching clean Windows Sandbox... Please wait.");
    console.log("\x1b[33mKeep this terminal open to serve files to the Sandbox. Press Ctrl+C to stop the server when done.\x1b[0m\n");

    // Launch WSB via OS shell file association
    exec(`start "" "${wsbPath}"`, (error) => {
      if (error) {
        console.error(`\x1b[31mFailed to launch Windows Sandbox:\x1b[0m ${error.message}`);
        server.close();
        process.exit(1);
      }
      console.log("\x1b[32mClean Windows Sandbox spawned successfully! The one-line installer will execute inside the guest context.\x1b[0m");
    });
  } catch (err) {
    console.error(`\x1b[31mError generating Sandbox file:\x1b[0m ${err.message}`);
    server.close();
    process.exit(1);
  }
});
