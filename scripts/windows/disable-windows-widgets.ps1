[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.disableWindowsWidgets
$shouldUndo = $Undo -or !$tweakEnabled

$registryTweak = {
    Param([String]$Path, [String]$Name, [Object]$Value, [String]$Type, [Switch]$Remove, [Switch]$DryRun)
    & "$PSScriptRoot/../../src/powershell/utils/slab-set-registry.ps1" -Path $Path -Name $Name -Value $Value -PropertyType $Type -Remove:$Remove -DryRun:$DryRun
}

$policyDsh = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
$policyFeeds = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds"
$hkcuAdvanced = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$defaultUserAdvanced = "HKU:\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

if ($shouldUndo) {
    Write-Host "Restoring Windows Widgets taskbar icons and GPO access..." -ForegroundColor Cyan
    
    &$registryTweak -Path $policyDsh -Name "AllowNewsAndInterests" -Remove -DryRun:$DryRun
    &$registryTweak -Path $policyFeeds -Name "EnableFeeds" -Remove -DryRun:$DryRun
    
    &$registryTweak -Path $hkcuAdvanced -Name "TaskbarDa" -Value 1 -Type "DWord" -DryRun:$DryRun
    if (Test-Path "HKU:\DefaultUser") {
        &$registryTweak -Path $defaultUserAdvanced -Name "TaskbarDa" -Value 1 -Type "DWord" -DryRun:$DryRun
    }
} else {
    Write-Host "Disabling Windows Widgets taskbar icons and GPO locks..." -ForegroundColor Cyan
    
    &$registryTweak -Path $policyDsh -Name "AllowNewsAndInterests" -Value 0 -Type "DWord" -DryRun:$DryRun
    &$registryTweak -Path $policyFeeds -Name "EnableFeeds" -Value 0 -Type "DWord" -DryRun:$DryRun
    
    &$registryTweak -Path $hkcuAdvanced -Name "TaskbarDa" -Value 0 -Type "DWord" -DryRun:$DryRun
    if (Test-Path "HKU:\DefaultUser") {
        &$registryTweak -Path $defaultUserAdvanced -Name "TaskbarDa" -Value 0 -Type "DWord" -DryRun:$DryRun
    }
}
