[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.blackDesktopBackground
$shouldUndo = $Undo -or !$tweakEnabled

$registryTweak = {
    Param([String]$Path, [String]$Name, [Object]$Value, [String]$Type, [Switch]$Remove, [Switch]$DryRun)
    & "$PSScriptRoot/../../src/powershell/utils/slab-set-registry.ps1" -Path $Path -Name $Name -Value $Value -PropertyType $Type -Remove:$Remove -DryRun:$DryRun
}

$paths = @("HKCU:\Control Panel\Colors", "HKCU:\Control Panel\Desktop")
if (Test-Path "HKU:\DefaultUser") {
    $paths += "HKU:\DefaultUser\Control Panel\Colors"
    $paths += "HKU:\DefaultUser\Control Panel\Desktop"
}

if ($shouldUndo) {
    Write-Host "Restoring default desktop background settings..." -ForegroundColor Cyan
    foreach ($path in $paths) {
        if ($path -like "*Colors") {
            &$registryTweak -Path $path -Name "Background" -Value "0 120 215" -Type "String" -DryRun:$DryRun
        } else {
            &$registryTweak -Path $path -Name "Wallpaper" -Remove -DryRun:$DryRun
        }
    }
} else {
    Write-Host "Setting desktop background to solid black..." -ForegroundColor Cyan
    foreach ($path in $paths) {
        if ($path -like "*Colors") {
            &$registryTweak -Path $path -Name "Background" -Value "0 0 0" -Type "String" -DryRun:$DryRun
        } else {
            &$registryTweak -Path $path -Name "Wallpaper" -Value "" -Type "String" -DryRun:$DryRun
        }
    }
}
