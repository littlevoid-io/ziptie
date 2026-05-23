param(
    [String]$InstallDir,
    [String]$ExtraArgs,
    [Switch]$Local,
    [Switch]$SkipElevation
)
$ErrorActionPreference = "Stop"

# Detect if there's a user config in the caller's directory before changing location
$callerConfigPath = Join-Path $PWD.Path "ziptie.config.json"
$hasCallerConfig = Test-Path $callerConfigPath -PathType Leaf

# 1. Resolve target path, defaulting to a "ziptie" subfolder in CWD if not provided
$targetPath = if ($InstallDir) { $InstallDir } else { Join-Path $PWD.Path "ziptie" }
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
            $repoRoot = $PWD.Path
        } elseif (Test-Path "..\ziptie.schema.json") {
            $repoRoot = (Get-Item "..").FullName
        }
    }
}

# Avoid downloading into protected system/Windows directories, system drive root, or active developer workspaces
$systemRoot = [Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)
$isDevWorkspace = (Test-Path (Join-Path $PWD.Path "package.json")) -and (Test-Path (Join-Path $PWD.Path "tsconfig.json"))
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
        $argsList += " -Local"
    } else {
        $argsList = "-ExecutionPolicy Bypass -NoProfile -Command `"& { [scriptblock]::Create((irm https://raw.githubusercontent.com/littlevoid-io/ziptie/main/scripts/bootstrap.ps1)).Invoke('$targetPath', '$escapedExtraArgs') }`""
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

if (Test-Path "ziptie.exe") {
    & ".\ziptie.exe" $argArray
} elseif (Test-Path "dist\ziptie.exe") {
    & "dist\ziptie.exe" $argArray
} elseif (Test-Path "setup.bat") {
    & ".\setup.bat" $argArray
} else {
    Write-Error "Could not locate ziptie.exe or setup.bat in the extracted files at $targetPath."
}
