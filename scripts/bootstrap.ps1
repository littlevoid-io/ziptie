param([String]$InstallDir)
$ErrorActionPreference = "Stop"

# 1. Resolve and default the installation directory to CWD if not provided
$targetPath = if ($InstallDir) { $InstallDir } else { $PWD.Path }
$targetPath = [System.IO.Path]::GetFullPath($targetPath)

# Avoid downloading into protected system/Windows directories or system drive root
$systemRoot = [Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)
if ($targetPath -like "$systemRoot*" -or $targetPath -eq "C:\") {
    $targetPath = Join-Path $HOME "Downloads\slab"
}

# 2. Elevate if not admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Slab requires administrative privileges. Elevating..." -ForegroundColor Yellow
    $argsList = "-ExecutionPolicy Bypass -NoProfile -Command `"& { [scriptblock]::Create((irm https://raw.githubusercontent.com/littlevoid-io/slab/main/scripts/bootstrap.ps1)).Invoke(@('$targetPath')) }`""
    Start-Process powershell -ArgumentList $argsList -Verb RunAs
    exit
}

# 3. Download precompiled release
New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
Set-Location -Path $targetPath

Write-Host "Downloading precompiled Slab release to $targetPath..." -ForegroundColor Cyan
$zipUrl = "https://github.com/littlevoid-io/slab/releases/latest/download/slab.zip"
$zipFile = "$env:TEMP\slab-release.zip"

if (Test-Path $zipFile) { Remove-Item $zipFile -Force }
try {
    Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile
} catch {
    Write-Error "Failed to download precompiled release from GitHub. Please ensure a release has been published or check network connectivity."
    exit
}

Write-Host "Extracting release..." -ForegroundColor Cyan
Expand-Archive -Path $zipFile -DestinationPath $targetPath -Force
Remove-Item $zipFile -Force

Write-Host "Launching Slab..." -ForegroundColor Green
if (Test-Path "slab.exe") {
    & ".\slab.exe"
} elseif (Test-Path "dist\slab.exe") {
    & "dist\slab.exe"
} elseif (Test-Path "setup.bat") {
    & ".\setup.bat"
} else {
    Write-Error "Could not locate slab.exe or setup.bat in the extracted files at $targetPath."
}
