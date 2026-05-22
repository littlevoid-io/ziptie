[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)] [Object]$Config,
    [Switch]$DryRun, [Switch]$Undo
)

. "$PSScriptRoot/../../src/powershell/utils/slab-init.ps1"

$tweakEnabled = $Config.lockdown.disableAppInstalls
$shouldUndo = $Undo -or !$tweakEnabled

$path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"

$keys = @(
    "FeatureManagementEnabled", "OemPreInstalledAppsEnabled", "PreInstalledAppsEnabled",
    "SilentInstalledAppsEnabled", "ContentDeliveryAllowed", "PreInstalledAppsEverEnabled",
    "SubscribedContentEnabled", "SubscribedContent-338388Enabled", "SubscribedContent-338389Enabled",
    "SubscribedContent-314559Enabled", "SubscribedContent-338387Enabled", "SubscribedContent-338393Enabled",
    "SubscribedContent-310093Enabled", "SystemPaneSuggestionsEnabled", "SoftLandingEnabled"
)

if ($shouldUndo) {
    Write-Host "Re-enabling automatic consumer app installations..." -ForegroundColor Cyan
    foreach ($key in $keys) {
        &$registryTweak -Path $path -Name $key -Remove
    }
    &$registryTweak -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore" -Name "AutoDownload" -Remove
    &$registryTweak -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Remove
} else {
    Write-Host "Disabling automatic consumer app installations (Content Delivery Manager & GPO)..." -ForegroundColor Cyan
    foreach ($key in $keys) {
        &$registryTweak -Path $path -Name $key -Value 0 -Type "DWord"
    }
    &$registryTweak -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore" -Name "AutoDownload" -Value 2 -Type "DWord"
    &$registryTweak -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Value 1 -Type "DWord"
}
