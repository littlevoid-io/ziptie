Describe "Ziptie Canary Mock Verification" {
    $canaryScript = Resolve-Path "$PSScriptRoot/../scripts/windows/test-canary.ps1"

    BeforeAll {
        $canaryFile = "$PSScriptRoot/../.tmp/canary-file.txt"
        
        # Ensure any pre-existing canary file is cleaned up first
        if (Test-Path $canaryFile) {
            Remove-Item $canaryFile -Force
        }
    }

    Context "Canary Mock Execution" {
        Mock New-Item {
            Write-Host "[MOCK] Intercepted New-Item call safely in-memory!"
        }

        It "Should mock the New-Item cmdlet and NOT create the physical file on the host" {
            # Run the canary script (without -DryRun)
            . $canaryScript
            
            # Assert Pester intercepted the call
            Assert-MockCalled New-Item -Times 1
            
            # Assert that the file does NOT exist on the host PC
            $canaryFileExists = Test-Path "$PSScriptRoot/../.tmp/canary-file.txt"
            $canaryFileExists | Should Be $false
        }
    }
}
