# @littlevoid/ziptie

A modern, zero-dependency, and offline-first Windows 11 system bootstrapping and kiosk lockdown framework. It configures and locks down Windows installations to run interactive museum exhibits, gallery installations, and unattended digital signage.

---

## ⚡ One-Line Install & Setup (Recommended)

To bootstrap a new Windows 11 system completely from scratch with **zero dependencies pre-installed** (no Git or Node.js required), open **PowerShell as Administrator** and run:

```powershell
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/littlevoid-io/ziptie/main/scripts/bootstrap.ps1 | iex"
```

This script will automatically:
1. Check for and request administrative elevation.
2. Download and provision the latest precompiled Ziptie release directly to your local working directory.
3. Extract the release and execute the standalone `dist\ziptie.exe` binary.
4. Launch the interactive Ziptie setup assistant to configure your PC.

---

## 🚀 How to Use (Quick Start)

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

## 📦 Creating a Release

To package a new release and publish it directly to GitHub:

### 1. Configure the GitHub Token
Create a `.env` file in the root of your repository and add your GitHub Personal Access Token (PAT):
```env
GITHUB_TOKEN=your_personal_access_token_here
```
> [!NOTE]
> Ensure the `.env` file is never committed. It is already added to `.gitignore` to keep your credentials safe.

### 2. Run the Release Script
Execute the following command in your terminal:
```bash
npm run release
```

This command automatically:
1. Loads the `GITHUB_TOKEN` environment variable from your `.env` file.
2. Prompts you to select the next version increment (e.g., `patch`, `minor`, `major`).
3. Updates `package.json` and `package-lock.json` and creates a local Git commit and tag.
4. Triggers the packaging hook:
   - Compiles the standalone `dist/ziptie.exe` binary.
   - Compresses all necessary dependencies (`dist/ziptie.exe`, `scripts/`, `ziptie.default.config.json`, `ziptie-schema.json`, and `setup.bat`) into a single `ziptie.zip` archive.
5. Deploys the release to GitHub via the REST API and **attaches `ziptie.zip` as a release asset** automatically.

---


## 🎯 What It Is For & What It Does
Ziptie automates the installation, configuration, and lockdown adjustments needed for public, unattended interactives:
* **System Customizations**: Sets the computer name, system timezone, power settings (High Performance, no screensaver/sleep), and schedules daily reboots.
* **Autologon & Startup**: Configures automatic login for user accounts and schedules startup tasks to run at GUI session logon (`AtLogon`) to avoid Session 0 headless isolation issues.
* **Offline Software Management**: Automatically uninstalls default Windows bloatware packages (defined in `bloatware-list.json`) and OneDrive. Installs local `.exe` or `.msi` application installers stored in the `./installers/` folder.
* **Security & Kiosk Lockdown**: Disables Windows Update, Edge swipes, multi-finger gestures, touch feedbacks, OOBE startup screens, desktop icons, and OS notification/toast popups.

---

## ⚙️ How It Works
1. **Config Engine**: The TypeScript CLI loads and validates `ziptie.config.json` against the schema. It recursively deep-merges user overrides with fallback defaults using the npm `deepmerge` library, writing a temporary JSON configuration block.
2. **Hive Mount Orchestration**: The main orchestrator mounts the Windows Default User Registry Hive (`C:\Users\Default\NTUSER.DAT`) to `HKU:\DefaultUser` inside a robust `try/finally` block. This ensures that any standard or guest accounts created on the machine in the future automatically inherit the lockdown settings out of the box.
3. **Granular Execution**: Executes standalone, convergent configuration scripts from `scripts/windows/`.
4. **Architectural Guidelines**:
   * **Modular TypeScript CLI**: Decoupled into specialized modules (`elevation.ts` for UAC checks, `powershell.ts` for script execution, and `config.ts` for file parsing/merging) and a task registry (`tasks.ts`), keeping the orchestrator clean and easily extensible.
   * **100-Line Code Cap**: Every PowerShell helper under `scripts/utils/` and tweak script under `scripts/windows/` is strictly capped at under 100 lines of code to maintain simplicity and a single responsibility.
   * **Convergent States**: Every script supports bidirectional execution using `-DryRun` and `-Undo` flags to ensure changes can be previewed or fully reverted on subsequent runs.
