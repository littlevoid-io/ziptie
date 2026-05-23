param(
    [String]$InstallDir,
    [String]$ExtraArgs
)
$ErrorActionPreference = "Stop"

# 1. Resolve and default the installation directory to CWD if not provided
$targetPath = if ($InstallDir) { $InstallDir } else { $PWD.Path }
$targetPath = [System.IO.Path]::GetFullPath($targetPath)

# Avoid downloading into protected system/Windows directories, system drive root, or active developer workspaces
$systemRoot = [Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)
$isDevWorkspace = (Test-Path (Join-Path $targetPath "package.json")) -and (Test-Path (Join-Path $targetPath "tsconfig.json"))
if ($targetPath -like "$systemRoot*" -or $targetPath -eq "C:\" -or $isDevWorkspace) {
    $targetPath = Join-Path $HOME "Downloads\ziptie"
}

# 2. Elevate if not admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Ziptie requires administrative privileges. Elevating..." -ForegroundColor Yellow
    $escapedExtraArgs = if ($ExtraArgs) { $ExtraArgs.Replace("'", "''") } else { "" }
    $argsList = "-ExecutionPolicy Bypass -NoProfile -Command `"& { [scriptblock]::Create((irm https://raw.githubusercontent.com/littlevoid-io/ziptie/main/scripts/bootstrap.ps1)).Invoke('$targetPath', '$escapedExtraArgs') }`""
    Start-Process powershell -ArgumentList $argsList -Verb RunAs
    exit
}

# 3. Download precompiled release
New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
Set-Location -Path $targetPath

Write-Host "Downloading precompiled Ziptie release to $targetPath..." -ForegroundColor Cyan
$zipUrl = "https://github.com/littlevoid-io/ziptie/releases/latest/download/ziptie.zip"
$zipFile = "$env:TEMP\ziptie-release.zip"

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

Write-Host "Launching Ziptie..." -ForegroundColor Green
$argArray = if ($ExtraArgs) { [regex]::Matches($ExtraArgs, '("[^"]*"|\S+)') | ForEach-Object { $_.Value.Trim('"') } } else { @() }

if (Test-Path "ziptie.exe") {
    & ".\ziptie.exe" $argArray
} elseif (Test-Path "dist\ziptie.exe") {
    & "dist\ziptie.exe" $argArray
} elseif (Test-Path "setup.bat") {
    & ".\setup.bat" $argArray
} else {
    Write-Error "Could not locate ziptie.exe or setup.bat in the extracted files at $targetPath."
}
