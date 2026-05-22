[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.disableOOBEPrompts
$shouldUndo = $Undo -or !$tweakEnabled

$registryTweak = {
    Param([String]$Path, [String]$Name, [Object]$Value, [String]$Type, [Switch]$Remove, [Switch]$DryRun)
    & "$PSScriptRoot/../../src/powershell/utils/slab-set-registry.ps1" -Path $Path -Name $Name -Value $Value -PropertyType $Type -Remove:$Remove -DryRun:$DryRun
}

$hkcuPaths = @("HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement", "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager")
if (Test-Path "HKU:\DefaultUser") {
    $hkcuPaths += "HKU:\DefaultUser\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement"
    $hkcuPaths += "HKU:\DefaultUser\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
}
$hklmCloud = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"

if ($shouldUndo) {
    Write-Host "Restoring default Windows OOBE and setup prompts..." -ForegroundColor Cyan
    foreach ($path in $hkcuPaths) {
        if ($path -like "*UserProfileEngagement") {
            &$registryTweak -Path $path -Name "ScoobeSystemSettingEnabled" -Remove -DryRun:$DryRun
        } else {
            &$registryTweak -Path $path -Name "SubscribedContent-310093Enabled" -Remove -DryRun:$DryRun
            &$registryTweak -Path $path -Name "SubscribedContent-338387Enabled" -Remove -DryRun:$DryRun
        }
    }
    &$registryTweak -Path $hklmCloud -Name "DisableWindowsConsumerFeatures" -Remove -DryRun:$DryRun
} else {
    Write-Host "Disabling Windows OOBE setup prompts and personalization suggestions..." -ForegroundColor Cyan
    foreach ($path in $hkcuPaths) {
        if ($path -like "*UserProfileEngagement") {
            &$registryTweak -Path $path -Name "ScoobeSystemSettingEnabled" -Value 0 -Type "DWord" -DryRun:$DryRun
        } else {
            &$registryTweak -Path $path -Name "SubscribedContent-310093Enabled" -Value 0 -Type "DWord" -DryRun:$DryRun
            &$registryTweak -Path $path -Name "SubscribedContent-338387Enabled" -Value 0 -Type "DWord" -DryRun:$DryRun
        }
    }
    &$registryTweak -Path $hklmCloud -Name "DisableWindowsConsumerFeatures" -Value 1 -Type "DWord" -DryRun:$DryRun
}