[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.disableAppRestore
$shouldUndo = $Undo -or !$tweakEnabled

$registryTweak = {
    Param([String]$Path, [String]$Name, [Object]$Value, [String]$Type, [Switch]$Remove, [Switch]$DryRun)
    & "$PSScriptRoot/../../src/powershell/utils/slab-set-registry.ps1" -Path $Path -Name $Name -Value $Value -PropertyType $Type -Remove:$Remove -DryRun:$DryRun
}

$path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$name = "DisableAutomaticRestartSignOn"

if ($shouldUndo) {
    Write-Host "Re-enabling automatic app restoration on startup..." -ForegroundColor Cyan
    &$registryTweak -Path $path -Name $name -Remove -DryRun:$DryRun
} else {
    Write-Host "Disabling automatic app restoration on startup..." -ForegroundColor Cyan
    &$registryTweak -Path $path -Name $name -Value 1 -Type "DWord" -DryRun:$DryRun
}
