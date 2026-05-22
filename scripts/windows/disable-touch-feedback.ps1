[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.disableTouchFeedback
$shouldUndo = $Undo -or !$tweakEnabled

$registryTweak = {
    Param([String]$Path, [String]$Name, [Object]$Value, [String]$Type, [Switch]$Remove, [Switch]$DryRun)
    & "$PSScriptRoot/../../src/powershell/utils/slab-set-registry.ps1" -Path $Path -Name $Name -Value $Value -PropertyType $Type -Remove:$Remove -DryRun:$DryRun
}

$hkcuPaths = @("HKCU:\Control Panel\Cursors", "HKCU:\Software\Microsoft\Wisp\Touch", "HKCU:\Software\Microsoft\Wisp\Pen\SysEventParameters")
if (Test-Path "HKU:\DefaultUser") {
    $hkcuPaths += "HKU:\DefaultUser\Control Panel\Cursors"
    $hkcuPaths += "HKU:\DefaultUser\Software\Microsoft\Wisp\Touch"
    $hkcuPaths += "HKU:\DefaultUser\Software\Microsoft\Wisp\Pen\SysEventParameters"
}
$hklmPath = "HKLM:\SOFTWARE\Policies\Microsoft\TabletTip\1.7"

if ($shouldUndo) {
    Write-Host "Restoring default touch and pen feedback..." -ForegroundColor Cyan
    
    foreach ($path in $hkcuPaths) {
        if ($path -like "*Cursors") {
            &$registryTweak -Path $path -Name "ContactVisualization" -Value 1 -Type "DWord" -DryRun:$DryRun
            &$registryTweak -Path $path -Name "GestureVisualization" -Value 31 -Type "DWord" -DryRun:$DryRun
        } elseif ($path -like "*Touch") {
            &$registryTweak -Path $path -Name "TouchMode_hold" -Value 1 -Type "DWord" -DryRun:$DryRun
        } elseif ($path -like "*SysEventParameters") {
            &$registryTweak -Path $path -Name "HoldMode" -Value 1 -Type "DWord" -DryRun:$DryRun
        }
    }
    
    &$registryTweak -Path $hklmPath -Name "DisableEdgeTarget" -Remove -DryRun:$DryRun
} else {
    Write-Host "Disabling touch and pen visual feedback..." -ForegroundColor Cyan
    
    foreach ($path in $hkcuPaths) {
        if ($path -like "*Cursors") {
            &$registryTweak -Path $path -Name "ContactVisualization" -Value 0 -Type "DWord" -DryRun:$DryRun
            &$registryTweak -Path $path -Name "GestureVisualization" -Value 0 -Type "DWord" -DryRun:$DryRun
        } elseif ($path -like "*Touch") {
            &$registryTweak -Path $path -Name "TouchMode_hold" -Value 0 -Type "DWord" -DryRun:$DryRun
        } elseif ($path -like "*SysEventParameters") {
            &$registryTweak -Path $path -Name "HoldMode" -Value 3 -Type "DWord" -DryRun:$DryRun
        }
    }
    
    &$registryTweak -Path $hklmPath -Name "DisableEdgeTarget" -Value 1 -Type "DWord" -DryRun:$DryRun
}
