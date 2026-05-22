[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.resetTextScale
$shouldUndo = $Undo -or !$tweakEnabled

$registryTweak = {
    Param([String]$Path, [String]$Name, [Object]$Value, [String]$Type, [Switch]$Remove, [Switch]$DryRun)
    & "$PSScriptRoot/../../src/powershell/utils/slab-set-registry.ps1" -Path $Path -Name $Name -Value $Value -PropertyType $Type -Remove:$Remove -DryRun:$DryRun
}

$paths = @("HKCU:\Control Panel\Desktop")
if (Test-Path "HKU:\DefaultUser") {
    $paths += "HKU:\DefaultUser\Control Panel\Desktop"
}

if ($shouldUndo) {
    Write-Host "Restoring default text scaling properties..." -ForegroundColor Cyan
    foreach ($p in $paths) {
        &$registryTweak -Path $p -Name "Win8DpiScaling" -Remove -DryRun:$DryRun
        &$registryTweak -Path $p -Name "LogPixels" -Remove -DryRun:$DryRun
    }
} else {
    Write-Host "Resetting Windows display text scaling to 100% (LogPixels=96, Win8DpiScaling=1)..." -ForegroundColor Cyan
    foreach ($p in $paths) {
        &$registryTweak -Path $p -Name "Win8DpiScaling" -Value 1 -Type "DWord" -DryRun:$DryRun
        &$registryTweak -Path $p -Name "LogPixels" -Value 96 -Type "DWord" -DryRun:$DryRun
    }
}
