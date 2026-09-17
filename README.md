# ziptie

Windows 11 system setup and bootstrapping CLI for museum exhibits, gallery installations, and unattended digital signage. Hardens and configures Windows settings offline from a declarative configuration file.

## Quick start

### One-line online install (requires internet)

Run from PowerShell on a fresh machine to bootstrap directly from GitHub:

```powershell
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/littlevoid-io/ziptie/main/scripts/bootstrap.ps1 | iex"
```

### Add to existing repository (can be configured for offline deployment, requires npm installed)

Initialize in your exhibit project root:

```sh
npx @littlevoid/ziptie init
```

Prompts for target mode (`online`, `offline`, `npm`), scaffolding `ziptie.config.json` and `ziptie.bat`. Run on target exhibit machines with:

```cmd
.\ziptie.bat
```

## Commands

### Setup commands

| Command                         | Description                                                 |
| ------------------------------- | ----------------------------------------------------------- |
| `ziptie`                        | Apply configuration (prompts for elevation if not elevated) |
| `ziptie --dry-run` (`-d`)       | Preview changes without modifying system state              |
| `ziptie --undo` (`-u`)          | Revert applied configuration                                |
| `ziptie --yes` (`-y`)           | Auto-confirm prompt with a 10s countdown                    |
| `ziptie --config <path>` (`-c`) | Specify a custom configuration file path                    |

When developing from checkout, run `npm start -- <flags>`.

### Init command

| Command                             | Description                                       |
| ----------------------------------- | ------------------------------------------------- |
| `ziptie init`                       | Scaffolds `ziptie.config.json` and `ziptie.bat`   |
| `ziptie init --mode <mode>` (`-m`)  | Set execution mode: `online`, `offline`, or `npm` |
| `ziptie init --force` (`-f`)        | Overwrite existing configuration and batch files  |
| `ziptie init --project-root <path>` | Target directory for scaffolding (default: cwd)   |

### Passing flags & overrides

#### In an exhibit repository (`ziptie.bat` / CLI)

Pass standard flags, flat parameter shortcuts, or dot-notation overrides:

```powershell
# Safe preview with auto-confirm
.\ziptie.bat -y -d

# Flat shortcuts for unique keys
.\ziptie.bat --timezone "Tokyo Standard Time" --disableScreensaver false --apps "Node.js,Git.Git"

# Dot-notation for nested categories
.\ziptie.bat --windows.disableScreensaver=false --system.computerName="EXHIBIT-99"
```

#### Via one-line online install (`bootstrap.ps1`)

Pass parameters to the remote runner using `-ExtraArgs`:

```powershell
powershell -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((irm https://raw.githubusercontent.com/littlevoid-io/ziptie/main/scripts/bootstrap.ps1))) -ExtraArgs '-y -d --timezone \"Tokyo Standard Time\" --disableScreensaver false'"
```

## Configuration

`ziptie.config.json` is validated against `ziptie.schema.json` and merged over defaults in `ziptie.default.config.json`:

```json
{
  "$schema": "https://raw.githubusercontent.com/littlevoid-io/ziptie/main/ziptie.schema.json",
  "system": {
    "computerName": "exhibit-pc-01",
    "timezone": "auto",
    "dailyReboot": true,
    "rebootTime": "06:00"
  },
  "autologon": {
    "enabled": true,
    "username": "auto",
    "disablePasswordlessHello": true
  },
  "startupTask": {
    "enabled": true,
    "workingDir": "C:\\Exhibit",
    "executable": "launch.bat"
  }
}
```

### Config sections

All sections are optional and merge over defaults in `ziptie.default.config.json`:

| Section          | Default | Purpose                                                                           |
| ---------------- | ------- | --------------------------------------------------------------------------------- |
| `system`         | on      | Hostname, timezone, daily reboot task, reboot on finish                           |
| `autologon`      | on      | Auto-login credentials and Windows Hello bypass                                   |
| `startupTask`    | on      | Scheduled task registered to trigger `AtLogon` in the GUI session                 |
| `packageManager` | on      | Winget/Chocolatey installs and offline `./installers` scanning                    |
| `windows`        | on      | System tweaks: telemetry, updates, widgets, touch gestures, power plan, bloatware |

<details>
<summary>View all parameters</summary>

