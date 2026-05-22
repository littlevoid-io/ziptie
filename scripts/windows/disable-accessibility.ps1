[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)] [Object]$Config,
    [Switch]$DryRun, [Switch]$Undo
)

. "$PSScriptRoot/../../src/powershell/utils/slab-init.ps1"

$tweakEnabled = $Config.lockdown.disableAccessibilityShortcuts
$shouldUndo = $Undo -or !$tweakEnabled

$path = "HKCU:\Control Panel\Accessibility"

if ($shouldUndo) {
    Write-Host "Enabling keyboard accessibility shortcuts..." -ForegroundColor Cyan
    &$registryTweak -Path "$path\StickyKeys" -Name "Flags" -Value "510" -Type "String"
    &$registryTweak -Path "$path\Keyboard Response" -Name "Flags" -Value "126" -Type "String"
    &$registryTweak -Path "$path\ToggleKeys" -Name "Flags" -Value "62" -Type "String"
} else {
    Write-Host "Disabling keyboard accessibility shortcuts..." -ForegroundColor Cyan
    &$registryTweak -Path "$path\StickyKeys" -Name "Flags" -Value "506" -Type "String"
    &$registryTweak -Path "$path\Keyboard Response" -Name "Flags" -Value "122" -Type "String"
    &$registryTweak -Path "$path\ToggleKeys" -Name "Flags" -Value "58" -Type "String"
}