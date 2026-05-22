[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.clearDesktopIcons
$shouldUndo = $Undo -or !$tweakEnabled

$registryTweak = {
    Param([String]$Path, [String]$Name, [Object]$Value, [String]$Type, [Switch]$Remove, [Switch]$DryRun)
    & "$PSScriptRoot/../../src/powershell/utils/slab-set-registry.ps1" -Path $Path -Name $Name -Value $Value -PropertyType $Type -Remove:$Remove -DryRun:$DryRun
}

$paths = @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced")
if (Test-Path "HKU:\DefaultUser") {
    $paths += "HKU:\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
}

if ($shouldUndo) {
    Write-Host "Showing desktop icons..." -ForegroundColor Cyan
    foreach ($path in $paths) {
        &$registryTweak -Path $path -Name "HideIcons" -Value 0 -Type "DWord" -DryRun:$DryRun
    }
} else {
    Write-Host "Hiding desktop icons..." -ForegroundColor Cyan
    foreach ($path in $paths) {
        &$registryTweak -Path $path -Name "HideIcons" -Value 1 -Type "DWord" -DryRun:$DryRun
    }
}
