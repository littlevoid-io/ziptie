# slab
## Goals, Architecture, and Agent Mandates

`slab` is a modern, quirky, zero-dependency, and air-gap friendly Windows 11 system bootstrapping and kiosk lockdown framework. It is a complete modernization and port of the legacy Bluecadet `@bluecadet/launchpad-scaffold` (also referred to as `little-bootstrap`).

Just like a physical concrete slab, it is poured directly over raw ground (Windows 11) to establish an unshakeable, flat, clean, and perfectly leveled foundation supporting high-fidelity interactive museum exhibits, gallery installations, and unattended digital signage.

---

## 1. Core Vision & Goals

The legacy tool was a collection of shell scripts cobbled together over years of Windows 8 and Windows 10 updates. Windows 11 has introduced major architectural shifts, stricter security defaults (like Windows Hello), and different structures for widgets, telemetry, and updates. 

`slab` targets **three core goals**:

1. **Modern Windows 11 Compliance & Support**
   - Eliminate obsolete Windows 8/10 tweaks (such as Cortana, the legacy Win 8 Start Page, or outdated namespace folder registry hacks).
   - Implement robust modern overrides for Windows 11 features (such as Taskbar Widgets, Web Experience app, personalized ads, and Copilot/Recall).
   - Use stable, official Group Policy registry keys and CSP/WMI policies instead of raw, destructive registry hacks wherever possible.

2. **Portable, Air-Gapped, and Local-First Deployment**
   - **Air-Gapped Operation**: Exhibits in galleries and museums are often kept on closed networks without internet access for security. `slab` never requires an active internet connection to configure settings.
   - **Local Installer Support**: Support bundling offline software installers (`.msi`, `.exe`) in a portable `./installers/` folder and executing silent installations locally, completely bypassing dynamic online downloads like standard Chocolatey installs.
   - **Offline Winget Integration**: Leverage built-in Windows 11 Winget capabilities using local manifests or pre-downloaded package files.

3. **Streamlined Declarative Configuration & CLI**
   - **Declarative Standard**: Move away from executable PowerShell configuration files (`defaults.ps1` / `user.ps1`), which introduce security risks (arbitrary code execution) and syntax-error vulnerabilities.
   - **JSON / YAML Configurations**: Re-implement configuration as a structured, parseable JSON or YAML file (e.g., `slab.config.json`).
   - **JSON Schema Validation**: Ship a detailed JSON Schema alongside the package. When developers edit the configuration in VS Code, they receive immediate autocompletion, real-time type validation, and embedded documentation for every single configuration flag.
   - **Non-blocking Execution**: Ensure that the bootstrapper can run headlessly and silently (e.g., via RMM or remote shell) by removing interactive blocks like pop-up notepad windows.

---

## 2. Agent Research Findings & Architecture

During the initialization of this project, three specialized AI agents were deployed to establish our technical blueprint. Below are their compiled insights and architectural decisions.

### A. Tech Director Agent: Legacy Code & OS Drift Analysis
The Tech Director analyzed the legacy codebase (`setup.ps1`, `scripts/windows/*`, and `config/*`) and highlighted key issues:
- **Session 0 Hazard**: The legacy setup configured startup tasks to trigger `-AtStartup` via Task Scheduler. This causes Windows to run the exhibit software in **Session 0**, which runs headlessly in the background before user logon. This is fatal for interactive graphical apps (Unity, Unreal, Web browsers), which require the active user graphics session. `slab` triggers **`-AtLogon`** or runs as a startup shortcut in the user shell.
- **The HKCU Profile Gap**: Tweaks targeting the Current User (`HKCU`) only applied to the Administrator account running the script. When a low-privilege `exhibit` user account was created, they inherited none of these configurations. `slab` mounts the **Default User Registry Hive** (`C:\Users\Default\NTUSER.DAT`) during setup so all newly created users automatically inherit the customized settings.
- **Autologon Security**: Plain-text storage of passwords in the registry is unsafe and bypassed by Windows Hello. `slab` configures passwordless bypasses properly or utilizes Microsoft's secure `Autologon.exe` tool.

### B. Tech Researcher Agent: Modern Framework Benchmarks
The Tech Researcher surveyed the web for leading Windows optimization and configuration toolkits (including *Sophia Script*, *Chris Titus Winutil*, *AtlasOS*, and *Win11Debloat*) to identify best-in-class features:
- **Sophia Script**: Taught us the value of using official CSP policies, granular undo/reversal commands, and standard WMI interfaces.
- **AtlasOS / AME Wizard**: Demonstrated the absolute superiority of declarative Playbooks (YAML/JSON separating execution code from system values).
- **Win11Debloat**: Showed how to configure settings specifically for **Audit Mode/Sysprep**, allowing exhibit builders to create and configure a golden image before cloning it to multiple machines.

