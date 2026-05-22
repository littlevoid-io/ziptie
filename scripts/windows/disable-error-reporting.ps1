[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)] [Object]$Config,
    [Switch]$DryRun, [Switch]$Undo
)

. "$PSScriptRoot/../utils/slab-init.ps1"

$tweakEnabled = $Config.lockdown.disableErrorReporting
$shouldUndo = $Undo -or !$tweakEnabled

$path = "HKLM:\Software\Microsoft\Windows\Windows Error Reporting"

if ($shouldUndo) {
    Write-Host "Re-enabling Windows Error Reporting..." -ForegroundColor Cyan
    &$registryTweak -Path $path -Name "Disabled" -Remove
} else {
    Write-Host "Disabling Windows Error Reporting..." -ForegroundColor Cyan
    &$registryTweak -Path $path -Name "Disabled" -Value 1 -Type "DWord"
}
