Describe "Ziptie Lockdown Script Verification" {
    BeforeAll {
        $global:ZiptieTestMode = $true

        # Unconditionally resolve all paths inside BeforeAll for Pester 5 scope sharing
        $helpersPath = "$PSScriptRoot/utils/test-helpers.ps1"
        if (!(Test-Path $helpersPath)) { $helpersPath = "./test/utils/test-helpers.ps1" }
        . $helpersPath

        $mocksPath = "$PSScriptRoot/utils/test-mocks.ps1"
        if (!(Test-Path $mocksPath)) { $mocksPath = "./test/utils/test-mocks.ps1" }
        . $mocksPath

        $scriptsPath = "$PSScriptRoot/../scripts/windows"
        if (!(Test-Path $scriptsPath)) { $scriptsPath = "./scripts/windows" }
        $scriptsDir = (Resolve-Path $scriptsPath).Path

        $utilsPath = "$PSScriptRoot/../scripts/utils"
        if (!(Test-Path $utilsPath)) { $utilsPath = "./scripts/utils" }
        $utilsDir = (Resolve-Path $utilsPath).Path

        $configPath = "$PSScriptRoot/../ziptie.default.config.json"
        if (!(Test-Path $configPath)) { $configPath = "./ziptie.default.config.json" }
        $defaultConfigPath = (Resolve-Path $configPath).Path

        Backup-ZiptieUtilities -utilsDir $utilsDir
    }

    AfterAll {
        Restore-ZiptieUtilities -utilsDir $utilsDir
    }

    Context "Execution Safety & Mock Framework" {
        # Discovery-time fallback to locate target scripts before BeforeAll executes
        $discoveryScriptsDir = $scriptsDir
        if (!$discoveryScriptsDir) {
            $scriptsPath = "$PSScriptRoot/../scripts/windows"
            if (!(Test-Path $scriptsPath)) { $scriptsPath = "./scripts/windows" }
            $discoveryScriptsDir = (Resolve-Path $scriptsPath).Path
        }

        $files = [System.IO.Directory]::GetFiles($discoveryScriptsDir, "*.ps1")
        foreach ($file in $files) {
            $scriptName = Split-Path -Leaf $file
            if ($scriptName -eq "install-local-apps.ps1" -or $scriptName -eq "test-canary.ps1") {
                continue
            }
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($scriptName)
            $scriptObj = [PSCustomObject]@{ FullName = $file; Name = $scriptName; BaseName = $baseName }
            $case = @{ TestScript = $scriptObj; BaseName = $baseName }

            It "Should run <BaseName> in Dry-Run Mode successfully" -TestCases @($case) {
                param($TestScript)
                try {
                    $mockConfig = Get-Content -Raw -Path $defaultConfigPath | ConvertFrom-Json
                    . $TestScript.FullName -Config $mockConfig -DryRun
                } catch {
                    $global:Error.Clear()
                    throw "Dry-run script $($TestScript.Name) failed: $_"
                }
            }

            It "Should run <BaseName> in Full Mock Active Mode successfully" -TestCases @($case) {
                param($TestScript)
                try {
                    $mockConfig = Get-Content -Raw -Path $defaultConfigPath | ConvertFrom-Json
                    . $TestScript.FullName -Config $mockConfig
                } catch {
                    $global:Error.Clear()
                    throw "Lockdown script $($TestScript.Name) failed: $_"
                }
            }

            It "Should run <BaseName> in Undo Mode successfully" -TestCases @($case) {
                param($TestScript)
                try {
                    $mockConfig = Get-Content -Raw -Path $defaultConfigPath | ConvertFrom-Json
                    . $TestScript.FullName -Config $mockConfig -Undo
                } catch {
                    $global:Error.Clear()
                    throw "Undo script $($TestScript.Name) failed: $_"
                }
            }

            It "Should run <BaseName> with tweaks disabled in config successfully" -TestCases @($case) {
                param($TestScript)
                try {
                    $mockConfig = Get-Content -Raw -Path $defaultConfigPath | ConvertFrom-Json
                    if ($mockConfig.lockdown) {
                        foreach ($prop in $mockConfig.lockdown.PSObject.Properties) {
                            if ($prop.Value -eq $true) { $prop.Value = $false }
                        }
                    }
                    if ($mockConfig.startupTask) { $mockConfig.startupTask.enabled = $false }
                    if ($mockConfig.system) { $mockConfig.system.enableDailyReboot = $false }

                    . $TestScript.FullName -Config $mockConfig
                } catch {
                    $global:Error.Clear()
                    throw "Disabled config script $($TestScript.Name) failed: $_"
                }
            }
        }
    }
}
