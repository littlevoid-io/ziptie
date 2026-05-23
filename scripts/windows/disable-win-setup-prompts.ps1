[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)] [Object]$Config,
    [Switch]$DryRun, [Switch]$Undo
)

. "$PSScriptRoot/../utils/ziptie-init.ps1"

$tweakEnabled = $Config.lockdown.disableOOBEPrompts
$shouldUndo = $Undo -or !$tweakEnabled

$hkcuPaths = @("HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager")
$hklmCloud = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"

if ($shouldUndo) {
    Write-Host "Restoring default Windows OOBE and setup prompts..." -ForegroundColor Cyan
    foreach ($path in $hkcuPaths) {
        if ($path -like "*UserProfileEngagement") {
            &$registryTweak -Path $path -Name "ScoobeSystemSettingEnabled" -Remove
        } else {
            &$registryTweak -Path $path -Name "SubscribedContent-310093Enabled" -Remove
            &$registryTweak -Path $path -Name "SubscribedContent-338387Enabled" -Remove
        }
    }
    &$registryTweak -Path $hklmCloud -Name "DisableWindowsConsumerFeatures" -Remove
} else {
    Write-Host "Disabling Windows OOBE setup prompts and personalization suggestions..." -ForegroundColor Cyan
    foreach ($path in $hkcuPaths) {
        if ($path -like "*UserProfileEngagement") {
            &$registryTweak -Path $path -Name "ScoobeSystemSettingEnabled" -Value 0 -Type "DWord"
        } else {
            &$registryTweak -Path $path -Name "SubscribedContent-310093Enabled" -Value 0 -Type "DWord"
            &$registryTweak -Path $path -Name "SubscribedContent-338387Enabled" -Value 0 -Type "DWord"
        }
    }
    &$registryTweak -Path $hklmCloud -Name "DisableWindowsConsumerFeatures" -Value 1 -Type "DWord"
}
