[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.enableScriptExecution
$shouldUndo = $Undo -or !$tweakEnabled

. "$PSScriptRoot/../utils/slab-init.ps1"

if ($shouldUndo) {
    Write-Host "Restoring default script execution policy..." -ForegroundColor Cyan
    &$registryTweak -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows" -Name "EnableScripts" -Remove
    &$registryTweak -Path "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell" -Name "ExecutionPolicy" -Remove
} else {
    Write-Host "Configuring PowerShell script execution policy to RemoteSigned..." -ForegroundColor Cyan
    &$registryTweak -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows" -Name "EnableScripts" -Value 1 -Type "DWord"
    &$registryTweak -Path "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell" -Name "ExecutionPolicy" -Value "RemoteSigned" -Type "String"
}
