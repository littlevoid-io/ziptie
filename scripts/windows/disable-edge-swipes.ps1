[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)] [Object]$Config,
    [Switch]$DryRun, [Switch]$Undo
)

. "$PSScriptRoot/../../src/powershell/utils/slab-init.ps1"

$tweakEnabled = $Config.lockdown.disableEdgeSwipes
$shouldUndo = $Undo -or !$tweakEnabled

$path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI"

if ($shouldUndo) {
    Write-Host "Enabling edge swipes..." -ForegroundColor Cyan
    &$registryTweak -Path $path -Name "AllowEdgeSwipe" -Remove
} else {
    Write-Host "Disabling edge swipes..." -ForegroundColor Cyan
    &$registryTweak -Path $path -Name "AllowEdgeSwipe" -Value 0 -Type "DWord"
}