[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.enableDarkMode
$shouldUndo = $Undo -or !$tweakEnabled

$registryTweak = {
    Param([String]$Path, [String]$Name, [Object]$Value, [String]$Type, [Switch]$Remove, [Switch]$DryRun)
    & "$PSScriptRoot/../../src/powershell/utils/slab-set-registry.ps1" -Path $Path -Name $Name -Value $Value -PropertyType $Type -Remove:$Remove -DryRun:$DryRun
}

$paths = @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize")
if (Test-Path "HKU:\DefaultUser") {
    $paths += "HKU:\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
}

if ($shouldUndo) {
    Write-Host "Enabling Windows Light Mode (restoring defaults)..." -ForegroundColor Cyan
    foreach ($path in $paths) {
        &$registryTweak -Path $path -Name "AppsUseLightTheme" -Value 1 -Type "DWord" -DryRun:$DryRun
        &$registryTweak -Path $path -Name "SystemUsesLightTheme" -Value 1 -Type "DWord" -DryRun:$DryRun
    }
} else {
    Write-Host "Enabling Windows Dark Mode..." -ForegroundColor Cyan
    foreach ($path in $paths) {
        &$registryTweak -Path $path -Name "AppsUseLightTheme" -Value 0 -Type "DWord" -DryRun:$DryRun
        &$registryTweak -Path $path -Name "SystemUsesLightTheme" -Value 0 -Type "DWord" -DryRun:$DryRun
    }
}
