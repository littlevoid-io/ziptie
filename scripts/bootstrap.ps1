param(
    [String]$InstallDir,
    [String]$ExtraArgs,
    [String]$WorkingDir,
    [Switch]$Local,
    [Switch]$SkipElevation
)
$ErrorActionPreference = "Stop"

# Immediately capture and switch/validate the working directory
if (-not $WorkingDir) {
    $WorkingDir = $PWD.ProviderPath
}
Set-Location -Path $WorkingDir

# Detect if there's a user config in the caller's directory before changing location
$callerConfigPath = Join-Path $WorkingDir "ziptie.config.json"
$hasCallerConfig = Test-Path $callerConfigPath -PathType Leaf

# 1. Resolve target path, defaulting to a "ziptie" subfolder in TEMP if not provided
$targetPath = if ($InstallDir) { $InstallDir } else { Join-Path $env:TEMP "ziptie" }
$targetPath = [System.IO.Path]::GetFullPath($targetPath)

# Detect if running from a local repository copy
$isLocalScript = $false
$repoRoot = $null
if ($PSScriptRoot) {
    $possibleRepoRoot = Split-Path -Parent $PSScriptRoot
    if (Test-Path (Join-Path $possibleRepoRoot "ziptie.schema.json")) {
        $isLocalScript = $true
        $repoRoot = $possibleRepoRoot
    }
}

if ($Local -or $isLocalScript) {
    $Local = $true
    if (-not $repoRoot -and $PSScriptRoot) {
        $repoRoot = Split-Path -Parent $PSScriptRoot
    }
    if ($Local -and -not $repoRoot) {
        if (Test-Path "ziptie.schema.json") {
            $repoRoot = $PWD.ProviderPath
        } elseif (Test-Path "..\ziptie.schema.json") {
            $repoRoot = (Get-Item "..").FullName
        }
    }
}

# Avoid downloading into protected system/Windows directories, system drive root, or active developer workspaces
$systemRoot = [Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)
$isDevWorkspace = (Test-Path (Join-Path $WorkingDir "package.json")) -and (Test-Path (Join-Path $WorkingDir "tsconfig.json"))
if ($targetPath -like "$systemRoot*" -or $targetPath -eq "C:\" -or $isDevWorkspace) {
    $targetPath = Join-Path $HOME "Downloads\ziptie"
}

# 2. Elevate if not admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and -not $SkipElevation) {
    Write-Host "Ziptie requires administrative privileges. Elevating..." -ForegroundColor Yellow
    $escapedExtraArgs = if ($ExtraArgs) { $ExtraArgs.Replace("'", "''") } else { "" }
    
    if ($Local) {
        $scriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
        $argsList = "-ExecutionPolicy Bypass -NoProfile -File `"$scriptPath`""
        if ($InstallDir) { $argsList += " -InstallDir `"$InstallDir`"" }
        if ($ExtraArgs) { $argsList += " -ExtraArgs `"$escapedExtraArgs`"" }
        if ($WorkingDir) { $argsList += " -WorkingDir `"$WorkingDir`"" }
        $argsList += " -Local"
    } else {
        $argsList = "-ExecutionPolicy Bypass -NoProfile -Command `"& { [scriptblock]::Create((irm https://raw.githubusercontent.com/littlevoid-io/ziptie/main/scripts/bootstrap.ps1)).Invoke('$targetPath', '$escapedExtraArgs', '$WorkingDir') }`""
    }
    
    Start-Process powershell -ArgumentList $argsList -Verb RunAs
    exit
}

# 3. Obtain release files
New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
Set-Location -Path $targetPath

if ($Local) {
    Write-Host "[Local Simulation] Copying Ziptie release files from local repo at $repoRoot to $targetPath..." -ForegroundColor Cyan
    $itemsToCopy = @("dist", "scripts", "ziptie.default.config.json", "ziptie.schema.json", "setup.bat")
    foreach ($item in $itemsToCopy) {
        $destItem = Join-Path $targetPath $item
        if (Test-Path $destItem) {
            Remove-Item -Path $destItem -Recurse -Force -ErrorAction SilentlyContinue
        }
        $srcPath = Join-Path $repoRoot $item
        if (Test-Path $srcPath) {
            Copy-Item -Path $srcPath -Destination $targetPath -Recurse -Force
        }
    }
} else {
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
    # Clean up old local folders explicitly to prevent stale file caching or partial extraction blocks
    $itemsToClean = @("dist", "scripts", "ziptie.default.config.json", "ziptie.schema.json", "setup.bat")
    foreach ($item in $itemsToClean) {
        $destItem = Join-Path $targetPath $item
        if (Test-Path $destItem) {
            Remove-Item -Path $destItem -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Expand-Archive -Path $zipFile -DestinationPath $targetPath -Force
    Remove-Item $zipFile -Force
}

Set-Location -Path $WorkingDir

Write-Host "Launching Ziptie..." -ForegroundColor Green
$argArray = if ($ExtraArgs) { [regex]::Matches($ExtraArgs, '("[^"]*"|\S+)') | ForEach-Object { $_.Value.Trim('"') } } else { @() }

# Pass the caller's config via CLI if detected and not already overridden in ExtraArgs
$hasConfigArg = $false
foreach ($arg in $argArray) {
    if ($arg -eq "-c" -or $arg -eq "--config") {
        $hasConfigArg = $true
        break
    }
}
if ($hasCallerConfig -and -not $hasConfigArg) {
    Write-Host "Detected local config in caller directory at $callerConfigPath. Passing to Ziptie..." -ForegroundColor Cyan
    $argArray += @("-c", $callerConfigPath)
}

$exePath = Join-Path $targetPath "ziptie.exe"
$distExePath = Join-Path $targetPath "dist\ziptie.exe"
$setupBatPath = Join-Path $targetPath "setup.bat"

if (Test-Path $exePath) {
    & $exePath $argArray
} elseif (Test-Path $distExePath) {
    & $distExePath $argArray
} elseif (Test-Path $setupBatPath) {
    & $setupBatPath $argArray
} else {
    Write-Error "Could not locate ziptie.exe or setup.bat in the extracted files at $targetPath."
}
