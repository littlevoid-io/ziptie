# @littlevoid/slab

A modern, zero-dependency, and offline-first Windows 11 system bootstrapping and kiosk lockdown framework. It configures and locks down Windows installations to run interactive museum exhibits, gallery installations, and unattended digital signage.

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
Customize settings in `slab-config.json` at the root of the repository. Open the file in VS Code to get auto-completion, schema validation, and description tooltips defined in `slab-schema.json`.

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
This command compiles the CLI, dynamically generates a `.wsb` mapping configuration at `.tmp/slab-sandbox.wsb` (gitignored), mounts the repository to `C:\slab` inside the guest environment, and runs `test/run-sandbox-tests.ps1` to validate the **Dry-Run**, **Active**, and **Undo** states.

---

## 🎯 What It Is For & What It Does
Slab automates the installation, configuration, and lockdown adjustments needed for public, unattended interactives:
* **System Customizations**: Sets the computer name, system timezone, power settings (High Performance, no screensaver/sleep), and schedules daily reboots.
* **Autologon & Startup**: Configures automatic login for user accounts and schedules startup tasks to run at GUI session logon (`AtLogon`) to avoid Session 0 headless isolation issues.
* **Offline Software Management**: Automatically uninstalls default Windows bloatware packages (defined in `bloatware-list.json`) and OneDrive. Installs local `.exe` or `.msi` application installers stored in the `./installers/` folder.
* **Security & Kiosk Lockdown**: Disables Windows Update, Edge swipes, multi-finger gestures, touch feedbacks, OOBE startup screens, desktop icons, and OS notification/toast popups.

---

## ⚙️ How It Works
1. **Config Engine**: The TypeScript CLI loads and validates `slab-config.json`, merges it with fallback defaults, and writes a temporary JSON configuration.
2. **Hive Mount Orchestration**: The main orchestrator (`slab.ps1`) mounts the Windows Default User Registry Hive (`C:\Users\Default\NTUSER.DAT`) to `HKU:\DefaultUser` inside a `try/finally` block. This ensures that any standard or guest accounts created on the machine in the future automatically inherit the lockdown settings out of the box.
3. **Granular Execution**: Executes standalone, convergent configuration scripts from `scripts/windows/`.
4. **Architectural Guidelines**:
   * **100-Line Code Cap**: Every PowerShell helper under `src/powershell/utils/` and tweak script under `scripts/windows/` is strictly capped at under 100 lines of code to maintain simplicity and a single responsibility.
   * **Convergent States**: Every script supports bidirectional execution using `-DryRun` and `-Undo` flags to ensure changes can be previewed or fully reverted on subsequent runs.
