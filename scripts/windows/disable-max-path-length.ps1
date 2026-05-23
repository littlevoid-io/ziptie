[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)] [Object]$Config,
    [Switch]$DryRun, [Switch]$Undo
)

. "$PSScriptRoot/../utils/ziptie-init.ps1"

$tweakEnabled = $Config.lockdown.disableMaxPathLength
$shouldUndo = $Undo -or !$tweakEnabled

$path = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"

if ($shouldUndo) {
    Write-Host "Restoring default path length limit (260 characters)..." -ForegroundColor Cyan
    &$registryTweak -Path $path -Name "LongPathsEnabled" -Remove
} else {
    Write-Host "Disabling maximum path length limit (enabling long paths)..." -ForegroundColor Cyan
    &$registryTweak -Path $path -Name "LongPathsEnabled" -Value 1 -Type "DWord"
}
