[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)] [Object]$Config,
    [Switch]$DryRun, [Switch]$Undo
)

. "$PSScriptRoot/../../src/powershell/utils/slab-init.ps1"

$tweakEnabled = $Config.lockdown.disableScreensaver
$shouldUndo = $Undo -or !$tweakEnabled

$policyFolder = "Software\Policies\Microsoft\Windows\Control Panel\Desktop"
$paths = @("HKLM:\$policyFolder", "HKCU:\$policyFolder", "HKCU:\Control Panel\Desktop")

if ($shouldUndo) {
    Write-Host "Restoring default screensaver settings..." -ForegroundColor Cyan
    foreach ($path in $paths) {
        &$registryTweak -Path $path -Name "ScreenSaveTimeOut" -Remove
        &$registryTweak -Path $path -Name "ScreenSaveActive" -Remove
        &$registryTweak -Path $path -Name "ScreenSaverIsSecure" -Remove
        &$registryTweak -Path $path -Name "SCRNSAVE.EXE" -Remove
    }
} else {
    Write-Host "Disabling screensaver for HKLM and user scopes..." -ForegroundColor Cyan
    foreach ($path in $paths) {
        &$registryTweak -Path $path -Name "ScreenSaveTimeOut" -Value "0" -Type "String"
        &$registryTweak -Path $path -Name "ScreenSaveActive" -Value "0" -Type "String"
        &$registryTweak -Path $path -Name "ScreenSaverIsSecure" -Value "0" -Type "String"
        &$registryTweak -Path $path -Name "SCRNSAVE.EXE" -Value "" -Type "String"
    }
}