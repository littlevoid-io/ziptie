[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.disableAppInstalls
$shouldUndo = $Undo -or !$tweakEnabled

$registryTweak = {
    Param([String]$Path, [String]$Name, [Object]$Value, [String]$Type, [Switch]$Remove, [Switch]$DryRun)
    & "$PSScriptRoot/../../src/powershell/utils/slab-set-registry.ps1" -Path $Path -Name $Name -Value $Value -PropertyType $Type -Remove:$Remove -DryRun:$DryRun
}

$userPaths = @("HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager")
if (Test-Path "HKU:\DefaultUser") {
    $userPaths += "HKU:\DefaultUser\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
}

$keys = @(
    "FeatureManagementEnabled", "OemPreInstalledAppsEnabled", "PreInstalledAppsEnabled",
    "SilentInstalledAppsEnabled", "ContentDeliveryAllowed", "PreInstalledAppsEverEnabled",
    "SubscribedContentEnabled", "SubscribedContent-338388Enabled", "SubscribedContent-338389Enabled",
    "SubscribedContent-314559Enabled", "SubscribedContent-338387Enabled", "SubscribedContent-338393Enabled",
    "SubscribedContent-310093Enabled", "SystemPaneSuggestionsEnabled", "SoftLandingEnabled"
)

if ($shouldUndo) {
    Write-Host "Re-enabling automatic consumer app installations..." -ForegroundColor Cyan
    foreach ($path in $userPaths) {
        foreach ($key in $keys) {
            &$registryTweak -Path $path -Name $key -Remove -DryRun:$DryRun
        }
    }
    &$registryTweak -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore" -Name "AutoDownload" -Remove -DryRun:$DryRun
    &$registryTweak -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Remove -DryRun:$DryRun
} else {
    Write-Host "Disabling automatic consumer app installations (Content Delivery Manager & GPO)..." -ForegroundColor Cyan
    foreach ($path in $userPaths) {
        foreach ($key in $keys) {
            &$registryTweak -Path $path -Name $key -Value 0 -Type "DWord" -DryRun:$DryRun
        }
    }
    &$registryTweak -Path "HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore" -Name "AutoDownload" -Value 2 -Type "DWord" -DryRun:$DryRun
    &$registryTweak -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Value 1 -Type "DWord" -DryRun:$DryRun
}
