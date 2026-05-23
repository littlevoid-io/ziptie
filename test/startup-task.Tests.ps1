# Pre-define dummy scheduled task functions in global scope to bypass real cmdlets and their strict parameter type constraints
function global:Register-ScheduledTask { param($TaskName, $TaskPath, $Action, $Trigger, $Settings, [switch]$Force) }
function global:Unregister-ScheduledTask { param($TaskName, $TaskPath, [switch]$Confirm) }
function global:Get-ScheduledTask { param($TaskName, $TaskPath) }
function global:New-ScheduledTaskAction { param($Execute, $Argument, $WorkingDirectory) }
function global:New-ScheduledTaskTrigger { param([switch]$AtLogon, [switch]$AtStartup, [switch]$Daily, $At) }
function global:New-ScheduledTaskSettingsSet { param([switch]$AllowStartIfOnBatteries, [switch]$DontStopIfGoingOnBatteries) }

function Get-StartupTaskPaths {
    $scriptsPath = "$PSScriptRoot/../scripts/windows"
    if (!(Test-Path $scriptsPath)) { $scriptsPath = "./scripts/windows" }
    $resolvedPath = (Resolve-Path "$scriptsPath/enable-startup-task.ps1").Path

    $configPath = "$PSScriptRoot/../ziptie.default.config.json"
    if (!(Test-Path $configPath)) { $configPath = "./ziptie.default.config.json" }
    $defaultConfigPath = (Resolve-Path $configPath).Path

    return @{ ResolvedPath = $resolvedPath; DefaultConfigPath = $defaultConfigPath }
}

Describe "Ziptie Startup Task Parameter Splitting" {
    BeforeAll {
        Mock Test-Path { return $true }
        Mock New-Item { return $null }
        Mock Write-Host { }
        Mock Write-Warning { }
        Mock Unregister-ScheduledTask { }
        Mock Get-ScheduledTask { return $null }
        
        Mock New-ScheduledTaskAction {
            param($Execute, $Argument, $WorkingDirectory)
            return [PSCustomObject]@{ Execute = $Execute; Arguments = $Argument; WorkingDirectory = $WorkingDirectory }
        }
        Mock New-ScheduledTaskTrigger {
            param([switch]$AtLogon, [switch]$AtStartup)
            return [PSCustomObject]@{ AtLogon = $AtLogon; AtStartup = $AtStartup; Delay = $null }
        }
        Mock New-ScheduledTaskSettingsSet { return [PSCustomObject]@{ } }
        
        $global:lastExecutedAction = $null
        Mock Register-ScheduledTask {
            param($TaskName, $TaskPath, $Action, $Trigger, $Settings, $Force)
            if ($TaskName -eq "Launch Exhibit") { $global:lastExecutedAction = $Action }
            return [PSCustomObject]@{ }
        }
    }

    Context "Startup Task Args Splitting Logic" {
        It "Should split executable into command and arguments if args is empty" {
            $paths = Get-StartupTaskPaths
            $mockConfig = Get-Content -Raw -Path $paths.DefaultConfigPath | ConvertFrom-Json
            $mockConfig.startupTask.enabled = $true
            $mockConfig.startupTask.executable = "node index.js --port 80"
            $mockConfig.startupTask.args = @()

            $global:lastExecutedAction = $null
            & $paths.ResolvedPath -Config $mockConfig

            if ($global:lastExecutedAction.Execute -ne "node") {
                throw "Expected Execute to be 'node', but got '$($global:lastExecutedAction.Execute)'"
            }
            if ($global:lastExecutedAction.Arguments -ne "index.js --port 80") {
                throw "Expected Arguments to be 'index.js --port 80', but got '$($global:lastExecutedAction.Arguments)'"
            }
        }

        It "Should use explicit args and treat executable literally if args is provided" {
            $paths = Get-StartupTaskPaths
            $mockConfig = Get-Content -Raw -Path $paths.DefaultConfigPath | ConvertFrom-Json
            $mockConfig.startupTask.enabled = $true
            $mockConfig.startupTask.executable = "C:\Path With Spaces\node.exe"
            $mockConfig.startupTask.args = @("index.js", "--port", "80")

            $global:lastExecutedAction = $null
            & $paths.ResolvedPath -Config $mockConfig

            if ($global:lastExecutedAction.Execute -ne "C:\Path With Spaces\node.exe") {
                throw "Expected Execute to be 'C:\Path With Spaces\node.exe', but got '$($global:lastExecutedAction.Execute)'"
            }
            if ($global:lastExecutedAction.Arguments -ne "index.js --port 80") {
                throw "Expected Arguments to be 'index.js --port 80', but got '$($global:lastExecutedAction.Arguments)'"
            }
        }

        It "Should handle null args correctly by falling back to regex splitting" {
            $paths = Get-StartupTaskPaths
            $mockConfig = Get-Content -Raw -Path $paths.DefaultConfigPath | ConvertFrom-Json
            $mockConfig.startupTask.enabled = $true
            $mockConfig.startupTask.executable = "node index.js"
            $mockConfig.startupTask.args = $null

            $global:lastExecutedAction = $null
            & $paths.ResolvedPath -Config $mockConfig

            if ($global:lastExecutedAction.Execute -ne "node") {
                throw "Expected Execute to be 'node', but got '$($global:lastExecutedAction.Execute)'"
            }
            if ($global:lastExecutedAction.Arguments -ne "index.js") {
                throw "Expected Arguments to be 'index.js', but got '$($global:lastExecutedAction.Arguments)'"
            }
        }
    }
}
