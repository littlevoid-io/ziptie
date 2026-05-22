[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.disableWindowsWidgets
$shouldUndo = $Undo -or !$tweakEnabled

. "$PSScriptRoot/../utils/slab-init.ps1"

$policyDsh = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
$policyFeeds = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds"
$hkcuAdvanced = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

if ($shouldUndo) {
    Write-Host "Restoring Windows Widgets taskbar icons and GPO access..." -ForegroundColor Cyan
    
    &$registryTweak -Path $policyDsh -Name "AllowNewsAndInterests" -Remove
    &$registryTweak -Path $policyFeeds -Name "EnableFeeds" -Remove
    
    &$registryTweak -Path $hkcuAdvanced -Name "TaskbarDa" -Value 1 -Type "DWord"
} else {
    Write-Host "Disabling Windows Widgets taskbar icons and GPO locks..." -ForegroundColor Cyan
    
    &$registryTweak -Path $policyDsh -Name "AllowNewsAndInterests" -Value 0 -Type "DWord"
    &$registryTweak -Path $policyFeeds -Name "EnableFeeds" -Value 0 -Type "DWord"
    
    &$registryTweak -Path $hkcuAdvanced -Name "TaskbarDa" -Value 0 -Type "DWord"
}

