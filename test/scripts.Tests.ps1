# Dummy functions so Pester 3.4.0 can mock them even if they are not installed on the host PC
function choco { }
function winget { }

Describe "Ziptie Lockdown Script Verification" {
    BeforeAll {
        $scriptsDir = Resolve-Path "$PSScriptRoot/../scripts/windows"
        $utilsDir = Resolve-Path "$PSScriptRoot/../scripts/utils"
        
        # Safe template configuration representing standard default values
        $defaultConfigPath = Resolve-Path "$PSScriptRoot/../ziptie.default.config.json"
        if (!(Test-Path $defaultConfigPath)) {
            throw "Error: Production config not found at $defaultConfigPath"
        }
        $mockConfig = Get-Content -Raw -Path $defaultConfigPath | ConvertFrom-Json

        # Compile the Win32 P/Invoke type in BeforeAll so it is safely defined once in the AppDomain,
        # preventing any duplicate compilation compiler errors during repetitive test runs.
        if (-not ("ZiptieWin32.Win32SystemParametersInfoBackground" -as [type])) {
            $sig = '[DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);'
            Add-Type -MemberDefinition $sig -Name "Win32SystemParametersInfoBackground" -Namespace "ZiptieWin32" -ErrorAction SilentlyContinue | Out-Null
        }

        # =====================================================================
        # AIRTIGHT UTILITY STUBBING FRAMEWORK
        # Back up original utility scripts and replace them with benign stubs 
        # to ensure call operator ( & ) executions are 100% safely intercepted.
        # =====================================================================
        $backupDir = Resolve-Path "$PSScriptRoot/../.tmp" -ErrorAction SilentlyContinue
        if (!$backupDir) {
            $backupDir = New-Item -ItemType Directory -Path "$PSScriptRoot/../.tmp" -Force | Out-Null
            $backupDir = Resolve-Path "$PSScriptRoot/../.tmp"
        }
        $utilsBackupPath = "$backupDir/utils-backup"
        if (!(Test-Path $utilsBackupPath)) {
            New-Item -ItemType Directory -Path $utilsBackupPath -Force | Out-Null
        }

        $utils = Get-ChildItem -Path $utilsDir -Filter "*.ps1"
        foreach ($u in $utils) {
            # Backup original utility file
            Copy-Item -Path $u.FullName -Destination $utilsBackupPath -Force
            
            # Replace utility with a benign silent stub, except ziptie-init.ps1 which sets up our scriptblocks.
            if ($u.Name -ne "ziptie-init.ps1") {
                Set-Content -Path $u.FullName -Value "Param([Switch]`$DryRun)"
            }
        }
    }

    AfterAll {
        # =====================================================================
        # RESTORE UTILITY SCRIPTS
        # Restore all original utility scripts from the backup to keep workspace clean.
        # =====================================================================
        $utilsBackupPath = "$PSScriptRoot/../.tmp/utils-backup"
        $utilsDir = Resolve-Path "$PSScriptRoot/../scripts/utils" -ErrorAction SilentlyContinue
        
        if ($utilsDir -and (Test-Path $utilsBackupPath)) {
            $backupFiles = Get-ChildItem -Path $utilsBackupPath -Filter "*.ps1"
            foreach ($bf in $backupFiles) {
                Copy-Item -Path $bf.FullName -Destination $utilsDir -Force
            }
            Remove-Item $utilsBackupPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context "Static Analysis & Architecture Guidelines" {
        It "Should strictly cap every script under 100 lines of code" {
            $scripts = Get-ChildItem -Path $scriptsDir -Filter "*.ps1" -Recurse
            $utilsDir = Resolve-Path "$PSScriptRoot/../scripts/utils"
            $utils = Get-ChildItem -Path $utilsDir -Filter "*.ps1"
            
            foreach ($script in ($scripts + $utils)) {
                $lines = Get-Content -Path $script.FullName
                $lines.Count | Should BeLessThan 100
            }
        }

        It "Should not contain hardcoded plain-text passwords or secrets" {
            $scripts = Get-ChildItem -Path $scriptsDir -Filter "*.ps1" -Recurse
            $utilsDir = Resolve-Path "$PSScriptRoot/../scripts/utils"
            $utils = Get-ChildItem -Path $utilsDir -Filter "*.ps1"
            
            foreach ($script in ($scripts + $utils)) {
                $content = Get-Content -Raw -Path $script.FullName
                $content | Should Not Match "password\s*=\s*'[^']+'"
                $content | Should Not Match 'password\s*=\s*"[^"]+"'
            }
        }
    }

    Context "Execution Safety & Mock Framework" {
        BeforeEach {
            # =================================================================
            # RECURSION-PROOF IN-MEMORY SYSTEM MOCKS
            # Overriding cmdlets with pure .NET methods and stubs completely
            # bypasses command lookup, preventing Pester call depth recursion.
            # =================================================================
            
            Mock Test-Path {
                param($Path)
                if ($Path -like "*DefaultUser*") { return $false }
                if ($Path -like "*AppEvents*") { return $true }
                if ($Path -like "*StuckRects3*") { return $true }
                if ($Path -like "*bloatware-list.json") { return $true }
                
                # Pure .NET file checking: avoids calling Test-Path itself (preventing infinite recursion)
                if ($Path -and ([System.IO.File]::Exists($Path) -or [System.IO.Directory]::Exists($Path))) {
                    return $true
                }
                return $false
            }
            
            Mock Get-ChildItem {
                param($Path, $Filter, $Recurse)
                # Safely simulate registry sound schemes to keep disable-system-sounds silent and isolated
                if ($Path -like "*AppEvents*") {
                    return @(
                        [PSCustomObject]@{
                            PSChildName = ".Current"
                            PSPath = "Microsoft.PowerShell.Core\Registry::HKEY_CURRENT_USER\AppEvents\Schemes\Apps\.Default\.Default\.Current"
                        },
                        [PSCustomObject]@{
                            PSChildName = ".Current"
                            PSPath = "Microsoft.PowerShell.Core\Registry::HKEY_CURRENT_USER\AppEvents\Schemes\Apps\.Default\AppGPFault\.Current"
                        }
                    )
                }
                return @()
            }
            
            Mock Get-Item {
                param($Path)
                # Return a custom object with a real ScriptMethod to support native .GetValue() method calls
                $mockKey = [PSCustomObject]@{ }
                $mockKey | Add-Member -MemberType ScriptMethod -Name GetValue -Value {
                    param($name)
                    return ""
                } -Force
                return $mockKey
            }

            Mock New-Item { return $null }
            Mock Set-ItemProperty { }
            Mock Remove-ItemProperty { }
            Mock Get-ItemProperty { return @{ Value = 0 } }
            Mock Remove-Item { }
            
            # Mock Scheduled Tasks (only modifying commands)
            Mock Register-ScheduledTask { return [PSCustomObject]@{ } }
            Mock Unregister-ScheduledTask { }
            Mock Get-ScheduledTask { return $null }
            Mock Rename-Computer { }
            
            # Mock process launchers & network tools
            Mock Start-Process { return [PSCustomObject]@{ HasExited = $true } }
            Mock Set-NetFirewallProfile { }
            
            # Mock WMI/Computer info
            Mock Get-ComputerInfo {
                return [PSCustomObject]@{
                    OsName = "Microsoft Windows 11 Pro"
                }
            }
            
            # Mock powercfg with realistic return formats
            Mock powercfg {
                param($a1, $a2, $a3, $a4, $a5)
                $argString = "$a1 $a2 $a3 $a4 $a5"
                if ($argString -like "*/list*") {
                    return "Power Scheme GUID: 381b4222-f694-41f0-9685-ff5bb260df2e  (Balanced)"
                }
                if ($argString -like "*/getactivescheme*") {
                    return "Power Scheme GUID: 381b4222-f694-41f0-9685-ff5bb260df2e  (Balanced)"
                }
                return ""
            }
            
            # Mock external tools
            Mock tzutil { }
            Mock w32tm { }
            Mock gpupdate { }
            Mock winget { }
            Mock choco { }

            # Silence progress/warning console printing to prevent user confusion and clean up stdout
            Mock Write-Host { }
            Mock Write-Warning { }
        }

        function New-LockdownTest {
            param($TestScript)

            $configPath = (Resolve-Path "$PSScriptRoot/../ziptie.default.config.json").Path

            It "Should run $($TestScript.BaseName) in Dry-Run Mode successfully" {
                try {
                    $mockConfig = Get-Content -Raw -Path $configPath | ConvertFrom-Json
                    . $TestScript.FullName -Config $mockConfig -DryRun
                } catch {
                    $global:Error.Clear()
                    throw "Dry-run script $($TestScript.Name) failed with exception: $_"
                }
            }

            It "Should run $($TestScript.BaseName) in Full Mock Active Mode successfully" {
                try {
                    $mockConfig = Get-Content -Raw -Path $configPath | ConvertFrom-Json
                    . $TestScript.FullName -Config $mockConfig
                } catch {
                    $global:Error.Clear()
                    throw "Lockdown script $($TestScript.Name) failed with exception: $_"
                }
            }

            It "Should run $($TestScript.BaseName) in Undo Mode successfully" {
                try {
                    $mockConfig = Get-Content -Raw -Path $configPath | ConvertFrom-Json
                    . $TestScript.FullName -Config $mockConfig -Undo
                } catch {
                    $global:Error.Clear()
                    throw "Undo script $($TestScript.Name) failed with exception: $_"
                }
            }

            It "Should run $($TestScript.BaseName) with tweaks disabled in config successfully" {
                try {
                    $mockConfig = Get-Content -Raw -Path $configPath | ConvertFrom-Json
                    
                    # Programmatically toggle all boolean config options to false
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
                    throw "Disabled config script $($TestScript.Name) failed with exception: $_"
                }
            }
        }

        $scripts = Get-ChildItem -Path $scriptsDir -Filter "*.ps1"
        foreach ($script in $scripts) {
            # Skip helper/installer/test scripts to test in dedicated blocks
            if ($script.Name -eq "install-local-apps.ps1" -or $script.Name -eq "test-canary.ps1") {
                continue
            }
            New-LockdownTest -TestScript $script
        }
    }
}
