# Ziptie Testing Framework

This directory contains the dual-layer testing suite designed for validating Ziptie's bootstrapper, declarative configuration loaders, and system-altering lockdown scripts safely.

---

## 1. The Dual-Layer Architecture

To ensure maximum safety and consistency, the test suite is partitioned into two distinct execution tiers:

1. **Mock-Safe Local Unit Tests (`test/unit/` & `test/*.Tests.ps1`)**
   - Verified locally on the host machine using `npm test`.
   - Mocks all system-altering commands (`powercfg`, `Rename-Computer`, registry writes, etc.) so that tests run completely in-memory in milliseconds with zero side effects.
2. **Automated Sandbox Integration Tests (`test/run-sandbox-tests.ps1`)**
   - Executed inside an isolated Windows Sandbox guest environment via `npm run sandbox:local`.
   - Executes Ziptie in **active modification mode** on a clean, disposable OS instance and asserts that the actual system settings, registry keys, and scheduled tasks were modified successfully.

---

## 2. Pester 3 vs. Pester 5 Cross-Compatibility Guidelines

exhibits and signage machines often operate on different versions of Windows. To ensure tests can run on any development machine as well as in clean CI environments, our PowerShell Pester tests are engineered to be **100% compatible with both Pester v3 and Pester v5**.

### Why Both Versions Are Needed

*   **Pester 3 (Local Host Default):** Windows 10 and 11 come pre-installed with **Pester v3.4.0** in the default System modules path (`C:\Program Files\WindowsPowerShell\Modules\Pester`). Unless developers manually install Pester 5, running tests directly on the host executes under Pester 3.
*   **Pester 5 (CI & Sandbox Guest):** Modern CI environments (like the GitHub Actions `windows-latest` runner) and dynamic sandboxes bootstrap and load the modern **Pester v5.x** module.

---

## 3. Core Architectural Learnings & Rules

Pester 5 introduced a two-phase execution lifecycle (**Discovery** and **Run**) which significantly differs from Pester 3's single-pass execution. Writing cross-compatible tests requires strict adherence to the following design patterns:

### A. Variable Scope & Lifetime Isolation
*   **The Issue:** In Pester 5, the script is loaded and analyzed during the **Discovery** phase (to find all `It` blocks). Any variables defined at the top of the file (outside block scopes) are lost and reset to `$null` when the **Run** phase executes.
*   **The Rule:** Path variables (like `$scriptsDir`, `$utilsDir`, and `$defaultConfigPath`) **MUST** be defined **unconditionally** inside the `BeforeAll` block of the `Describe` block.
*   **Scope Sharing:** Avoid the `$script:` prefix for path variables. Defining them as ordinary variables (e.g., `$scriptsDir = ...`) inside `BeforeAll` leverages Pester 5's automatic scope inheritance, making them safely available to all nested child blocks during execution.
*   **Discovery Fallbacks:** If variables are needed during Discovery (e.g., to find files for dynamic test cases in a `foreach` loop), define a local fallback check inside the Discovery-time `Context` block body itself.

### B. Mocks Registration & Activation
*   **The Danger:** In Pester 5, `Mock` cmdlets written directly inside a `Context` or `Describe` block body execute during the **Discovery** phase. Mocks evaluated during Discovery are **NOT** active during the Run phase. This causes tests to bypass the mocks entirely, leading to **dangerous live execution** of system-altering commands (like renaming the host PC or modifying firewall policies) on the developer's host or the CI runner.
*   **The Rule:** All `Mock` declarations **MUST** be wrapped inside `BeforeAll` or `BeforeEach` blocks. This ensures that the mock framework registers and activates them at the start of the **Run** phase, keeping the tests perfectly safe, in-memory, and blazing fast.

