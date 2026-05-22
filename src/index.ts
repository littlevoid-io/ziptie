import * as fs from "node:fs";
import * as path from "node:path";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import sudo from "sudo-prompt";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const args = process.argv.slice(2);
const hasFlag = (flag: string, short: string) => args.includes(flag) || args.includes(short);
const getArgValue = (flag: string, short: string): string | null => {
    const idx = args.findIndex(a => a === flag || a === short);
    if (idx !== -1 && idx + 1 < args.length) {
        return args[idx + 1];
    }
    return null;
};

const dryRun = hasFlag("--dry-run", "-d");
const undo = hasFlag("--undo", "-u");
const customConfigPath = getArgValue("--config", "-c");

const defaultConfig = {
  system: {
    computerName: "EXHIBIT-PC-01",
    timezone: "Eastern Standard Time",
    enableDailyReboot: false,
    rebootTime: "03:00"
  },
  autologon: {
    enabled: false,
    username: "exhibit",
    disablePasswordlessHello: true
  },
  startupTask: {
    enabled: true,
    workingDir: "C:\\Exhibit",
    executable: "launch.bat",
    trigger: "AtLogon",
    delay: "PT1M"
  },
  packageManager: {
    provider: "winget",
    allowOfflineFallback: true,
    localInstallersPath: ".\\installers",
    apps: ["Node.js", "Git.Git"]
  },
  lockdown: {
    disableScreensaver: true,
    disableAccessibilityShortcuts: true,
    disableEdgeSwipes: true,
    disableTouchFeedback: true,
    disableWindowsUpdate: true,
    disableWindowsWidgets: true,
    disableCopilotRecall: true,
    disableOOBEPrompts: true,
    clearDesktopIcons: true,
    blackDesktopBackground: true,
    configureExplorer: true,
    disableAppInstalls: true,
    disableAppRestore: true,
    disableErrorReporting: true,
    disableFirewall: false,
    disableMaxPathLength: true,
    disableNewNetworkWindow: true,
    disableNotifications: true,
    disableTouchGestures: true,
    enableScriptExecution: true,
    resetTextScale: true,
    uninstallBloatware: true,
    uninstallOneDrive: true,
    unpinStartMenuApps: true,
    setPowerSettings: true
  }
};

async function main() {
  if (process.platform !== "win32") {
    console.error("Error: Slab currently only supports Windows 11 / Windows 10.");
    process.exit(1);
  }

  const configFilePath = customConfigPath 
    ? path.resolve(customConfigPath) 
    : path.resolve(process.cwd(), "slab-config.json");

  console.log(`Searching for slab configuration at: ${configFilePath}`);
  
  let userConfig: any = {};
  if (fs.existsSync(configFilePath)) {
    try {
      const content = fs.readFileSync(configFilePath, "utf8");
      userConfig = JSON.parse(content);
      console.log("Successfully loaded user configuration.");
    } catch (e: any) {
      console.error(`Error parsing config file: ${e.message}`);
      process.exit(1);
    }
  } else {
    console.log("No config file found. Using default configurations.");
  }

  const mergedConfig = {
    ...defaultConfig,
    ...userConfig,
    system: { ...defaultConfig.system, ...userConfig.system },
    autologon: { ...defaultConfig.autologon, ...userConfig.autologon },
    startupTask: { ...defaultConfig.startupTask, ...userConfig.startupTask },
    packageManager: { ...defaultConfig.packageManager, ...userConfig.packageManager },
    lockdown: { ...defaultConfig.lockdown, ...userConfig.lockdown }
  };

  const tmpDir = path.resolve(process.cwd(), ".tmp");
  if (!fs.existsSync(tmpDir)) {
    fs.mkdirSync(tmpDir, { recursive: true });
  }

  const resolvedConfigPath = path.join(tmpDir, "slab-temp-config.json");
  fs.writeFileSync(resolvedConfigPath, JSON.stringify(mergedConfig, null, 2), "utf8");
  console.log(`Resolved configuration written to: ${resolvedConfigPath}`);

  let projectRoot = path.resolve(__dirname, "..");
  if (!fs.existsSync(path.join(projectRoot, "slab.ps1"))) {
    projectRoot = process.cwd();
  }
  const slabPs1Path = path.join(projectRoot, "slab.ps1");

  if (!fs.existsSync(slabPs1Path)) {
    console.error(`Error: Could not locate slab.ps1 at ${slabPs1Path}`);
    process.exit(1);
  }

  if (dryRun) {
    console.log("Running in Dry-Run mode. Spawning PowerShell directly...");
    const child = spawn("PowerShell.exe", ["-ExecutionPolicy", "Bypass", "-File", `"${slabPs1Path}"`, "-ConfigPath", `"${resolvedConfigPath}"`, "-DryRun"], {
      stdio: "inherit",
      shell: true
    });
    child.on("exit", (code) => {
      process.exit(code ?? 0);
    });
  } else {
    console.log("Elevation required. Triggering UAC elevation for Slab...");
    const runCmd = `cmd.exe /c start /wait powershell.exe -ExecutionPolicy Bypass -NoExit -File "${slabPs1Path}" -ConfigPath "${resolvedConfigPath}"${undo ? " -Undo" : ""}`;
    
    sudo.exec(
      runCmd,
      {
        name: "Slab Kiosk Lockdown Engine"
      },
      (error, stdout, stderr) => {
        if (error) {
          console.error(`Elevation failed: ${error.message}`);
          process.exit(1);
        }
        if (stdout) console.log(stdout);
        if (stderr) console.error(stderr);
        console.log("Slab execution complete.");
      }
    );
  }
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
