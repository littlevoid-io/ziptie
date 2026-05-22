[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.autologon.enabled
$shouldUndo = $Undo -or !$tweakEnabled

$registryTweak = {
    Param([String]$Path, [String]$Name, [Object]$Value, [String]$Type, [Switch]$Remove, [Switch]$DryRun)
    & "$PSScriptRoot/../../src/powershell/utils/slab-set-registry.ps1" -Path $Path -Name $Name -Value $Value -PropertyType $Type -Remove:$Remove -DryRun:$DryRun
}

$winlogonPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon"
$passwordlessPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device"

if ($shouldUndo) {
    Write-Host "Restoring default logon behavior (disabling autologon)..." -ForegroundColor Cyan
    &$registryTweak -Path $winlogonPath -Name "AutoAdminLogon" -Value "0" -Type "String" -DryRun:$DryRun
    &$registryTweak -Path $winlogonPath -Name "DefaultUserName" -Remove -DryRun:$DryRun
    &$registryTweak -Path $winlogonPath -Name "DefaultPassword" -Remove -DryRun:$DryRun
    
    if ($Config.autologon.disablePasswordlessHello) {
        &$registryTweak -Path $passwordlessPath -Name "DevicePasswordLessBuildVersion" -Remove -DryRun:$DryRun
    }
} else {
    $username = $Config.autologon.username
    # Securely retrieve the password from environment if available, otherwise default to blank
    $password = $env:SLAB_AUTOLOGON_PASSWORD
    if (!$password) { $password = "" }
    
    Write-Host "Enabling automatic logon for user '$username'..." -ForegroundColor Cyan
    
    if ($Config.autologon.disablePasswordlessHello) {
        Write-Host "Disabling Windows Hello passwordless constraints globally..." -ForegroundColor Cyan
        &$registryTweak -Path $passwordlessPath -Name "DevicePasswordLessBuildVersion" -Value 0 -Type "DWord" -DryRun:$DryRun
    }
    
    &$registryTweak -Path $winlogonPath -Name "AutoAdminLogon" -Value "1" -Type "String" -DryRun:$DryRun
    &$registryTweak -Path $winlogonPath -Name "DefaultDomainName" -Value $env:COMPUTERNAME -Type "String" -DryRun:$DryRun
    &$registryTweak -Path $winlogonPath -Name "DefaultUserName" -Value $username -Type "String" -DryRun:$DryRun
    &$registryTweak -Path $winlogonPath -Name "DefaultPassword" -Value $password -Type "String" -DryRun:$DryRun
}