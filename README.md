# @littlevoid/ziptie

A modern, zero-dependency, and offline-first Windows 11 system bootstrapping and kiosk lockdown framework. It configures and locks down Windows installations to run interactive museum exhibits, gallery installations, and unattended digital signage.

---

## One-Line Install

To bootstrap a new Windows 11 system from scratch with **zero dependencies pre-installed** (no Git or Node.js required), open **PowerShell as Administrator** and run:

```powershell
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/littlevoid-io/ziptie/main/scripts/bootstrap.ps1 | iex"
```

This script will:
1. Check for and request UAC elevation.
2. Download and extract the latest precompiled Ziptie release locally.
3. Execute the standalone `dist\ziptie.exe` binary.
4. Launch the setup assistant to configure the system.

---

## Quick Start

### 1. Prerequisites
* **Windows 11** or **Windows 10**
* **Node.js** (v18 or higher)

### 2. Installation
Clone the repository and compile the TypeScript engine:
```bash
npm install
npm run build
```

### 3. Configuration
Customize settings in `ziptie.config.json` at the root of the repository. Open the file in VS Code to get auto-completion, schema validation, and description tooltips defined in `ziptie-schema.json`.

### 4. Run Dry-Run (Safe Preview)
To preview configuration changes without modifying the registry or system state:
```bash
node dist/index.js --dry-run
```

### 5. Apply Configuration
Apply the configuration (requires UAC elevation):
```bash
node dist/index.js
```

### 6. Revert Configuration
To revert the applied lockdowns and restore default OS settings:
```bash
node dist/index.js --undo
```

### 7. Run Isolated Sandbox Tests
To safely verify configurations without altering your host machine, launch an isolated Windows Sandbox:
```bash
npm run sandbox
```
This command compiles the CLI, dynamically generates a .wsb mapping configuration at `.tmp/ziptie-sandbox.wsb` (gitignored), mounts the repository to `C:\ziptie` inside the guest environment, and runs `test/run-sandbox-tests.ps1` to validate the active configuration state.

### 8. Test the One-Line Bootstrap Installer in a Clean Sandbox
To verify the one-line bootstrap installer completely from scratch inside an isolated, clean Windows Sandbox with **no local folders mounted** (simulating a pure client machine with internet access):
```bash
npm run sandbox:installer
```
This command dynamically generates a `.wsb` configuration at `.tmp/ziptie-sandbox-installer.wsb` (gitignored) and launches Windows Sandbox to execute the GitHub one-line command (`irm | iex`) in an elevated guest PowerShell window automatically at logon.


---

## Creating a Release

To package a new release and publish it directly to GitHub:

### 1. Configure the GitHub Token
Add your GitHub Personal Access Token (PAT) to a `.env` file in the repository root:
```env
GITHUB_TOKEN=your_personal_access_token_here
```

### 2. Run the Release Script
```bash
npm run release
```

This will automatically:
1. Prompt for the next version increment (`patch`, `minor`, `major`).
2. Update version files and create a local Git commit and tag.
3. Build the standalone `dist\ziptie.exe` binary.
4. Package assets (`dist\ziptie.exe`, `scripts/`, default config, and `setup.bat`) into `ziptie.zip`.
5. Deploy to GitHub via the REST API and attach the zip archive as a release asset.

---

## Core Features

Ziptie automates the configuration and lockdown required for public, unattended interactive systems:
* **System Settings**: Configures hostname, timezone, power scheme (High Performance, no sleep), and schedules daily reboots.
* **Autologon & Startup**: Configures automatic user login and schedules startup tasks to run at GUI session logon (`AtLogon`).
* **Package Management**: Uninstalls Windows bloatware/OneDrive, and silently installs offline application installers (`.exe`, `.msi`) from the `./installers/` directory.
* **Security & Lockdown**: Disables Windows Update, edge swipes, touch feedback, OOBE prompts, desktop icons, and OS notifications.

---

## How It Works

1. **Config Engine**: The CLI parses `ziptie.config.json` against the JSON schema, merging user overrides with defaults via `deepmerge`.
2. **Hive Mounting**: The orchestrator mounts the Windows Default User Registry Hive (`C:\Users\Default\NTUSER.DAT`) to `HKU:\DefaultUser` so newly created user accounts automatically inherit lockdown policies.
3. **Execution**: Runs convergent PowerShell configuration scripts from `scripts/windows/`.
4. **Architecture**:
   * **Modular CLI**: Decoupled into specialized modules (`elevation.ts`, `powershell.ts`, `config.ts`) and a task registry (`tasks.ts`).
   * **100-Line Code Cap**: All script and utility files are strictly capped under 100 lines for maintainability.
   * **Convergent Execution**: Scripts run in both apply and revert (`-Undo`) modes.
