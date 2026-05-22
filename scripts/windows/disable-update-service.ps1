[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)] [Object]$Config,
    [Switch]$DryRun, [Switch]$Undo
)

. "$PSScriptRoot/../utils/slab-init.ps1"

$tweakEnabled = $Config.lockdown.disableWindowsUpdate
$shouldUndo = $Undo -or !$tweakEnabled

$policyAU = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
$policyWU = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$uxSettings = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"

if ($shouldUndo) {
    Write-Host "Restoring Windows Update services and settings..." -ForegroundColor Cyan
    
    & "$PSScriptRoot/../utils/slab-set-service.ps1" -ServiceName "wuauserv" -StartupType "Automatic" -State "Running" -DryRun:$DryRun
    & "$PSScriptRoot/../utils/slab-set-service.ps1" -ServiceName "UsoSvc" -StartupType "Automatic" -State "Running" -DryRun:$DryRun
    &$registryTweak -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" -Name "Start" -Value 3 -Type "DWord" # Manual
    
    &$registryTweak -Path $policyAU -Name "NoAutoUpdate" -Remove
    &$registryTweak -Path $policyAU -Name "AUOptions" -Remove
    &$registryTweak -Path $policyWU -Name "ExcludeWUDriversInQualityUpdate" -Remove
    &$registryTweak -Path $policyWU -Name "TargetReleaseVersion" -Remove
    &$registryTweak -Path $policyWU -Name "TargetReleaseVersionInfo" -Remove
    &$registryTweak -Path $uxSettings -Name "PauseUpdatesExpiryTime" -Remove
    &$registryTweak -Path $uxSettings -Name "PauseFeatureUpdatesStartTime" -Remove
    &$registryTweak -Path $uxSettings -Name "PauseQualityUpdatesStartTime" -Remove
    &$registryTweak -Path $uxSettings -Name "PauseUpdatesStartTime" -Remove
} else {
    Write-Host "Applying Windows Update pause GPO locks and service stops..." -ForegroundColor Cyan
    
    & "$PSScriptRoot/../utils/slab-set-service.ps1" -ServiceName "wuauserv" -StartupType "Disabled" -State "Stopped" -DryRun:$DryRun
    & "$PSScriptRoot/../utils/slab-set-service.ps1" -ServiceName "UsoSvc" -StartupType "Disabled" -State "Stopped" -DryRun:$DryRun
    
    &$registryTweak -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" -Name "Start" -Value 4 -Type "DWord"
    
    &$registryTweak -Path $policyAU -Name "NoAutoUpdate" -Value 1 -Type "DWord"
    &$registryTweak -Path $policyAU -Name "AUOptions" -Value 2 -Type "DWord"
    &$registryTweak -Path $policyWU -Name "ExcludeWUDriversInQualityUpdate" -Value 1 -Type "DWord"
    
    $osVersion = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name DisplayVersion -ErrorAction SilentlyContinue).DisplayVersion
    if (!$osVersion) { $osVersion = "23H2" }
    &$registryTweak -Path $policyWU -Name "TargetReleaseVersion" -Value 1 -Type "DWord"
    &$registryTweak -Path $policyWU -Name "TargetReleaseVersionInfo" -Value $osVersion -Type "String"
    
    $futureTime = "2099-12-31T23:59:59Z"
    $nowTime = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    &$registryTweak -Path $uxSettings -Name "PauseUpdatesExpiryTime" -Value $futureTime -Type "String"
    &$registryTweak -Path $uxSettings -Name "PauseFeatureUpdatesStartTime" -Value $nowTime -Type "String"
    &$registryTweak -Path $uxSettings -Name "PauseQualityUpdatesStartTime" -Value $nowTime -Type "String"
    &$registryTweak -Path $uxSettings -Name "PauseUpdatesStartTime" -Value $nowTime -Type "String"
}
