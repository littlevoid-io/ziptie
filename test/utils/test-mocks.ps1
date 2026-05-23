# Dummy functions so Pester can mock them even if they are not installed on the host PC
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) { function choco { } }
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { function winget { } }

# Pre-define dummy scheduled task functions to bypass real cmdlets and their strict parameter type constraints
function Register-ScheduledTask { param($TaskName, $TaskPath, $Action, $Trigger, $Settings, [switch]$Force) }
function Unregister-ScheduledTask { param($TaskName, $TaskPath, [switch]$Confirm) }
function Get-ScheduledTask { param($TaskName, $TaskPath) }
function New-ScheduledTaskAction { param($Execute, $Argument, $WorkingDirectory) }
function New-ScheduledTaskTrigger { param([switch]$AtLogon, [switch]$AtStartup, [switch]$Daily, $At) }
function New-ScheduledTaskSettingsSet { param([switch]$AllowStartIfOnBatteries, [switch]$DontStopIfGoingOnBatteries) }

# Pure in-memory system mocks to prevent host environment pollution
Mock Test-Path { return $false } -ParameterFilter { $Path -like "*DefaultUser*" }
Mock Test-Path { return $true } -ParameterFilter { $Path -like "*AppEvents*" -or $Path -like "*StuckRects3*" -or $Path -like "*bloatware-list.json" }

Mock Get-ChildItem {
    return @(
        [PSCustomObject]@{ PSChildName = ".Current"; PSPath = "Microsoft.PowerShell.Core\Registry::HKEY_CURRENT_USER\AppEvents\Schemes\Apps\.Default\.Default\.Current" },
        [PSCustomObject]@{ PSChildName = ".Current"; PSPath = "Microsoft.PowerShell.Core\Registry::HKEY_CURRENT_USER\AppEvents\Schemes\Apps\.Default\AppGPFault\.Current" }
    )
} -ParameterFilter { $Path -like "*AppEvents*" }

Mock Get-Item {
    param($Path)
    $mockKey = [PSCustomObject]@{ }
    $mockKey | Add-Member -MemberType ScriptMethod -Name GetValue -Value { param($name) return "" } -Force
    return $mockKey
} -ParameterFilter { $Path -like "*AppEvents*" }

Mock Get-ItemProperty { return @{ Value = 0 } } -ParameterFilter { $Path -like "*Registry::*" -or $Path -like "*HKCU:*" -or $Path -like "*HKLM:*" -or $Path -like "*Software*" -or $Path -like "*Control Panel*" }

Mock New-Item { return $null }
Mock Set-ItemProperty { }
Mock Remove-ItemProperty { }
Mock Remove-Item { }

# Mock Scheduled Tasks action, trigger, settings, registry and queries
Mock New-ScheduledTaskAction {
    param($Execute, $Argument, $WorkingDirectory)
    return [PSCustomObject]@{ Execute = $Execute; Arguments = $Argument; WorkingDirectory = $WorkingDirectory }
}
Mock New-ScheduledTaskTrigger {
    param([switch]$AtLogon, [switch]$AtStartup, [switch]$Daily, $At)
    return [PSCustomObject]@{ AtLogon = $AtLogon; AtStartup = $AtStartup; Daily = $Daily; At = $At; Delay = $null }
}
Mock New-ScheduledTaskSettingsSet { return [PSCustomObject]@{ } }

$global:lastExecutedAction = $null
Mock Register-ScheduledTask {
    param($TaskName, $TaskPath, $Action, $Trigger, $Settings, $Force)
    if ($TaskName -eq "Launch Exhibit") { $global:lastExecutedAction = $Action }
    return [PSCustomObject]@{ }
}
Mock Unregister-ScheduledTask { }
Mock Get-ScheduledTask { return $null }
Mock Rename-Computer { }

# Mock process launchers, network tools, computer info & utilities
Mock Start-Process { return [PSCustomObject]@{ HasExited = $true } }
Mock Set-NetFirewallProfile { }
Mock Get-ComputerInfo { return [PSCustomObject]@{ OsName = "Microsoft Windows 11 Pro" } }
Mock powercfg {
    param($a1, $a2, $a3, $a4, $a5)
    $argString = "$a1 $a2 $a3 $a4 $a5"
    if ($argString -like "*/list*" -or $argString -like "*/getactivescheme*") {
        return "Power Scheme GUID: 381b4222-f694-41f0-9685-ff5bb260df2e  (Balanced)"
    }
    return ""
}
Mock tzutil { }
Mock w32tm { }
Mock gpupdate { }
Mock winget { }
Mock choco { }
Mock Write-Host { }
Mock Write-Warning { }
