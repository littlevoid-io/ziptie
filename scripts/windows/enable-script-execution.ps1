[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.enableScriptExecution
$shouldUndo = $Undo -or !$tweakEnabled

$registryTweak = {
    Param([String]$Path, [String]$Name, [Object]$Value, [String]$Type, [Switch]$Remove, [Switch]$DryRun)
    & "$PSScriptRoot/../../src/powershell/utils/slab-set-registry.ps1" -Path $Path -Name $Name -Value $Value -PropertyType $Type -Remove:$Remove -DryRun:$DryRun
}

if ($shouldUndo) {
    Write-Host "Restoring default script execution policy..." -ForegroundColor Cyan
    &$registryTweak -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows" -Name "EnableScripts" -Remove -DryRun:$DryRun
    &$registryTweak -Path "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell" -Name "ExecutionPolicy" -Remove -DryRun:$DryRun
} else {
    Write-Host "Configuring PowerShell script execution policy to RemoteSigned..." -ForegroundColor Cyan
    &$registryTweak -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows" -Name "EnableScripts" -Value 1 -Type "DWord" -DryRun:$DryRun
    &$registryTweak -Path "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell" -Name "ExecutionPolicy" -Value "RemoteSigned" -Type "String" -DryRun:$DryRun
}
