[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.disableEdgeSwipes
$shouldUndo = $Undo -or !$tweakEnabled

$registryTweak = {
    Param([String]$Path, [String]$Name, [Object]$Value, [String]$Type, [Switch]$Remove, [Switch]$DryRun)
    & "$PSScriptRoot/../../src/powershell/utils/slab-set-registry.ps1" -Path $Path -Name $Name -Value $Value -PropertyType $Type -Remove:$Remove -DryRun:$DryRun
}

$path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI"

if ($shouldUndo) {
    Write-Host "Enabling edge swipes..." -ForegroundColor Cyan
    &$registryTweak -Path $path -Name "AllowEdgeSwipe" -Remove -DryRun:$DryRun
} else {
    Write-Host "Disabling edge swipes..." -ForegroundColor Cyan
    &$registryTweak -Path $path -Name "AllowEdgeSwipe" -Value 0 -Type "DWord" -DryRun:$DryRun
}