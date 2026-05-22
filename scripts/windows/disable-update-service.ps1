[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.disableWindowsUpdate
$shouldUndo = $Undo -or !$tweakEnabled

$registryTweak = {
    Param([String]$Path, [String]$Name, [Object]$Value, [String]$Type, [Switch]$Remove, [Switch]$DryRun)
    & "$PSScriptRoot/../../src/powershell/utils/slab-set-registry.ps1" -Path $Path -Name $Name -Value $Value -PropertyType $Type -Remove:$Remove -DryRun:$DryRun
}

$policyAU = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
$policyWU = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
$uxSettings = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"

if ($shouldUndo) {
    Write-Host "Restoring Windows Update services and settings..." -ForegroundColor Cyan
    
    & "$PSScriptRoot/../../src/powershell/utils/slab-set-service.ps1" -ServiceName "wuauserv" -StartupType "Automatic" -State "Running" -DryRun:$DryRun
    & "$PSScriptRoot/../../src/powershell/utils/slab-set-service.ps1" -ServiceName "UsoSvc" -StartupType "Automatic" -State "Running" -DryRun:$DryRun
    &$registryTweak -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" -Name "Start" -Value 3 -Type "DWord" -DryRun:$DryRun # Manual
    
    &$registryTweak -Path $policyAU -Name "NoAutoUpdate" -Remove -DryRun:$DryRun
    &$registryTweak -Path $policyAU -Name "AUOptions" -Remove -DryRun:$DryRun
    &$registryTweak -Path $policyWU -Name "ExcludeWUDriversInQualityUpdate" -Remove -DryRun:$DryRun
    &$registryTweak -Path $uxSettings -Name "PauseUpdatesExpiryTime" -Remove -DryRun:$DryRun
    &$registryTweak -Path $uxSettings -Name "PauseFeatureUpdatesStartTime" -Remove -DryRun:$DryRun
    &$registryTweak -Path $uxSettings -Name "PauseQualityUpdatesStartTime" -Remove -DryRun:$DryRun
    &$registryTweak -Path $uxSettings -Name "PauseUpdatesStartTime" -Remove -DryRun:$DryRun
} else {
    Write-Host "Applying Windows Update pause GPO locks and service stops..." -ForegroundColor Cyan
    
    & "$PSScriptRoot/../../src/powershell/utils/slab-set-service.ps1" -ServiceName "wuauserv" -StartupType "Disabled" -State "Stopped" -DryRun:$DryRun
    & "$PSScriptRoot/../../src/powershell/utils/slab-set-service.ps1" -ServiceName "UsoSvc" -StartupType "Disabled" -State "Stopped" -DryRun:$DryRun
    
    &$registryTweak -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc" -Name "Start" -Value 4 -Type "DWord" -DryRun:$DryRun
    
    &$registryTweak -Path $policyAU -Name "NoAutoUpdate" -Value 1 -Type "DWord" -DryRun:$DryRun
    &$registryTweak -Path $policyAU -Name "AUOptions" -Value 2 -Type "DWord" -DryRun:$DryRun
    &$registryTweak -Path $policyWU -Name "ExcludeWUDriversInQualityUpdate" -Value 1 -Type "DWord" -DryRun:$DryRun
    
    $futureTime = "2099-12-31T23:59:59Z"
    $nowTime = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    &$registryTweak -Path $uxSettings -Name "PauseUpdatesExpiryTime" -Value $futureTime -Type "String" -DryRun:$DryRun
    &$registryTweak -Path $uxSettings -Name "PauseFeatureUpdatesStartTime" -Value $nowTime -Type "String" -DryRun:$DryRun
    &$registryTweak -Path $uxSettings -Name "PauseQualityUpdatesStartTime" -Value $nowTime -Type "String" -DryRun:$DryRun
    &$registryTweak -Path $uxSettings -Name "PauseUpdatesStartTime" -Value $nowTime -Type "String" -DryRun:$DryRun
}
