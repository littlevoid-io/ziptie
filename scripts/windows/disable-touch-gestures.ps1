[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)] [Object]$Config,
    [Switch]$DryRun, [Switch]$Undo
)

. "$PSScriptRoot/../../src/powershell/utils/slab-init.ps1"

$tweakEnabled = $Config.lockdown.disableTouchGestures
$shouldUndo = $Undo -or !$tweakEnabled

$path = "HKCU:\Control Panel\Desktop"

if ($shouldUndo) {
    Write-Host "Re-enabling default touch gestures..." -ForegroundColor Cyan
    &$registryTweak -Path $path -Name "TouchGestureSetting" -Remove
} else {
    Write-Host "Disabling advanced touch gestures (preventing app exiting via swipes)..." -ForegroundColor Cyan
    &$registryTweak -Path $path -Name "TouchGestureSetting" -Value 0 -Type "DWord"
}
