$scriptsPath = "$PSScriptRoot/../scripts/windows"
if (!(Test-Path $scriptsPath)) { $scriptsPath = "./scripts/windows" }
$resolvedPath = (Resolve-Path "$scriptsPath/enable-startup-task.ps1").Path

$configPath = "$PSScriptRoot/../ziptie.default.config.json"
if (!(Test-Path $configPath)) { $configPath = "./ziptie.default.config.json" }
$defaultConfigPath = (Resolve-Path $configPath).Path

Describe "Ziptie Startup Task Parameter Splitting" {
    BeforeAll {
        Mock Test-Path { return $true }
        Mock New-Item { return $null }
        Mock Write-Host { }
        Mock Write-Warning { }
        Mock Unregister-ScheduledTask { }
        Mock Get-ScheduledTask { return $null }
        
        $global:lastExecutedAction = $null
        Mock Register-ScheduledTask {
            param($TaskName, $TaskPath, $Action, $Trigger, $Settings, $Force)
            if ($TaskName -eq "Launch Exhibit") {
                $global:lastExecutedAction = $Action
            }
            return [PSCustomObject]@{ }
        }
    }

    Context "Startup Task Args Splitting Logic" {
        It "Should split executable into command and arguments if args is empty" {
            $mockConfig = Get-Content -Raw -Path $defaultConfigPath | ConvertFrom-Json
            $mockConfig.startupTask.enabled = $true
            $mockConfig.startupTask.executable = "node index.js --port 80"
            $mockConfig.startupTask.args = @()

            $global:lastExecutedAction = $null
            & $resolvedPath -Config $mockConfig

            if ($global:lastExecutedAction.Execute -ne "node") {
                throw "Expected Execute to be 'node', but got '$($global:lastExecutedAction.Execute)'"
            }
            if ($global:lastExecutedAction.Arguments -ne "index.js --port 80") {
                throw "Expected Arguments to be 'index.js --port 80', but got '$($global:lastExecutedAction.Arguments)'"
            }
        }

        It "Should use explicit args and treat executable literally if args is provided" {
            $mockConfig = Get-Content -Raw -Path $defaultConfigPath | ConvertFrom-Json
            $mockConfig.startupTask.enabled = $true
            $mockConfig.startupTask.executable = "C:\Path With Spaces\node.exe"
            $mockConfig.startupTask.args = @("index.js", "--port", "80")

            $global:lastExecutedAction = $null
            & $resolvedPath -Config $mockConfig

            if ($global:lastExecutedAction.Execute -ne "C:\Path With Spaces\node.exe") {
                throw "Expected Execute to be 'C:\Path With Spaces\node.exe', but got '$($global:lastExecutedAction.Execute)'"
            }
            if ($global:lastExecutedAction.Arguments -ne "index.js --port 80") {
                throw "Expected Arguments to be 'index.js --port 80', but got '$($global:lastExecutedAction.Arguments)'"
            }
        }

        It "Should handle null args correctly by falling back to regex splitting" {
            $mockConfig = Get-Content -Raw -Path $defaultConfigPath | ConvertFrom-Json
            $mockConfig.startupTask.enabled = $true
            $mockConfig.startupTask.executable = "node index.js"
            $mockConfig.startupTask.args = $null

            $global:lastExecutedAction = $null
            & $resolvedPath -Config $mockConfig

            if ($global:lastExecutedAction.Execute -ne "node") {
                throw "Expected Execute to be 'node', but got '$($global:lastExecutedAction.Execute)'"
            }
            if ($global:lastExecutedAction.Arguments -ne "index.js") {
                throw "Expected Arguments to be 'index.js', but got '$($global:lastExecutedAction.Arguments)'"
            }
        }
    }
}
