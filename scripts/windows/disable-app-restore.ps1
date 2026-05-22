[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)] [Object]$Config,
    [Switch]$DryRun, [Switch]$Undo
)

. "$PSScriptRoot/../utils/slab-init.ps1"

$tweakEnabled = $Config.lockdown.disableAppRestore
$shouldUndo = $Undo -or !$tweakEnabled

$path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$name = "DisableAutomaticRestartSignOn"

if ($shouldUndo) {
    Write-Host "Re-enabling automatic app restoration on startup..." -ForegroundColor Cyan
    &$registryTweak -Path $path -Name $name -Remove
} else {
    Write-Host "Disabling automatic app restoration on startup..." -ForegroundColor Cyan
    &$registryTweak -Path $path -Name $name -Value 1 -Type "DWord"
}
