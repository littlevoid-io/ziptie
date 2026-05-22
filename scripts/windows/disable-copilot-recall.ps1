[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.disableCopilotRecall
$shouldUndo = $Undo -or !$tweakEnabled

$registryTweak = {
    Param([String]$Path, [String]$Name, [Object]$Value, [String]$Type, [Switch]$Remove, [Switch]$DryRun)
    & "$PSScriptRoot/../../src/powershell/utils/slab-set-registry.ps1" -Path $Path -Name $Name -Value $Value -PropertyType $Type -Remove:$Remove -DryRun:$DryRun
}

# HKLM system-wide paths
$hklmCopilot = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
$hklmAI = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"

# HKCU user-specific paths
$userPaths = @("HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot")
if (Test-Path "HKU:\DefaultUser") {
    $userPaths += "HKU:\DefaultUser\Software\Policies\Microsoft\Windows\WindowsCopilot"
}

if ($shouldUndo) {
    Write-Host "Restoring Windows Copilot and Recall (AI analysis)..." -ForegroundColor Cyan
    
    &$registryTweak -Path $hklmCopilot -Name "TurnOffWindowsCopilot" -Remove -DryRun:$DryRun
    &$registryTweak -Path $hklmAI -Name "DisableAIDataAnalysis" -Remove -DryRun:$DryRun
    
    foreach ($path in $userPaths) {
        &$registryTweak -Path $path -Name "TurnOffWindowsCopilot" -Remove -DryRun:$DryRun
    }
} else {
    Write-Host "Disabling Windows Copilot and Recall (AI analysis) via Group Policies..." -ForegroundColor Cyan
    
    &$registryTweak -Path $hklmCopilot -Name "TurnOffWindowsCopilot" -Value 1 -Type "DWord" -DryRun:$DryRun
    &$registryTweak -Path $hklmAI -Name "DisableAIDataAnalysis" -Value 1 -Type "DWord" -DryRun:$DryRun
    
    foreach ($path in $userPaths) {
        &$registryTweak -Path $path -Name "TurnOffWindowsCopilot" -Value 1 -Type "DWord" -DryRun:$DryRun
    }
}