| Key                                     | Type    | Description                                                 |
| :-------------------------------------- | :------ | :---------------------------------------------------------- |
| `system.computerName`                   | string  | Hostname of the system.                                     |
| `system.timezone`                       | string  | System timezone registry value or `auto`.                   |
| `system.dailyReboot`                    | boolean | Configures daily reboot task.                               |
| `system.rebootTime`                     | string  | Time of reboot (e.g. `06:00`).                              |
| `system.rebootOnFinish`                 | boolean | Reboots machine when execution finishes.                    |
| `autologon.enabled`                     | boolean | Enables autologon (requires dot-notation).                  |
| `autologon.username`                    | string  | User account targeted for auto-login (or `auto`).           |
| `autologon.disablePasswordlessHello`    | boolean | Disables Windows Hello passwordless requirement.            |
| `startupTask.enabled`                   | boolean | Creates scheduled startup task (requires dot-notation).     |
| `startupTask.workingDir`                | string  | Working directory for executable.                           |
| `startupTask.executable`                | string  | Executable path to launch.                                  |
| `startupTask.args`                      | array   | Command-line arguments.                                     |
| `startupTask.trigger`                   | string  | Trigger constraint (default: `AtLogon`).                    |
| `startupTask.delay`                     | string  | Delay before launch (e.g. `PT1M`).                          |
| `packageManager.provider`               | string  | Package manager CLI (`winget` or `choco`).                  |
| `packageManager.allowOfflineFallback`   | boolean | Scans `.\installers` for offline installers.                |
| `packageManager.localInstallersPath`    | string  | Folder path for offline installers.                         |
| `packageManager.apps`                   | array   | Package IDs or Chocolatey package names.                    |
| `windows.disableScreensaver`            | boolean | Disables lockscreen, sleep, and screensavers.               |
| `windows.disableAccessibilityShortcuts` | boolean | Blocks Shift-key accessibility triggers.                    |
| `windows.disableEdgeSwipes`             | boolean | Disables touch swipes from monitor edges.                   |
| `windows.disableTouchFeedback`          | boolean | Disables visual touch pointer indicators.                   |
| `windows.disableSystemSounds`           | boolean | Disables system-event audio alerts.                         |
| `windows.disableWindowsUpdate`          | boolean | Disables Windows Update service and tasks.                  |
| `windows.disableWindowsWidgets`         | boolean | Disables widgets and news feeds from taskbar.               |
| `windows.disableCopilotRecall`          | boolean | Disables Windows Copilot and Recall tracking.               |
| `windows.disableOOBEPrompts`            | boolean | Blocks post-update setup prompts.                           |
| `windows.clearDesktopIcons`             | boolean | Removes default shortcuts from public desktop.              |
| `windows.solidColorBackground`          | string  | Sets desktop solid background hex color (e.g. `#333333`).   |
| `windows.enableDarkMode`                | boolean | Forces dark theme across Windows UI.                        |
| `windows.configureExplorer`             | boolean | Shows file extensions, hidden files, and simplifies layout. |
| `windows.disableAppInstalls`            | boolean | Blocks Store background app installs.                       |
| `windows.disableAppRestore`             | boolean | Blocks automatic AppX restoration.                          |
| `windows.disableErrorReporting`         | boolean | Disables Windows error popup reporting.                     |
| `windows.disableFirewall`               | boolean | Disables Windows Defender Firewall rules.                   |
| `windows.disableMaxPathLength`          | boolean | Extends NTFS 260 character path limit.                      |
| `windows.disableNewNetworkWindow`       | boolean | Disables overlay network panel flyouts.                     |
| `windows.disableNotifications`          | boolean | Disables Action Center notifications.                       |
| `windows.disableTouchGestures`          | boolean | Disables multi-finger touch controls.                       |
| `windows.enableScriptExecution`         | boolean | Sets PowerShell execution policy to RemoteSigned.           |
| `windows.resetTextScale`                | boolean | Resets display text scaling to 100%.                        |
| `windows.uninstallBloatware`            | boolean | Uninstalls bundled UWP consumer bloatware.                  |
| `windows.uninstallOneDrive`             | boolean | Uninstalls and removes OneDrive.                            |
| `windows.unpinStartMenuApps`            | boolean | Clears pinned default apps from Start menu.                 |
| `windows.setPowerSettings`              | boolean | Sets power plan to High Performance.                        |

</details>

## Execution pipeline

| Stage                    | Action                                                                                           |
| :----------------------- | :----------------------------------------------------------------------------------------------- |
| **1. Config resolution** | Parses `ziptie.config.json` against `ziptie.schema.json` and deep-merges over defaults           |
| **2. Hive mount**        | Mounts `C:\Users\Default\NTUSER.DAT` to `HKU:\DefaultUser` to propagate settings to new accounts |
| **3. App provisioning**  | Scans `./installers` for silent installers or resolves packages via Winget/Chocolatey            |
| **4. OS settings**       | Executes convergent scripts in `scripts/windows/` for apply or revert (`--undo`)                 |
| **5. Shell restart**     | Unmounts default hive and restarts Windows Explorer                                              |

## Development

```sh
npm install
npm run build         # bundle CLI into dist/index.js
npm test              # run unit and pester tests
npm run package       # compile standalone dist/ziptie.exe and zip archive
```

### Windows Sandbox testing

Verify configuration behaviors inside an isolated Windows Sandbox:

| Command                  | Action                                                   |
| ------------------------ | -------------------------------------------------------- |
| `npm run sandbox`        | Mount repository and open interactive guest console      |
| `npm run sandbox:local`  | Run automated guest tests (`test/run-sandbox-tests.ps1`) |
| `npm run sandbox:remote` | Test remote cloud bootstrap script in clean sandbox      |

## License

[MIT](LICENSE)
