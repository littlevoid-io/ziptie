[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.disableAccessibilityShortcuts
$shouldUndo = $Undo -or !$tweakEnabled

$registryTweak = {
    Param([String]$Path, [String]$Name, [Object]$Value, [String]$Type, [Switch]$Remove, [Switch]$DryRun)
    & "$PSScriptRoot/../../src/powershell/utils/slab-set-registry.ps1" -Path $Path -Name $Name -Value $Value -PropertyType $Type -Remove:$Remove -DryRun:$DryRun
}

$paths = @("HKCU:\Control Panel\Accessibility")
if (Test-Path "HKU:\DefaultUser") {
    $paths += "HKU:\DefaultUser\Control Panel\Accessibility"
}

if ($shouldUndo) {
    Write-Host "Enabling keyboard accessibility shortcuts..." -ForegroundColor Cyan
    foreach ($path in $paths) {
        &$registryTweak -Path "$path\StickyKeys" -Name "Flags" -Value "510" -Type "String" -DryRun:$DryRun
        &$registryTweak -Path "$path\Keyboard Response" -Name "Flags" -Value "126" -Type "String" -DryRun:$DryRun
        &$registryTweak -Path "$path\ToggleKeys" -Name "Flags" -Value "62" -Type "String" -DryRun:$DryRun
    }
} else {
    Write-Host "Disabling keyboard accessibility shortcuts..." -ForegroundColor Cyan
    foreach ($path in $paths) {
        &$registryTweak -Path "$path\StickyKeys" -Name "Flags" -Value "506" -Type "String" -DryRun:$DryRun
        &$registryTweak -Path "$path\Keyboard Response" -Name "Flags" -Value "122" -Type "String" -DryRun:$DryRun
        &$registryTweak -Path "$path\ToggleKeys" -Name "Flags" -Value "58" -Type "String" -DryRun:$DryRun
    }
}