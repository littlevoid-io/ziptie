# AGENTS.md

## Project overview

ziptie is a CLI and bootstrapping utility for Windows 11 museum exhibits, gallery installations, and unattended digital signage. It reads a declarative configuration (`ziptie.config.json`, validated by `ziptie.schema.json` and merged over `ziptie.default.config.json`) to harden and configure Windows settings offline.

It supports air-gapped environments via local offline installers (`installers/`), local Winget manifests, and silent provisioning without requiring an active internet connection.

## Dev environment tips

- Node >= 20, Bun (for builds and unit tests), and PowerShell 5.1+ compatibility. ESM only (`"type": "module"`).
- Run `npm run build` to compile the TypeScript CLI to `dist/index.js`.
- Run `npm run package` to compile the standalone binary (`dist/ziptie.exe`) and zip archive (`dist/ziptie.zip`).
- Use simple native commands from the shell; invoke PowerShell explicitly (`powershell -Command "..."`) when executing scripts or cmdlets.

## Build and test commands

Run all of these before treating a change as finished — all must be clean:

```sh
npm run format:check  # prettier --check . (npm run format to write)
npm run build         # bundle CLI into dist/index.js
npm test              # bun test (unit/cli) + pester tests
```

To test OS configuration or guest behavior in an isolated environment:

- `npm run sandbox` packages the project and launches an interactive Windows Sandbox.
- `npm run sandbox:local` runs the automated sandbox verification suite (`test/run-sandbox-tests.ps1`) in the guest.
- `npm run sandbox:remote` tests the remote cloud bootstrap script in a clean sandbox.

## Code style guidelines

- Size limits: 100 lines max per PowerShell script (`scripts/**/*.ps1`, enforced by static analysis test). Split helper logic into `scripts/utils/`.
- Modular CLI: Orchestrator delegates to `src/utils/` and `src/tasks.ts`. No monolithic script bodies.
- Host isolation: Never execute registry modifications or OS configuration scripts directly on the host machine. Run active tests in Windows Sandbox only.
- Official policies over hacks: Use stable Group Policy registry keys (`HKLM`/`HKCU`) and CSP/WMI policies. Mount the Default User hive (`C:\Users\Default\NTUSER.DAT`) to propagate user-level settings to future user accounts.
- Convergent execution: Settings scripts must support DryRun and revert modifications when a setting is toggled to `false`.
- Scheduled tasks: Startup tasks for interactive exhibits must trigger `AtLogon`, never `AtStartup` (avoids Session 0 headless graphics execution).
- Guest compatibility: Maintain PowerShell 5.1 compatibility across all scripts executed inside Windows Sandbox or target guest environments.
- No `eslint-disable` or `@ts-ignore` without explaining why in the commit message.
- Comment only the non-obvious "why" (hidden OS quirks, driver behaviors, or API workarounds).

## Testing instructions

- Dual-layer testing: mock-safe host tests vs. active sandbox tests. See [test/README.md](test/README.md) for architectural details.
- Unit tests live in `test/unit/` and `test/cli.test.ts`, executed via Bun (`npm run test:unit`, `npm run test:cli`).
- PowerShell Pester tests live in `test/*.Tests.ps1` (`npm run test:pester`). Tests must remain 100% compatible with both Pester 3.4.0 (Windows default) and Pester 5 (CI). Mocks must wrap in `BeforeAll`/`BeforeEach` to prevent discovery-phase leakage.
- Guest verification: Run `npm run sandbox:local` to execute `test/run-sandbox-tests.ps1` inside Windows Sandbox and verify active registry changes and task registrations.

## Release instructions

- Release from `develop` branch with a clean working tree: `npm run release`.
- The CLI prompts for a SemVer bump, creates the release branch, bumps versions, merges to `main`, tags, merges back to `develop`, and pushes to GitHub.
- GitHub Actions (`.github/workflows/release.yml`) builds the package, creates the GitHub Release with the tarball and standalone executable zip, and runs `npm stage publish` via npm Trusted Publisher (OIDC).
- Approve the staged release on [npmjs.com](https://www.npmjs.com) or via `npm stage approve <stage-id>`.

## PR instructions

- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`) with the subject strictly under 50 characters: `<type>(<scope>): <subject>`. Verbose details go into the commit body.
- Run the full gate (`npm test`, `npm run format:check`, `npm run build`) before committing.
- Keep commits scoped to one logical change; split unrelated fixes into separate commits.
- Strict local execution: Never push local commits or branches to remote upstream repositories (`git push` is forbidden for AI agents).
