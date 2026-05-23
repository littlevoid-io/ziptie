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
