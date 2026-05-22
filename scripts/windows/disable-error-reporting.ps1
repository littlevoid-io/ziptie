[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.disableErrorReporting
$shouldUndo = $Undo -or !$tweakEnabled

$registryTweak = {
    Param([String]$Path, [String]$Name, [Object]$Value, [String]$Type, [Switch]$Remove, [Switch]$DryRun)
    & "$PSScriptRoot/../../src/powershell/utils/slab-set-registry.ps1" -Path $Path -Name $Name -Value $Value -PropertyType $Type -Remove:$Remove -DryRun:$DryRun
}

$path = "HKLM:\Software\Microsoft\Windows\Windows Error Reporting"

if ($shouldUndo) {
    Write-Host "Re-enabling Windows Error Reporting..." -ForegroundColor Cyan
    &$registryTweak -Path $path -Name "Disabled" -Remove -DryRun:$DryRun
} else {
    Write-Host "Disabling Windows Error Reporting..." -ForegroundColor Cyan
    &$registryTweak -Path $path -Name "Disabled" -Value 1 -Type "DWord" -DryRun:$DryRun
}
