[CmdletBinding()]
Param(
    [Switch]$DryRun
)

Write-Host "Post-install: Refreshing environment to configure NVM..." -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "[DRY-RUN] Would fetch environment variables, run nvm install lts, and nvm use lts" -ForegroundColor Yellow
    return
}

# Dynamically extract NVM_HOME and NVM_SYMLINK from registry if not already populated
$nvmHome = [System.Environment]::GetEnvironmentVariable("NVM_HOME", "User")
if (!$nvmHome) { $nvmHome = [System.Environment]::GetEnvironmentVariable("NVM_HOME", "Machine") }
$nvmSymlink = [System.Environment]::GetEnvironmentVariable("NVM_SYMLINK", "User")
if (!$nvmSymlink) { $nvmSymlink = [System.Environment]::GetEnvironmentVariable("NVM_SYMLINK", "Machine") }

if ($nvmHome) { $env:NVM_HOME = $nvmHome }
if ($nvmSymlink) { $env:NVM_SYMLINK = $nvmSymlink }

# Force reload PATH variables from machine and user registry hives to bypass session-level lag
$machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
$userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
$env:PATH = "$machinePath;$userPath"

# Resolve the NVM command path
$nvmCmd = Get-Command "nvm" -ErrorAction SilentlyContinue
if ($null -eq $nvmCmd -and $env:NVM_HOME -and (Test-Path "$env:NVM_HOME\nvm.exe")) {
    $nvmCmd = "$env:NVM_HOME\nvm.exe"
}

if ($nvmCmd) {
    Write-Host "NVM resolved at '$nvmCmd'. Installing Node.js LTS..." -ForegroundColor Cyan
    & $nvmCmd install lts
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null) {
        Write-Host "Activating Node.js LTS version..." -ForegroundColor Cyan
        & $nvmCmd use lts
        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null) {
            Write-Host "Successfully installed and configured Node.js LTS version via NVM." -ForegroundColor Green
        } else {
            Write-Warning "Failed to activate LTS version using NVM."
        }
    } else {
        Write-Warning "Failed to install LTS version using NVM."
    }
} else {
    Write-Warning "NVM command or executable could not be resolved. Please verify NVM installation."
}
