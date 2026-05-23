# Set UTF-8 encoding
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$pester5Dir = "$PSScriptRoot/../.tmp/Pester5"
if (!(Test-Path $pester5Dir)) {
    Write-Host "Pester 5 is not found locally. Bootstrapping Pester 5.6.1 locally into .tmp/Pester5..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $pester5Dir -Force | Out-Null
    
    $tempZip = "$env:TEMP\pester5.zip"
    if (Test-Path $tempZip) { Remove-Item $tempZip -Force }
    
    try {
        $progressPreference = 'silentlyContinue'
        Invoke-WebRequest -Uri "https://www.powershellgallery.com/api/v2/package/Pester/5.6.1" -OutFile $tempZip -UseBasicParsing
        Expand-Archive -Path $tempZip -DestinationPath $pester5Dir -Force
        Remove-Item $tempZip -Force
        Write-Host "Pester 5 bootstrapped successfully." -ForegroundColor Green
    } catch {
        Write-Error "Failed to bootstrap Pester 5 locally: $_"
        exit 1
    }
}

# Import local Pester 5 module specifically
Write-Host "Importing local Pester 5 module from .tmp/Pester5..." -ForegroundColor Cyan
Import-Module -Name "$pester5Dir/Pester.psd1" -Force -ErrorAction Stop

# Verify Pester 5 is loaded
$pesterVer = (Get-Module -Name Pester).Version
Write-Host "Successfully loaded Pester Version: $pesterVer" -ForegroundColor Green

$canaryFile = (Resolve-Path "$PSScriptRoot/canary.Tests.ps1").Path
$otherFiles = Get-ChildItem -Path $PSScriptRoot -Filter "*.Tests.ps1" | 
    ForEach-Object { $_.FullName } | 
    Where-Object { $_ -ne $canaryFile }

$testFiles = @($canaryFile) + $otherFiles

$config = [PesterConfiguration]::Default
$config.Run.Path = $testFiles
$config.Run.Exit = $true
$config.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration $config
