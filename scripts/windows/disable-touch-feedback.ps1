[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)] [Object]$Config,
    [Switch]$DryRun, [Switch]$Undo
)

. "$PSScriptRoot/../../src/powershell/utils/slab-init.ps1"

$tweakEnabled = $Config.lockdown.disableTouchFeedback
$shouldUndo = $Undo -or !$tweakEnabled

$hkcuPaths = @("HKCU:\Control Panel\Cursors", "HKCU:\Software\Microsoft\Wisp\Touch", "HKCU:\Software\Microsoft\Wisp\Pen\SysEventParameters")
$hklmPath = "HKLM:\SOFTWARE\Policies\Microsoft\TabletTip\1.7"

if ($shouldUndo) {
    Write-Host "Restoring default touch and pen feedback..." -ForegroundColor Cyan
    
    foreach ($path in $hkcuPaths) {
        if ($path -like "*Cursors") {
            &$registryTweak -Path $path -Name "ContactVisualization" -Value 1 -Type "DWord"
            &$registryTweak -Path $path -Name "GestureVisualization" -Value 31 -Type "DWord"
        } elseif ($path -like "*Touch") {
            &$registryTweak -Path $path -Name "TouchMode_hold" -Value 1 -Type "DWord"
        } elseif ($path -like "*SysEventParameters") {
            &$registryTweak -Path $path -Name "HoldMode" -Value 1 -Type "DWord"
        }
    }
    
    &$registryTweak -Path $hklmPath -Name "DisableEdgeTarget" -Remove
} else {
    Write-Host "Disabling touch and pen visual feedback..." -ForegroundColor Cyan
    
    foreach ($path in $hkcuPaths) {
        if ($path -like "*Cursors") {
            &$registryTweak -Path $path -Name "ContactVisualization" -Value 0 -Type "DWord"
            &$registryTweak -Path $path -Name "GestureVisualization" -Value 0 -Type "DWord"
        } elseif ($path -like "*Touch") {
            &$registryTweak -Path $path -Name "TouchMode_hold" -Value 0 -Type "DWord"
        } elseif ($path -like "*SysEventParameters") {
            &$registryTweak -Path $path -Name "HoldMode" -Value 3 -Type "DWord"
        }
    }
    
    &$registryTweak -Path $hklmPath -Name "DisableEdgeTarget" -Value 1 -Type "DWord"
}
