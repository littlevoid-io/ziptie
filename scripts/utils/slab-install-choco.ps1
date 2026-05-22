Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Resolve ChocolateyInstall path robustly
if (!$env:ChocolateyInstall) {
    $env:ChocolateyInstall = [System.Environment]::GetEnvironmentVariable("ChocolateyInstall", "Machine")
}
if (!$env:ChocolateyInstall) {
    $env:ChocolateyInstall = [System.Environment]::GetEnvironmentVariable("ChocolateyInstall", "User")
}
if (!$env:ChocolateyInstall) {
    $env:ChocolateyInstall = "$env:SystemDrive\ProgramData\chocolatey"
}

# Explicitly add bin to PATH of this running session immediately
$binPath = "$env:ChocolateyInstall\bin"
if (Test-Path $binPath) {
    if ($env:PATH -notlike "*$binPath*") {
        $env:PATH = "$env:PATH;$binPath"
    }
}

# Import Chocolatey profile module for the parent/active session
$profilePath = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path $profilePath) {
    Import-Module $profilePath -Force -ErrorAction SilentlyContinue
}

# Run refreshenv to update other variables if available
if (Get-Command "refreshenv" -ErrorAction SilentlyContinue) {
    refreshenv
}