### C. Brainstormer Agent: The Birth of `slab`
To replace the outdated `@bluecadet/launchpad-scaffold` and `little-bootstrap` names, we brainstormed tactile, physical metaphors based on groundwork and foundations. `slab` was selected as the ultimate physical metaphor for laying down an unshakeable, flat concrete foundation supporting your exhibit application.

---

## 3. Reference Modern Architecture Blueprint

Below is the conceptual blueprint for the `slab` configuration and execution model:

### Standard Declarative Config (`slab.config.json`)
```json
{
  "system": {
    "computerName": "EXHIBIT-PC-01",
    "timezone": "Eastern Standard Time",
    "enableDailyReboot": true,
    "rebootTime": "03:00"
  },
  "autologon": {
    "enabled": true,
    "username": "exhibit",
    "disablePasswordlessHello": true
  },
  "startupTask": {
    "enabled": true,
    "workingDir": "C:\\Exhibit",
    "executable": "launch.bat",
    "trigger": "AtLogon",
    "delay": "PT1M"
  },
  "packageManager": {
    "provider": "winget",
    "allowOfflineFallback": true,
    "localInstallersPath": ".\\installers",
    "apps": [
      "Node.js",
      "Git.Git"
    ]
  },
  "lockdown": {
    "disableScreensaver": true,
    "disableAccessibilityShortcuts": true,
    "disableEdgeSwipes": true,
    "disableTouchFeedback": true,
    "disableWindowsUpdate": true,
    "disableWindowsWidgets": true,
    "disableOOBEPrompts": true,
    "clearDesktopIcons": true,
    "blackDesktopBackground": true
  }
}
```

### The Multi-Step Execution Pipeline
1. **Parse & Validate**: The Node CLI reads `slab.config.json`, validates it against the JSON Schema, and dumps a sanitized temporary JSON payload.
2. **Environment Assertions**: The PowerShell wrapper checks administrative privileges and runs a warning-only network latency check.
3. **Registry Hive Mount (HKU:\DefaultUser)**: Mounts `C:\Users\Default\NTUSER.DAT` to inject all User-specific (`HKCU`) lockdown rules so that all future local user profiles (such as `exhibit`) boot fully locked down.
4. **App Execution & Installer Loop**: If `allowOfflineFallback` is true, scans `.\installers` and runs silent, unattended local installations.
5. Autologon & Kiosk Shell Setup: Configures autologon and registers the startup task under the graphical user session (or configures Shell Launcher V2 to replace the Explorer shell with the exhibit application directly).
6. Graceful Reboot: Prompts or executes a standard restart to finalize configuration.

---

## 4. Modern Refactoring Achievements & Sandbox Verification Loop

Following strict architectural oversight, the framework has been successfully refactored and finalized under the following parameters:

### 🧩 Structural Mods & Modular PowerShell Units
- **100-Line Absolute Code Cap**: To prevent monolithic sprawl and ensure maintainability, every single PowerShell file (including utilities and individual lockdown scripts) is strictly capped at under **100 lines of code**.
- **Shared Utilities Integration**: Core OS routines (hive loading, hive unloading, registry writes, service status, AppX uninstalls) are cleanly decoupled into standalone helper scripts within `src/powershell/utils/`.
- **Convergent Pipeline Execution**: `slab.ps1` runs all lockdown scripts unconditionally. Tweak scripts read configuration parameters and execute native DryRun or Undo sequences locally. This guarantees that toggling a configuration setting to `false` and re-running Slab automatically reverts the tweak on the next run, maintaining state synchronization.
- **Decoupled Data Configurations**: Volatile structures like UWP package lists have been extracted from logic script bodies into declarative assets like `bloatware-list.json`.

### 🧪 Dynamic Sandbox Test Execution Loop
- **Gitignored absolute-path WSB Configs**: Dynamic Sandbox XML mapping is generated on the fly inside `.tmp/slab-sandbox.wsb` (which is safely gitignored), mapping the current host directory to `C:\slab` in isolation.
- **Single-command Launch Loop**: Executing `npm run sandbox` automatically compiles the TS CLI, generates the WSB file, and opens an isolated Windows Sandbox environment.
- **Automated Validation Assertions**: The Sandbox runs `test/run-sandbox-tests.ps1` inside the elevated guest context. It executes Slab in Dry-Run, Active, and Undo modes, runs automated registry/scheduled task assertions, and pauses to allow developers to perform physical spot-checks. This guarantees 100% safety with zero host configuration drift.
