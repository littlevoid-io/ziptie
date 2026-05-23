# @littlevoid/ziptie

A zero-dependency Windows 11 system bootstrapping and kiosk lockdown framework. It configures and locks down Windows installations to run interactive media installations and unattended digital signage.

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

### Passing CLI Arguments to the Cloud Installer
You can execute the cloud installer with automated confirmation flags, safe dry-runs, or custom configuration overrides by running it as a script block and passing the `-ExtraArgs` parameter:

```powershell
powershell -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((irm https://raw.githubusercontent.com/littlevoid-io/ziptie/main/scripts/bootstrap.ps1))) -ExtraArgs '-y -d --timezone \"Tokyo Standard Time\" --disableScreensaver false'"
```

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
Customize settings in `ziptie.config.json` at the root of the repository. Open the file in VS Code to get auto-completion, schema validation, and description tooltips defined in `ziptie.schema.json`.

### 4. Run Dry-Run (Safe Preview)
To preview configuration changes without modifying the registry or system state:
```bash
npm start -- --dry-run
```

### 5. Apply Configuration
Apply the configuration (requires UAC elevation):
```bash
npm start
```

### 6. Revert Configuration
To revert the applied lockdowns and restore default OS settings:
```bash
npm start -- --undo
```

### 7. Command Line Overrides
You can dynamically override any parameter in `ziptie.config.json` directly from the CLI. This is extremely useful for remote scripting, silent RMM deployments, or multi-machine provisioning:

* **Direct Dot-Notation**: Pass the full category and parameter path.
  ```bash
  npm start -- --lockdown.disableScreensaver=false --system.computerName="EXHIBIT-99"
  ```
* **Smart Flat Shortcuts**: If a parameter name is unique in the configuration, you can omit the category! The engine will dynamically map it to its nested path and auto-cast the value to its correct primitive type (booleans, numbers, or comma-separated lists):
  ```bash
  npm start -- --timezone "Tokyo Standard Time" --disableScreensaver true --apps "Node.js,Git.Git"
  ```
* **Combinations**: You can mix and match standard flags, dot-notation, and shortcuts in a single command:
  ```bash
  npm start -- -y -d --computerName "EXHIBIT-02" --lockdown.disableEdgeSwipes=false
  ```


---

## Development

### Local Bootstrap Simulation (One-Liner)

To test, debug, or verify the bootstrapping process locally without fetching from GitHub, you can execute the bootstrap script directly from your local repository. The script will automatically detect the local repository and copy its release assets (e.g., `dist/ziptie.exe`, `scripts/`, etc.) to the target installation directory instead of downloading the zip from GitHub:

```powershell
# -InstallDir specifies the target destination folder where files are copied.
# (Defaults to current directory, or safely falls back to C:\Users\<Name>\Downloads\ziptie if run inside the repo)
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap.ps1 -InstallDir "C:\ziptie-dev"
```

You can also pass custom configuration overrides, silent install confirmations, or dry-run flags directly to the copied executable via the `-ExtraArgs` parameter:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\bootstrap.ps1 -InstallDir "C:\ziptie-dev" -ExtraArgs "-d -y --timezone `"Tokyo Standard Time`""
```


---

## Testing

Ziptie features a comprehensive, dual-layer test suite to ensure robust configuration parsing, correct CLI argument handling, and safe PowerShell scripts before execution on any target machine.

### 1. Test Architecture
*   **TypeScript Unit & CLI Tests (via Bun)**: Blazing-fast, mock-driven tests validating CLI overrides, dot-notation mapping, configuration deep merging, and elevation status checks.
*   **PowerShell Pester Unit Tests**: Non-destructive Pester unit tests confirming dry-run execution, script revertibility (`-Undo`), installer cleanups, and local simulation paths safely without modifying host configurations.
*   **Isolated Sandbox Environments**: Automated and interactive Windows Sandbox workflows verifying complete system configuration changes, registry states, scheduled task triggers, and dynamic WinGet provisioning.

### 2. Running Local Tests
You can execute tests locally on your development system using the npm scripts:

*   **Run Entire Test Suite (TypeScript + Pester)**:
    ```bash
    npm test
    ```
*   **Run TypeScript Unit Tests Only**:
    ```bash
    npm run test:unit
    ```
*   **Run CLI Integration Tests Only**:
    ```bash
    npm run test:cli
    ```
*   **Run Pester Unit Tests Only**:
    ```bash
    npm run test:pester
    ```

### 3. Run Isolated Sandbox Environments
Safely verify active registry modifications, Winget/Chocolatey installers, and the bootstrapping pipeline without any host system drift:

*   **Interactive Mapped Sandbox (Default)**:
    Mounts the repository directly to the guest User Desktop (`C:\Users\WDAGUtilityAccount\Desktop\ziptie`) and launches an elevated interactive PowerShell prompt without executing automated tests:
    ```bash
    npm run sandbox
    ```
    This is highly useful for manual spot-checks, interactive CLI testing, and active step-by-step experimentation.

*   **Automated Local Integration Tests**:
    Mounts the repository directly to the guest User Desktop and automatically executes the end-to-end integration test suite (`test/run-sandbox-tests.ps1`) to assert system configuration state:
    ```bash
    npm run sandbox:local
    ```

*   **Clean Remote Cloud Installer**:
    Launches a completely fresh guest environment with **no local folders mounted** (simulating a pure target machine with internet access) and executes the GitHub one-line bootstrap installer (`irm | iex`) from the current branch automatically at logon:
    ```bash
    npm run sandbox:remote
    ```

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
