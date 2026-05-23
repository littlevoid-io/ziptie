# Set UTF-8 encoding
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Detect major Pester version
$pesterModule = Get-Module -Name Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
$pesterVersion = if ($pesterModule) { $pesterModule.Version.Major } else { 3 }

Write-Host "Detected Pester Version: $pesterVersion" -ForegroundColor Cyan

$testFiles = @(
    (Resolve-Path "$PSScriptRoot/canary.Tests.ps1").Path,
    (Resolve-Path "$PSScriptRoot/bootstrap.Tests.ps1").Path,
    (Resolve-Path "$PSScriptRoot/scripts.Tests.ps1").Path
)

if ($pesterVersion -ge 5) {
    # Modern Pester 5 execution (avoiding legacy parameters and scoping issues)
    $config = [PesterConfiguration]::Default
    $config.Run.Path = $testFiles
    $config.Run.Exit = $true
    $config.Output.Verbosity = 'Detailed'
    Invoke-Pester -Configuration $config
} else {
    # Legacy Pester 3/4 execution
    Invoke-Pester -Path $testFiles -EnableExit
}
