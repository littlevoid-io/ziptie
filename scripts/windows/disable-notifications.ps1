[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.disableNotifications
$shouldUndo = $Undo -or !$tweakEnabled

$registryTweak = {
    Param([String]$Path, [String]$Name, [Object]$Value, [String]$Type, [Switch]$Remove, [Switch]$DryRun)
    & "$PSScriptRoot/../../src/powershell/utils/slab-set-registry.ps1" -Path $Path -Name $Name -Value $Value -PropertyType $Type -Remove:$Remove -DryRun:$DryRun
}

$explorerPaths = @("HKCU:\Software\Policies\Microsoft\Windows\Explorer")
$pushPaths = @("HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications")

if (Test-Path "HKU:\DefaultUser") {
    $explorerPaths += "HKU:\DefaultUser\Software\Policies\Microsoft\Windows\Explorer"
    $pushPaths += "HKU:\DefaultUser\Software\Microsoft\Windows\CurrentVersion\PushNotifications"
}

if ($shouldUndo) {
    Write-Host "Re-enabling toast notifications and Notification Center..." -ForegroundColor Cyan
    foreach ($p in $explorerPaths) {
        &$registryTweak -Path $p -Name "DisableNotificationCenter" -Remove -DryRun:$DryRun
    }
    foreach ($p in $pushPaths) {
        &$registryTweak -Path $p -Name "ToastEnabled" -Remove -DryRun:$DryRun
    }
} else {
    Write-Host "Disabling toast notifications and Notification Center..." -ForegroundColor Cyan
    foreach ($p in $explorerPaths) {
        &$registryTweak -Path $p -Name "DisableNotificationCenter" -Value 1 -Type "DWord" -DryRun:$DryRun
    }
    foreach ($p in $pushPaths) {
        &$registryTweak -Path $p -Name "ToastEnabled" -Value 0 -Type "DWord" -DryRun:$DryRun
    }
}