[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.disableTouchGestures
$shouldUndo = $Undo -or !$tweakEnabled

$registryTweak = {
    Param([String]$Path, [String]$Name, [Object]$Value, [String]$Type, [Switch]$Remove, [Switch]$DryRun)
    & "$PSScriptRoot/../../src/powershell/utils/slab-set-registry.ps1" -Path $Path -Name $Name -Value $Value -PropertyType $Type -Remove:$Remove -DryRun:$DryRun
}

$paths = @("HKCU:\Control Panel\Desktop")
if (Test-Path "HKU:\DefaultUser") {
    $paths += "HKU:\DefaultUser\Control Panel\Desktop"
}

if ($shouldUndo) {
    Write-Host "Re-enabling default touch gestures..." -ForegroundColor Cyan
    foreach ($p in $paths) {
        &$registryTweak -Path $p -Name "TouchGestureSetting" -Remove -DryRun:$DryRun
    }
} else {
    Write-Host "Disabling advanced touch gestures (preventing app exiting via swipes)..." -ForegroundColor Cyan
    foreach ($p in $paths) {
        &$registryTweak -Path $p -Name "TouchGestureSetting" -Value 0 -Type "DWord" -DryRun:$DryRun
    }
}
