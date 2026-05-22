[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.disableScreensaver
$shouldUndo = $Undo -or !$tweakEnabled

$registryTweak = {
    Param([String]$Path, [String]$Name, [Object]$Value, [String]$Type, [Switch]$Remove, [Switch]$DryRun)
    & "$PSScriptRoot/../../src/powershell/utils/slab-set-registry.ps1" -Path $Path -Name $Name -Value $Value -PropertyType $Type -Remove:$Remove -DryRun:$DryRun
}

$policyFolder = "Software\Policies\Microsoft\Windows\Control Panel\Desktop"
$paths = @("HKLM:\$policyFolder", "HKCU:\$policyFolder", "HKCU:\Control Panel\Desktop")
if (Test-Path "HKU:\DefaultUser") {
    $paths += "HKU:\DefaultUser\$policyFolder"
    $paths += "HKU:\DefaultUser\Control Panel\Desktop"
}

if ($shouldUndo) {
    Write-Host "Restoring default screensaver settings..." -ForegroundColor Cyan
    foreach ($path in $paths) {
        &$registryTweak -Path $path -Name "ScreenSaveTimeOut" -Remove -DryRun:$DryRun
        &$registryTweak -Path $path -Name "ScreenSaveActive" -Remove -DryRun:$DryRun
        &$registryTweak -Path $path -Name "ScreenSaverIsSecure" -Remove -DryRun:$DryRun
        &$registryTweak -Path $path -Name "SCRNSAVE.EXE" -Remove -DryRun:$DryRun
    }
} else {
    Write-Host "Disabling screensaver for HKLM, HKCU, and Default User..." -ForegroundColor Cyan
    foreach ($path in $paths) {
        &$registryTweak -Path $path -Name "ScreenSaveTimeOut" -Value "0" -Type "String" -DryRun:$DryRun
        &$registryTweak -Path $path -Name "ScreenSaveActive" -Value "0" -Type "String" -DryRun:$DryRun
        &$registryTweak -Path $path -Name "ScreenSaverIsSecure" -Value "0" -Type "String" -DryRun:$DryRun
        &$registryTweak -Path $path -Name "SCRNSAVE.EXE" -Value "" -Type "String" -DryRun:$DryRun
    }
}