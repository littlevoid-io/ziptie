# ziptie
## Goals, Architecture, and Agent Mandates

`ziptie` is a modern, quirky, zero-dependency, and air-gap friendly Windows 11 system bootstrapping and kiosk lockdown framework. It is a complete modernization and port of the legacy Bluecadet `@bluecadet/launchpad-scaffold` (also referred to as `little-bootstrap`).

Just like a high-tensile physical ziptie, it wraps around your operating system to secure, strap down, bundle, and lock in all system configurations, establishing a perfectly clean and secure foundation supporting high-fidelity interactive museum exhibits, gallery installations, and unattended digital signage.

---

## 1. Core Vision & Goals

The legacy tool was a collection of shell scripts cobbled together over years of Windows 8 and Windows 10 updates. Windows 11 has introduced major architectural shifts, stricter security defaults (like Windows Hello), and different structures for widgets, telemetry, and updates. 

`ziptie` targets **three core goals**:

1. **Modern Windows 11 Compliance & Support**
   - Eliminate obsolete Windows 8/10 tweaks (such as Cortana, the legacy Win 8 Start Page, or outdated namespace folder registry hacks).
   - Implement robust modern overrides for Windows 11 features (such as Taskbar Widgets, Web Experience app, personalized ads, and Copilot/Recall).
   - Use stable, official Group Policy registry keys and CSP/WMI policies instead of raw, destructive registry hacks wherever possible.

2. **Portable, Air-Gapped, and Local-First Deployment**
   - **Air-Gapped Operation**: Exhibits in galleries and museums are often kept on closed networks without internet access for security. `ziptie` never requires an active internet connection to configure settings.
   - **Local Installer Support**: Support bundling offline software installers (`.msi`, `.exe`) in a portable `./installers/` folder and executing silent installations locally, completely bypassing dynamic online downloads like standard Chocolatey installs.
   - **Offline Winget Integration**: Leverage built-in Windows 11 Winget capabilities using local manifests or pre-downloaded package files.

3. **Streamlined Declarative Configuration & CLI**
   - **Declarative Standard**: Move away from executable PowerShell configuration files (`defaults.ps1` / `user.ps1`), which introduce security risks (arbitrary code execution) and syntax-error vulnerabilities.
   - **JSON / YAML Configurations**: Re-implement configuration as a structured, parseable JSON or YAML file (e.g., `ziptie.config.json`).
   - **JSON Schema Validation**: Ship a detailed JSON Schema alongside the package. When developers edit the configuration in VS Code, they receive immediate autocompletion, real-time type validation, and embedded documentation for every single configuration flag.
   - **Non-blocking Execution**: Ensure that the bootstrapper can run headlessly and silently (e.g., via RMM or remote shell) by removing interactive blocks like pop-up notepad windows.

---

## 2. Agent Research Findings & Architecture

During the initialization of this project, three specialized AI agents were deployed to establish our technical blueprint. Below are their compiled insights and architectural decisions.

### A. Tech Director Agent: Legacy Code & OS Drift Analysis
The Tech Director analyzed the legacy codebase (`setup.ps1`, `scripts/windows/*`, and `config/*`) and highlighted key issues:
- **Session 0 Hazard**: The legacy setup configured startup tasks to trigger `-AtStartup` via Task Scheduler. This causes Windows to run the exhibit software in **Session 0**, which runs headlessly in the background before user logon. This is fatal for interactive graphical apps (Unity, Unreal, Web browsers), which require the active user graphics session. `ziptie` triggers **`-AtLogon`** or runs as a startup shortcut in the user shell.
- **The HKCU Profile Gap**: Tweaks targeting the Current User (`HKCU`) only applied to the Administrator account running the script. When a low-privilege `exhibit` user account was created, they inherited none of these configurations. `ziptie` mounts the **Default User Registry Hive** (`C:\Users\Default\NTUSER.DAT`) during setup so all newly created users automatically inherit the customized settings.
- **Autologon Security**: Plain-text storage of passwords in the registry is unsafe and bypassed by Windows Hello. `ziptie` configures passwordless bypasses properly or utilizes Microsoft's secure `Autologon.exe` tool.

### B. Tech Researcher Agent: Modern Framework Benchmarks
The Tech Researcher surveyed the web for leading Windows optimization and configuration toolkits (including *Sophia Script*, *Chris Titus Winutil*, *AtlasOS*, and *Win11Debloat*) to identify best-in-class features:
- **Sophia Script**: Taught us the value of using official CSP policies, granular undo/reversal commands, and standard WMI interfaces.
- **AtlasOS / AME Wizard**: Demonstrated the absolute superiority of declarative Playbooks (YAML/JSON separating execution code from system values).
- **Win11Debloat**: Showed how to configure settings specifically for **Audit Mode/Sysprep**, allowing exhibit builders to create and configure a golden image before cloning it to multiple machines.