### C. Canary Mock Validation (`test/canary.Tests.ps1`)
*   **Purpose:** Act as an early warning system. If any scoping changes in Pester 5 break cmdlet interception, the Canary test fails immediately, warning developers that the mock framework has been bypassed *before* any downstream scripts can make unintended system modifications.
*   **Implementation:** Mocks the native `New-Item` cmdlet, calls a dummy script that invokes `New-Item`, and asserts that `Assert-MockCalled` passes and that **no physical file** was created on the disk.
*   **Priority Execution:** The test runner `test/run-tests.ps1` dynamically discovers all `*.Tests.ps1` files and explicitly prepends the Canary test path to ensure it always executes first in the array.

---

## 4. Modern Modular Test Architecture

Following the **100-line absolute code cap** specified in `AGENTS.md`, the monolithic `test/scripts.Tests.ps1` (~370 lines) has been broken down into small, cohesive, and easily maintainable modules:

*   **`test/static-analysis.Tests.ps1`** (~40 lines): Focuses exclusively on auditing code quality constraints (100-line code cap check for all production files and plain-text password/secret detection checks).
*   **`test/lockdown-loop.Tests.ps1`** (~99 lines): Dynamically runs all standard Windows lockdown scripts in Dry-Run, Mock Active, Undo, and Disabled configuration modes.
*   **`test/startup-task.Tests.ps1`** (~80 lines): Focuses specifically on the argument-splitting, literal array, and null parameter parsing behaviors of the scheduled startup task script.
*   **`test/utils/test-helpers.ps1`** (~45 lines): Houses standard backup and restore procedures for target utility files.
*   **`test/utils/test-mocks.ps1`** (~80 lines): Houses the unified, pure in-memory mock environment.

---

## 5. Key Pester Refactoring Learnings

During the refactoring of our test suites, we identified and solved four critical Pester and PowerShell lifecycle constraints:

### A. Cmdlet Mock Interception of Helper Routines
*   **The Issue:** When a helper script uses standard PowerShell cmdlets (like `Get-ChildItem`, `Copy-Item`, `Remove-Item`, or `Test-Path`) to perform test cleanup or backup, these calls can be intercepted by active Pester mocks registered in the same session (e.g., our mock for `Get-ChildItem` which returns empty arrays to isolate system folders). This will silently break test lifecycle utilities, such as preventing original scripts from being restored and leaving the repository modified.
*   **The Solution:** All test lifecycle file and directory operations inside `test/utils/test-helpers.ps1` are implemented using **pure .NET static methods** (like `[System.IO.Directory]::GetFiles`, `[System.IO.File]::Copy`, and `[System.IO.Directory]::Delete`). Because Pester only mocks PowerShell cmdlets, pure .NET static methods are **100% immune to mock interception**, guaranteeing clean, reliable execution under any test configuration.

### B. Scoping and Dynamic Block Isolation
*   **The Issue:** Inside dynamic blocks of Pester (like `BeforeAll` and `AfterAll`), automatic variables like `$PSScriptRoot` can resolve to `$null` or behave unexpectedly because the block is executed in a dynamic scope within Pester's internal functions. Additionally, using `$script:utilsDir` within dynamic blocks executed by a module (like Pester) can resolve to the Pester module's internal script scope rather than the test script's scope.
*   **The Solution:** Paths are resolved and dot-sourced at the script-compilation level (outside the `Describe` block). We load variables and dot-source helpers once in the test file scope. Inside the `BeforeAll` and `AfterAll` blocks, we reference these variables using the explicit `$script:` scope qualifier, ensuring they bypass module boundary limitations.

### C. Pester 3.4.0 Mocking Declarations (Dummy Functions)
*   **The Issue:** On standard Windows installations, Pester 3.4.0 (the default pre-installed version) cannot mock a command or cmdlet (like `choco` or `winget`) unless it is already declared as an executable or function in the active session. If the target executable is not installed on the developer's host machine, Pester throws a `CommandNotFoundException` when registering the mock.
*   **The Solution:** We explicitly define inline dummy functions (e.g., `function choco { }`, `function winget { }`) at the top of the mock registry `test/utils/test-mocks.ps1`. This registers them safely in the PowerShell session, enabling Pester 3.4.0 to intercept and mock them flawlessly on any developer machine without requiring those tools to be physically installed.

