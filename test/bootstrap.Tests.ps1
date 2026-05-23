Describe "Ziptie Bootstrap Loader" {
    BeforeAll {
        $bootstrapScript = "$PSScriptRoot/../scripts/bootstrap.ps1"
    }

    Context "Path Resolution & Safeguards" {
        It "Should resolve to user Downloads when running in a protected directory" {
            Mock Test-Path {
                param($Path)
                if ($Path -eq "ziptie.exe" -or $Path -eq "dist\ziptie.exe" -or $Path -eq "setup.bat") { return $false }
                # Mock package.json / tsconfig.json dev check to return true to trigger safeguard fallback
                if ($Path -like "*package.json" -or $Path -like "*tsconfig.json") { return $true }
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
                if ($Path -eq "ziptie.exe" -or $Path -eq "dist\ziptie.exe" -or $Path -eq "setup.bat") { return $false }
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
                if ($Path -eq "ziptie.exe" -or $Path -eq "dist\ziptie.exe" -or $Path -eq "setup.bat") { return $false }
                return $true
            }
            Mock New-Item { }
            Mock Set-Location { }
            Mock Remove-Item { }
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
}
