[CmdletBinding()]
Param(
    [String]$ConfigPath = "$PSScriptRoot/.tmp/slab-temp-config.json",
    [Switch]$DryRun,
    [Switch]$Undo
)

Push-Location $PSScriptRoot
[Environment]::CurrentDirectory = $PWD

Write-Host "==================================================" -ForegroundColor Green
Write-Host "         S L A B   O R C H E S T R A T O R        " -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
if ($DryRun) { Write-Host "   *** RUNNING IN DRY-RUN MODE ***   " -ForegroundColor Yellow }
if ($Undo)   { Write-Host "   *** RUNNING IN UNDO MODE ***      " -ForegroundColor Yellow }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (!$isAdmin -and !$DryRun) {
    Write-Error "Slab requires administrator privileges. Please re-run as an Administrator."
    Exit 1
}

if (!(Test-Path $ConfigPath)) {
    Write-Error "Configuration file not found: $ConfigPath"
    Exit 1
}

$config = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json
Write-Host "Loaded configuration from: $ConfigPath" -ForegroundColor Gray

if (!$DryRun) {
    New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -ErrorAction SilentlyContinue | Out-Null
}

$hiveMounted = $false
try {
    if (!$DryRun) {
        & "$PSScriptRoot/src/powershell/utils/slab-mount-hive.ps1" -MountName "HKU\DefaultUser" -HivePath "C:\Users\Default\NTUSER.DAT"
        $hiveMounted = $true
    }

    # Core System Configurations
    & "$PSScriptRoot/scripts/windows/set-timezone.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/scripts/windows/set-computer-name.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/scripts/windows/enable-daily-reboot.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/scripts/windows/enable-auto-login.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/scripts/windows/enable-startup-task.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/scripts/windows/install-local-apps.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo

    # OS Lockdowns & Customizations
    $wins = "scripts/windows"
    & "$PSScriptRoot/$wins/disable-windows-widgets.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/$wins/disable-copilot-recall.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/$wins/disable-update-service.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/$wins/disable-screensaver.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/$wins/disable-accessibility.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/$wins/disable-edge-swipes.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/$wins/disable-touch-feedback.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/$wins/disable-win-setup-prompts.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/$wins/clear-desktop-shortcuts.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/$wins/clear-desktop-background.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/$wins/config-explorer.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/$wins/disable-app-installs.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/$wins/disable-app-restore.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/$wins/disable-error-reporting.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/$wins/disable-firewall.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/$wins/disable-max-path-length.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/$wins/disable-new-network-window.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/$wins/disable-notifications.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/$wins/disable-touch-gestures.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/$wins/enable-script-execution.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/$wins/reset-text-scale.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/$wins/uninstall-bloatware.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/$wins/uninstall-one-drive.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/$wins/unpin-start-menu-apps.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo
    & "$PSScriptRoot/$wins/set-power-settings.ps1" -Config $config -DryRun:$DryRun -Undo:$Undo

} finally {
    if ($hiveMounted) {
        [gc]::Collect()
        [gc]::WaitForPendingFinalizers()
        & "$PSScriptRoot/src/powershell/utils/slab-unmount-hive.ps1" -MountName "HKU\DefaultUser"
    }
    Pop-Location
    [Environment]::CurrentDirectory = $PWD
    Write-Host "Slab operations completed." -ForegroundColor Green
}
