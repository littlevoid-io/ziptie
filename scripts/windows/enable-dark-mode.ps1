[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.enableDarkMode
$shouldUndo = $Undo -or !$tweakEnabled

. "$PSScriptRoot/../../src/powershell/utils/slab-init.ps1"

$personalizePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"

if ($shouldUndo) {
    Write-Host "Enabling Windows Light Mode (restoring defaults)..." -ForegroundColor Cyan
    &$registryTweak -Path $personalizePath -Name "AppsUseLightTheme" -Value 1 -Type "DWord"
    &$registryTweak -Path $personalizePath -Name "SystemUsesLightTheme" -Value 1 -Type "DWord"
} else {
    Write-Host "Enabling Windows Dark Mode..." -ForegroundColor Cyan
    &$registryTweak -Path $personalizePath -Name "AppsUseLightTheme" -Value 0 -Type "DWord"
    &$registryTweak -Path $personalizePath -Name "SystemUsesLightTheme" -Value 0 -Type "DWord"
}

