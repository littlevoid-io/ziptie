[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)] [Object]$Config,
    [Switch]$DryRun, [Switch]$Undo
)

. "$PSScriptRoot/../../src/powershell/utils/slab-init.ps1"

$tweakEnabled = $Config.lockdown.clearDesktopIcons
$shouldUndo = $Undo -or !$tweakEnabled

$path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

if ($shouldUndo) {
    Write-Host "Showing desktop icons..." -ForegroundColor Cyan
    &$registryTweak -Path $path -Name "HideIcons" -Value 0 -Type "DWord"
} else {
    Write-Host "Hiding desktop icons..." -ForegroundColor Cyan
    &$registryTweak -Path $path -Name "HideIcons" -Value 1 -Type "DWord"
}
