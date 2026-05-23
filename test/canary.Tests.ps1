Describe "Ziptie Canary Mock Verification" {
    BeforeAll {
        $canaryScript = Resolve-Path "$PSScriptRoot/../scripts/windows/test-canary.ps1"
        $canaryFile = Resolve-Path "$PSScriptRoot/../.tmp/canary-file.txt" -ErrorAction SilentlyContinue
        
        # Ensure any pre-existing canary file is cleaned up first
        if ($canaryFile -and (Test-Path $canaryFile)) {
            Remove-Item $canaryFile -Force
        }
    }

    Context "Canary Mock Execution" {
        BeforeEach {
            # Mock the New-Item cmdlet inside the local test scope
            Mock New-Item {
                Write-Host "[MOCK] Intercepted New-Item call safely in-memory!"
            }
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
