[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)] [Object]$Config,
    [Switch]$DryRun, [Switch]$Undo
)

. "$PSScriptRoot/../utils/ziptie-init.ps1"

$tweakEnabled = $Config.lockdown.disableCopilotRecall
$shouldUndo = $Undo -or !$tweakEnabled

# HKLM system-wide paths
$hklmCopilot = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"
$hklmAI = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"

# HKCU user-specific path
$userPath = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"

if ($shouldUndo) {
    Write-Host "Restoring Windows Copilot and Recall (AI analysis)..." -ForegroundColor Cyan
    
    &$registryTweak -Path $hklmCopilot -Name "TurnOffWindowsCopilot" -Remove
    &$registryTweak -Path $hklmAI -Name "DisableAIDataAnalysis" -Remove
    &$registryTweak -Path $userPath -Name "TurnOffWindowsCopilot" -Remove
} else {
    Write-Host "Disabling Windows Copilot and Recall (AI analysis) via Group Policies..." -ForegroundColor Cyan
    
    &$registryTweak -Path $hklmCopilot -Name "TurnOffWindowsCopilot" -Value 1 -Type "DWord"
    &$registryTweak -Path $hklmAI -Name "DisableAIDataAnalysis" -Value 1 -Type "DWord"
    &$registryTweak -Path $userPath -Name "TurnOffWindowsCopilot" -Value 1 -Type "DWord"
}
