# 🧱 @littlevoid/slab

> **slab** is a modern, quirky, zero-dependency, and air-gap friendly Windows 11 system bootstrapping and kiosk lockdown framework. 

Just like a physical concrete slab, it is poured directly over raw ground (Windows 11) to establish an unshakeable, flat, clean, and perfectly leveled foundation supporting high-fidelity interactive museum exhibits, gallery installations, and unattended digital signage.

---

## 🏛️ Core Features

- **Modern Windows 11 Compliance**: Replaces obsolete registry hacks with stable, official Group Policy registry keys and CSP/WMI overrides (disabling Widgets, Copilot, Edge Swipes, and Notification panels).
- **Portable & Air-Gapped**: Runs offline-first. Scans a local `./installers` folder for `.msi`/`.exe` installers for silent offline installation, or runs built-in Winget processes when connected.
- **Default Registry Hive Mounting**: Mounts `C:\Users\Default\NTUSER.DAT` during installation to pre-apply all lockdown configurations, ensuring every newly created user (e.g., standard non-admin accounts) is fully locked down out of the box.
- **Strict Single-Purpose PowerShell Design**: Highly modular architecture where every tweak script and utility is strictly **capped under 100 lines of code**.
- **Bidirectional Convergent Tweaks**: Supports full **Dry-Run** simulations and absolute **Undo/Reversion** states, managed directly by the declarative configurations.

---

## 📦 Project Layout

- `src/` - TypeScript engine CLI compiler and launcher.
  - `src/powershell/utils/` - Decoupled utility operations (< 100 lines each) for registry hive loading, unmounting, service configuration, and AppX packages removal.
- `scripts/windows/` - Curved lockdown and customization scripts (< 100 lines each), supporting parameter overrides, DryRun, and Undo modes.
- `test/` - Integration and validation test suites.
- `slab-config.json` - Declarative configuration specification.
- `slab-schema.json` - Rich validation schema for autocompletion and type validation.

---

## 🚀 Getting Started

### Prerequisites
- **Node.js** (v18 or higher)
- **Windows 11** or **Windows 10** (x64)

### 1. Install & Build
Clone the repository and install dependencies:
```bash
npm install
npm run build
```

### 2. Configure Your Slab
Open [slab-config.json](file:///c:/Users/ben/Documents/Repos/_libs/little-bootstrap/slab-config.json) in VS Code. Since it references the JSON Schema, you will receive immediate autocompletion and inline documentation for every single configuration property.

### 3. Run Dry-Run (Verification)
You can run a safe, non-modifying dry-run to preview what changes Slab will make:
```bash
node dist/index.js --dry-run
```

### 4. Apply Configuration (Requires UAC Elevation)
Run the application normally to trigger UAC elevation and configure the OS:
```bash
node dist/index.js
```

### 5. Revert Configuration (Undo)
To undo all applied locks and restore standard OS settings:
```bash
node dist/index.js --undo
```

---

## 🧪 Isolated Sandbox Testing

To verify Slab's lockdowns without altering your host machine, you can launch a completely isolated **Windows Sandbox (WSB)** on the fly:

```bash
npm run sandbox
```

### What this npm script does:
1. Dynamically detects your local workspace's absolute path.
2. Generates a fully path-resolved WSB config file at `.tmp/slab-sandbox.wsb` (which is safely ignored by Git).
3. Spawns Windows Sandbox, securely mapping your workspace to `C:\slab` in isolation.
4. Automatically runs the automated test runner [test/run-sandbox-tests.ps1](file:///c:/Users/ben/Documents/Repos/_libs/little-bootstrap/test/run-sandbox-tests.ps1) inside the Sandbox to execute and verify **Dry-Run**, **Active**, and **Undo** modes against a fresh Windows 11 system!
