[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)] [Object]$Config,
    [Switch]$DryRun, [Switch]$Undo
)

. "$PSScriptRoot/../utils/slab-init.ps1"

$tweakEnabled = $Config.lockdown.disableNotifications
$shouldUndo = $Undo -or !$tweakEnabled

$explorerPath = "HKCU:\Software\Policies\Microsoft\Windows\Explorer"
$pushPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"

if ($shouldUndo) {
    Write-Host "Re-enabling toast notifications and Notification Center..." -ForegroundColor Cyan
    &$registryTweak -Path $explorerPath -Name "DisableNotificationCenter" -Remove
    &$registryTweak -Path $pushPath -Name "ToastEnabled" -Remove
} else {
    Write-Host "Disabling toast notifications and Notification Center..." -ForegroundColor Cyan
    &$registryTweak -Path $explorerPath -Name "DisableNotificationCenter" -Value 1 -Type "DWord"
    &$registryTweak -Path $pushPath -Name "ToastEnabled" -Value 0 -Type "DWord"
}