### C. Brainstormer Agent: The Birth of `ziptie`
To replace the outdated `@bluecadet/launchpad-scaffold` and `little-bootstrap` names, we brainstormed tactile, physical metaphors based on groundwork and foundations. `ziptie` was selected as the ultimate physical metaphor for holding things tight and tidy, strapping down your OS configuration.

---

## 3. Reference Modern Architecture Blueprint

Below is the conceptual blueprint for the `ziptie` configuration and execution model:

### Standard Declarative Config (`ziptie.config.json`)
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
1. **Parse & Validate**: The Node CLI reads `ziptie.config.json`, validates it against the JSON Schema, and dumps a sanitized temporary JSON payload.
2. **Environment Assertions**: The PowerShell wrapper checks administrative privileges and runs a warning-only network latency check.
3. **Registry Hive Mount (HKU:\DefaultUser)**: Mounts `C:\Users\Default\NTUSER.DAT` to inject all User-specific (`HKCU`) lockdown rules so that all future local user profiles (such as `exhibit`) boot fully locked down.
4. **App Execution & Installer Loop**: If `allowOfflineFallback` is true, scans `.\installers` and runs silent, unattended local installations.
5. Autologon & Kiosk Shell Setup: Configures autologon and registers the startup task under the graphical user session (or configures Shell Launcher V2 to replace the Explorer shell with the exhibit application directly).
6. Graceful Reboot: Prompts or executes a standard restart to finalize configuration.

---

## 4. Modern Refactoring Achievements & Sandbox Verification Loop

Following strict architectural oversight, the framework has been successfully refactored and finalized under the following parameters:

### Structural Modifications & Modular Pipeline
- **Modular TypeScript CLI Architecture**: Decoupled `src/index.ts` into a clean orchestrator alongside highly cohesive sub-modules under `src/utils/` (`config.ts`, `elevation.ts`, `powershell.ts`) and a separate task registry `src/tasks.ts`, ensuring the CLI is fully scalable and easy to maintain.
- **Robust Schema Blending via `deepmerge`**: Standardized recursive configuration loading and deep merging using the popular npm `deepmerge` library, completely replacing custom spread operators and ensuring automated future schema scalability.
- **100-Line Absolute Code Cap**: To prevent monolithic sprawl and ensure maintainability, every single PowerShell file (including utilities and individual lockdown scripts) is strictly capped at under **100 lines of code**.
- **Shared Utilities Integration**: Core OS routines (hive loading, hive unloading, registry writes, service status, AppX uninstalls) are cleanly decoupled into standalone helper scripts within `scripts/utils/`.
- **Convergent Pipeline Execution**: The orchestrator runs all lockdown scripts unconditionally. Tweak scripts read configuration parameters and execute native DryRun or Undo sequences locally. This guarantees that toggling a configuration setting to `false` and re-running Ziptie automatically reverts the tweak on the next run, maintaining state synchronization.
- **Decoupled Data Configurations**: Volatile structures like UWP package lists have been extracted from logic script bodies into declarative assets like `bloatware-list.json`.

### Sandbox Test Loop
- **Gitignored absolute-path WSB Configs**: Dynamic Sandbox XML mapping is generated on the fly inside `.tmp/ziptie-sandbox.wsb` and `.tmp/ziptie-sandbox-remote.wsb` (which are safely gitignored), mapping the current host directory directly to the guest Desktop at `C:\Users\WDAGUtilityAccount\Desktop\ziptie` in isolation.
- **Interactive Mapped Sandbox**: Running `npm run sandbox` automatically compiles the TS CLI, generates the WSB file, and opens an isolated Sandbox with an elevated interactive PowerShell terminal ready for manual spot-checks or CLI execution, without running the automated test script.
- **Automated Verification**: Running `npm run sandbox:local` launches the mapped Sandbox and automatically executes the automated integration test suite `test/run-sandbox-tests.ps1` to assert configuration state, pausing for final check.
- **Remote Installer Verification**: Running `npm run sandbox:remote` launches a clean, unmapped Sandbox to execute the GitHub one-line bootstrap installer block directly from the active git branch.

