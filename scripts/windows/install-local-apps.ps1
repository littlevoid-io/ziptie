[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

if ($Undo) {
    Write-Host "Automatic uninstall is not supported for package installations. Please manage app removals manually." -ForegroundColor Yellow
    return
}

$provider = $Config.packageManager.provider
$allowOffline = $Config.packageManager.allowOfflineFallback
$localPath = $Config.packageManager.localInstallersPath
$apps = $Config.packageManager.apps

# Check network connectivity
$isOnline = $false
try { if ((New-Object System.Net.NetworkInformation.Ping).Send("1.1.1.1", 1000).Status -eq "Success") { $isOnline = $true } } catch {}

# Check Winget/Choco availability
$hasWinget = $null -ne (Get-Command "winget" -ErrorAction SilentlyContinue)
$hasChoco = $null -ne (Get-Command "choco" -ErrorAction SilentlyContinue)

# Attempt WinGet bootstrap if designated but missing
if ($provider -eq "winget" -and $isOnline -and !$hasWinget) {
    Write-Warning "Winget is not installed. Bootstrapping Windows Package Manager..."
    & "$PSScriptRoot/../../src/powershell/utils/slab-install-winget.ps1" -DryRun:$DryRun
    $hasWinget = $null -ne (Get-Command "winget" -ErrorAction SilentlyContinue)
}

# Attempt Choco bootstrap if designated/fallback but missing
if (($provider -eq "choco" -or ($provider -eq "winget" -and !$hasWinget)) -and $isOnline -and !$hasChoco) {
    Write-Warning "Chocolatey is not installed. Bootstrapping Chocolatey..."
    & "$PSScriptRoot/../../src/powershell/utils/slab-install-choco.ps1"
    $hasChoco = $null -ne (Get-Command "choco" -ErrorAction SilentlyContinue)
}

# 1. Install via Winget
if ($provider -eq "winget" -and $isOnline -and $hasWinget) {
    Write-Host "System is online. Installing apps via Winget..." -ForegroundColor Cyan
    foreach ($app in $apps) {
        if ($DryRun) { Write-Host "[DRY-RUN] winget install --id '$app' --source winget --silent --accept-source-agreements --accept-package-agreements" -ForegroundColor Yellow }
        else {
            Write-Host "Installing '$app' via Winget..." -ForegroundColor Cyan
            & winget install --id $app --source winget --silent --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -eq 0) { Write-Host "Successfully installed '$app'." -ForegroundColor Green }
            else { Write-Warning "Winget failed to install '$app'. Exit code: $LASTEXITCODE" }
        }
    }
}
# 2. Install/Fallback via Chocolatey
elseif (($provider -eq "choco" -or ($provider -eq "winget" -and !$hasWinget)) -and $isOnline -and $hasChoco) {
    Write-Host "Installing apps via Chocolatey..." -ForegroundColor Cyan
    $chocoMap = @{ "CoreyButler.NVMforWindows" = "nvm"; "Microsoft.VisualStudioCode" = "vscode"; "Git.Git" = "git" }
    foreach ($app in $apps) {
        $chocoName = $chocoMap[$app]
        if (!$chocoName) { $chocoName = $app.Split('.')[-1].ToLower() }
        if ($DryRun) { Write-Host "[DRY-RUN] choco install '$chocoName' -y" -ForegroundColor Yellow }
        else {
            Write-Host "Installing '$chocoName' via Chocolatey..." -ForegroundColor Cyan
            & choco install $chocoName -y
            if ($LASTEXITCODE -eq 0) { Write-Host "Successfully installed '$chocoName'." -ForegroundColor Green }
            else { Write-Warning "Chocolatey failed to install '$chocoName'. Exit code: $LASTEXITCODE" }
        }
    }
}
# 3. Offline installer Fallback
elseif ($allowOffline) {
    Write-Host "Falling back to offline installers..." -ForegroundColor Yellow
    & "$PSScriptRoot/../../src/powershell/utils/slab-install-offline.ps1" -LocalPath $localPath -DryRun:$DryRun -RunRoot $PSScriptRoot/../../
}
else { Write-Host "Skipping package installations (provider is none, or system is offline with fallback disabled)." -ForegroundColor Gray }

# 4. Post-install: NVM Configuration
if (($apps -match "NVM") -and $isOnline) {
    & "$PSScriptRoot/../../src/powershell/utils/slab-configure-nvm.ps1" -DryRun:$DryRun
}
