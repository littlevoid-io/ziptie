[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.resetTextScale
$shouldUndo = $Undo -or !$tweakEnabled

. "$PSScriptRoot/../utils/ziptie-init.ps1"

$desktopPath = "HKCU:\Control Panel\Desktop"

if ($shouldUndo) {
    Write-Host "Restoring default text scaling properties..." -ForegroundColor Cyan
    &$registryTweak -Path $desktopPath -Name "Win8DpiScaling" -Remove
    &$registryTweak -Path $desktopPath -Name "LogPixels" -Remove
} else {
    Write-Host "Resetting Windows display text scaling to 100% (LogPixels=96, Win8DpiScaling=1)..." -ForegroundColor Cyan
    &$registryTweak -Path $desktopPath -Name "Win8DpiScaling" -Value 1 -Type "DWord"
    &$registryTweak -Path $desktopPath -Name "LogPixels" -Value 96 -Type "DWord"
}