### Windows 11 Compatibility & Sandbox Hardening
- **User Choice Protection Driver (UCPD) Resiliency**: Discovered that modern Windows 11 cumulative updates protect per-user registry values like `TaskbarDa` under `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` via the kernel-mode UCPD driver. Standardized absolute `Registry::HKEY_CURRENT_USER\` naming to bypass session drive scoping bugs and wrapped registry helper writes in `try/catch` blocks. Access errors are logged as warnings instead of halting execution, keeping the Ziptie pipeline robust.
- **PowerShell 5.1 Sandbox Compatibility**: Enforced strict PowerShell 5.1 backward compatibility for test and execution scripts run inside the guest Windows Sandbox environment (e.g., avoiding PowerShell 7+ syntax like ternary operators `$($a ? $b : $c)` in favor of standard `if/else` checks).
- **Scheduled Task Argument Validation**: Discovered that `New-ScheduledTaskAction` fails when passed an empty string to `-Argument`. Addressed this by conditionally supplying the parameter only when arguments are non-empty.
- **Offline Guest Package Manager Fallback**: Discovered that the standard `winget` package manager is not installed or available by default inside fresh guest environments like Windows Sandbox. Implemented a dynamic presence check using `Get-Command` to prevent `CommandNotFoundException` crashes, allowing the pipeline to fall back gracefully to local installer loops if local packages are configured.
- **Dynamic Winget Bootstrapping & Windows App Runtime Resolution**: Implemented a programmatic online bootstrapping mechanism for `winget` using the `ziptie-install-winget.ps1` helper. In clean guest environments like Windows Sandbox where WinGet is missing, the latest WinGet bundles fail to install due to a conflict/missing framework dependency on `Microsoft.WindowsAppRuntime.1.8`. Resolved this by dynamically downloading and silently installing the official `WindowsAppRuntimeInstall-x64.exe` installer alongside prerequisite OS dependencies (`Microsoft.VCLibs` and `Microsoft.UI.Xaml`), enabling seamless, automated WinGet provisioning.
- **Resilient Dual-Method WinGet Provisioning**: Enhanced `ziptie-install-winget.ps1` with a two-stage installer: Stage A performs direct MSIX/AppX/AppSDK deployment, and Stage B acts as a fallback to download the `Microsoft.WinGet.Client` module and execute `Repair-WinGetPackageManager -Force:$true -Latest` to dynamically resolve complex OS dependency trees.
- **Graceful, Visible Chocolatey Fallback**: Implemented a robust fallback to Chocolatey in `install-local-apps.ps1` if WinGet remains unavailable. The routine displays a clear yellow warning in the console, automatically installs/bootstraps `choco` via `scripts/install-choco.ps1`, maps common Winget IDs to Chocolatey names (e.g., `Git.Git` -> `git`, `CoreyButler.NVMforWindows` -> `nvm`, `Microsoft.VisualStudioCode` -> `vscode`), and silently installs apps.
- **100-Line Code Cap Modularization**: Decoupled all offline silent installer loop scanning and execution from `install-local-apps.ps1` into a dedicated utility script `scripts/utils/ziptie-install-offline.ps1`, keeping the main installer and all helper scripts strictly capped below the 100-line limit for absolute maintainability.
- **ThioJoe-Inspired WinGet Bootstrapping**: Refactored `ziptie-install-winget.ps1` to query the GitHub Releases API dynamically and download matching versions of the MSIX bundle and `DesktopAppInstaller_Dependencies.zip` zip archive. The script extracts the matching dependencies and registers the architecture-specific `x64` `.appx` dependencies automatically, eliminating dependency conflict code failures (`0x80073CF3`) entirely.
- **NVM Environment Variable & PATH Refresh Decoupling**: Encapsulated post-installation `nvm-windows` configuration into a dedicated modular helper `ziptie-configure-nvm.ps1` under the 100-line cap. The script bypasses parent-session PATH propagation lag by dynamically loading User/Machine environment registry values and injecting `NVM_HOME` and `NVM_SYMLINK` directly into the current PowerShell process context, successfully installing and activating the Node.js LTS version automatically.
- **VS Code & NVM Provisioning**: Integrated Visual Studio Code (`Microsoft.VisualStudioCode`) and NVM for Windows (`CoreyButler.NVMforWindows`) into the declarative package manager pipeline, ensuring seamless provisioning under Windows Sandbox and clean target machines.

---

## 5. Agent Execution Mandates

To align with Ziptie's design as an air-gapped, secure, and locally controlled framework, all AI coding agents operating on this codebase must strictly observe the following execution guidelines:

- **Strict Local Execution (Never Push)**: Coding agents must **NEVER** push local Git commits or branches to remote upstream repositories (e.g., executing `git push` is strictly forbidden). Upstream pushing remains exclusively a human developer operation.
- **No Direct-to-Host Configuration**: Lockdown configuration runs, registry overrides, and active OS modifications must **NEVER** be executed directly on the host development machine. All runtime tests, dry-runs, and active configurations must be run inside the isolated Windows Sandbox environment via the guest test suite (`npm run sandbox`).
- **Strict Conventional Commits Mandate**: Every git commit message MUST strictly adhere to the conventional commit standard format of `<type>(<action>): <subject>`. The subject line MUST be strictly less than **50 characters** in length, and any verbose descriptions or list details must be moved entirely into the commit message body separated by a blank line.

## 6. Tool Use

- MANDATORY: Use simple native commands, don't prefix or wrap commands with PowerShell, cd or git -c to circumvent this
- MANDATORY: Do not attempt to use PowerShell commands directly without invoking PowerShell (Get-ChildItem). Use native comands like `find` and `ls` instead.
