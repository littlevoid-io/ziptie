[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.disableMaxPathLength
$shouldUndo = $Undo -or !$tweakEnabled

$registryTweak = {
    Param([String]$Path, [String]$Name, [Object]$Value, [String]$Type, [Switch]$Remove, [Switch]$DryRun)
    & "$PSScriptRoot/../../src/powershell/utils/slab-set-registry.ps1" -Path $Path -Name $Name -Value $Value -PropertyType $Type -Remove:$Remove -DryRun:$DryRun
}

$path = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"

if ($shouldUndo) {
    Write-Host "Restoring default path length limit (260 characters)..." -ForegroundColor Cyan
    &$registryTweak -Path $path -Name "LongPathsEnabled" -Remove -DryRun:$DryRun
} else {
    Write-Host "Disabling maximum path length limit (enabling long paths)..." -ForegroundColor Cyan
    &$registryTweak -Path $path -Name "LongPathsEnabled" -Value 1 -Type "DWord" -DryRun:$DryRun
}