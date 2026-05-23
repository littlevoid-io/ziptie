# Dummy functions so Pester 3.4.0 can mock them even if they are not installed on the host PC
function choco { }
function winget { }

# Pure in-memory system mocks to prevent host environment pollution
Mock Test-Path {
    param($Path)
    if ($Path -like "*DefaultUser*") { return $false }
    if ($Path -like "*AppEvents*") { return $true }
    if ($Path -like "*StuckRects3*") { return $true }
    if ($Path -like "*bloatware-list.json") { return $true }
    if ($Path -and ([System.IO.File]::Exists($Path) -or [System.IO.Directory]::Exists($Path))) { return $true }
    return $false
}

Mock Get-ChildItem {
    param($Path, $Filter, $Recurse)
    if ($Path -like "*AppEvents*") {
        return @(
            [PSCustomObject]@{ PSChildName = ".Current"; PSPath = "Microsoft.PowerShell.Core\Registry::HKEY_CURRENT_USER\AppEvents\Schemes\Apps\.Default\.Default\.Current" },
            [PSCustomObject]@{ PSChildName = ".Current"; PSPath = "Microsoft.PowerShell.Core\Registry::HKEY_CURRENT_USER\AppEvents\Schemes\Apps\.Default\AppGPFault\.Current" }
        )
    }
    return @()
}

Mock Get-Item {
    param($Path)
    $mockKey = [PSCustomObject]@{ }
    $mockKey | Add-Member -MemberType ScriptMethod -Name GetValue -Value { param($name) return "" } -Force
    return $mockKey
}

Mock New-Item { return $null }
Mock Set-ItemProperty { }
Mock Remove-ItemProperty { }
Mock Get-ItemProperty { return @{ Value = 0 } }
Mock Remove-Item { }

# Mock Scheduled Tasks
$global:lastExecutedAction = $null
Mock Register-ScheduledTask {
    param($TaskName, $TaskPath, $Action, $Trigger, $Settings, $Force)
    if ($TaskName -eq "Launch Exhibit") { $global:lastExecutedAction = $Action }
    return [PSCustomObject]@{ }
}
Mock Unregister-ScheduledTask { }
Mock Get-ScheduledTask { return $null }
Mock Rename-Computer { }

# Mock process launchers & network tools
Mock Start-Process { return [PSCustomObject]@{ HasExited = $true } }
Mock Set-NetFirewallProfile { }

# Mock WMI/Computer info
Mock Get-ComputerInfo { return [PSCustomObject]@{ OsName = "Microsoft Windows 11 Pro" } }

# Mock powercfg
Mock powercfg {
    param($a1, $a2, $a3, $a4, $a5)
    $argString = "$a1 $a2 $a3 $a4 $a5"
    if ($argString -like "*/list*" -or $argString -like "*/getactivescheme*") {
        return "Power Scheme GUID: 381b4222-f694-41f0-9685-ff5bb260df2e  (Balanced)"
    }
    return ""
}

# Mock external tools and utility execution
Mock tzutil { }
Mock w32tm { }
Mock gpupdate { }
Mock winget { }
Mock choco { }
Mock Write-Host { }
Mock Write-Warning { }
