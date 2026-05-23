Describe "Ziptie Bootstrap Loader" {
    BeforeAll {
        $bootstrapScript = "$PSScriptRoot/../scripts/bootstrap.ps1"
        $global:repoRoot = (Resolve-Path "$PSScriptRoot/..").Path
    }
    AfterAll {
        $global:repoRoot = $null
    }

    Context "Path Resolution & Safeguards" {
        It "Should resolve to user Downloads when running in a protected directory" {
            Mock Test-Path {
                param($Path)
                # Mock package.json / tsconfig.json dev check to return true to trigger safeguard fallback
                if ($Path -like "*package.json" -or $Path -like "*tsconfig.json") { return $true }
                if ($Path -like "$global:repoRoot*") { return $true }
                if ($Path -like "*ziptie.exe" -or $Path -like "*dist\ziptie.exe" -or $Path -like "*setup.bat") { return $false }
                return $false
            }
            Mock New-Item { }
            Mock Set-Location { }
            Mock Invoke-WebRequest { }
            Mock Expand-Archive { }
            Mock Remove-Item { }
            Mock Write-Error { }

            # Run in protected Windows folder
            . $bootstrapScript -Local -InstallDir "C:\Windows\System32\ziptie" -SkipElevation

            # Assert fallback to Downloads folder
            Assert-MockCalled New-Item -Times 1 -ParameterFilter {
                $Path -like "*Downloads\ziptie*"
            }
        }
    }

    Context "Local Simulator Flow" {
        It "Should recursively copy files from local repo when Local flag is set" {
            Mock Test-Path {
                param($Path)
                # Fail dev workspace check to preserve custom InstallDir
                if ($Path -like "*package.json" -or $Path -like "*tsconfig.json") { return $false }
                if ($Path -like "$global:repoRoot*") { return $true }
                if ($Path -like "*ziptie.exe" -or $Path -like "*dist\ziptie.exe" -or $Path -like "*setup.bat") { return $false }
                return $true
            }
            Mock New-Item { }
            Mock Set-Location { }
            Mock Remove-Item { }
            Mock Copy-Item { } -Verifiable
            Mock Write-Error { }

            # Execute with SkipElevation to bypass UAC prompts
            . $bootstrapScript -Local -InstallDir "C:\mock-ziptie-install" -SkipElevation

            # Assert that Copy-Item was invoked to copy the package assets to custom InstallDir
            Assert-MockCalled Copy-Item -Times 5 -ParameterFilter {
                $Destination -eq "C:\mock-ziptie-install"
            }
        }
    }

    Context "Remote Release Downloader Flow" {
        It "Should download the zip release and unpack it when Local flag is not set" {
            Mock Test-Path {
                param($Path)
                # Force local repository checks to fail to trigger remote download flow
                if ($Path -like "*ziptie.schema.json" -or $Path -like "*package.json" -or $Path -like "*tsconfig.json") { return $false }
                if ($Path -like "$global:repoRoot*") { return $true }
                if ($Path -like "*ziptie.exe" -or $Path -like "*dist\ziptie.exe" -or $Path -like "*setup.bat") { return $false }
                return $true
            }
            Mock New-Item { }
            Mock Set-Location { }
            Mock Remove-Item { }
            Mock Copy-Item { }
            Mock Invoke-WebRequest { } -Verifiable
            Mock Expand-Archive { } -Verifiable
            Mock Write-Error { }

            # Run remote downloader test with SkipElevation active
            . $bootstrapScript -InstallDir "C:\mock-ziptie-remote" -SkipElevation

            # Assert that the installer queried GitHub and extracted the archive to target
            Assert-MockCalled Invoke-WebRequest -Times 1 -ParameterFilter {
                $Uri -eq "https://github.com/littlevoid-io/ziptie/releases/latest/download/ziptie.zip"
            }
            Assert-MockCalled Expand-Archive -Times 1 -ParameterFilter {
                $DestinationPath -eq "C:\mock-ziptie-remote"
            }
        }
    }

    Context "Caller Directory Configuration Detection" {
        It "Should pass the config file path via CLI argument if present in the caller directory" {
            Mock Test-Path {
                param($Path)
                if ($Path -like "*ziptie.config.json") { return $true }
                if ($Path -like "$global:repoRoot*") { return $true }
                if ($Path -like "*ziptie.exe" -or $Path -like "*dist\ziptie.exe" -or $Path -like "*setup.bat") { return $false }
                return $false
            }
            Mock New-Item { }
            Mock Set-Location { }
            Mock Remove-Item { }
            Mock Copy-Item { }
            Mock Invoke-WebRequest { }
            Mock Expand-Archive { }
            Mock Write-Error { }

            . $bootstrapScript -InstallDir "C:\mock-target" -SkipElevation

            if (($argArray -contains "-c") -ne $true) { throw "Expected argArray to contain -c" }
            $expectedPath = Join-Path $PWD.Path "ziptie.config.json"
            if (($argArray -contains $expectedPath) -ne $true) { throw "Expected argArray to contain caller config path: $expectedPath" }
        }
    }

    Context "TEMP Directory Resolution & CWD Preservation" {
        It "Should resolve to system TEMP folder when InstallDir is not provided" {
            Mock Test-Path {
                param($Path)
                if ($Path -like "*package.json" -or $Path -like "*tsconfig.json") { return $false }
                if ($Path -like "$global:repoRoot*") { return $true }
                if ($Path -like "*ziptie.exe" -or $Path -like "*dist\ziptie.exe" -or $Path -like "*setup.bat") { return $false }
                return $false
            }
            Mock New-Item { }
            Mock Set-Location { } -Verifiable
            Mock Invoke-WebRequest { }
            Mock Expand-Archive { }
            Mock Remove-Item { }
            Mock Write-Error { }

            . $bootstrapScript -SkipElevation

            $expectedTempPath = Join-Path $env:TEMP "ziptie"
            Assert-MockCalled New-Item -Times 1 -ParameterFilter {
                [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/') -eq [System.IO.Path]::GetFullPath($expectedTempPath).TrimEnd('\', '/')
            }
            Assert-MockCalled Set-Location -Times 2 -ParameterFilter {
                [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/') -eq [System.IO.Path]::GetFullPath($PWD.Path).TrimEnd('\', '/')
            }
        }
    }
}

