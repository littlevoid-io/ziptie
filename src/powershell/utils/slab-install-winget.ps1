[CmdletBinding()]
Param(
    [Switch]$DryRun
)

Write-Host "Winget is not installed. Bootstrapping Windows Package Manager..." -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "[DRY-RUN] Downloading and installing WinGet and matching dependencies..." -ForegroundColor Yellow
    return
}

$tempDir = "$env:TEMP\SlabWinGet"
if (!(Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
}

try {
    $progressPreference = 'silentlyContinue'
    
    Write-Host "Fetching latest winget-cli release metadata from GitHub API..." -ForegroundColor Gray
    $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases" -UseBasicParsing
    $latest = $releases | Sort-Object -Property published_at -Descending | Select-Object -First 1
    if (!$latest) { throw "Could not retrieve the latest release metadata." }
    
    Write-Host "Latest WinGet Version: $($latest.tag_name)" -ForegroundColor Gray
    
    $msixName = "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
    $depsZipName = "DesktopAppInstaller_Dependencies.zip"
    
    $msixAsset = $latest.assets | Where-Object { $_.name -eq $msixName }
    $depsAsset = $latest.assets | Where-Object { $_.name -eq $depsZipName }
    
    if (!$msixAsset -or !$depsAsset) { throw "Could not find required assets in the latest release." }
    
    Write-Host "Downloading matching dependencies zip..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $depsAsset.browser_download_url -OutFile "$tempDir\Dependencies.zip" -UseBasicParsing
    
    Write-Host "Downloading WinGet msixbundle..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $msixAsset.browser_download_url -OutFile "$tempDir\WinGet.msixbundle" -UseBasicParsing
    
    Write-Host "Extracting matching dependencies zip..." -ForegroundColor Gray
    Expand-Archive -Path "$tempDir\Dependencies.zip" -DestinationPath "$tempDir\DepsExtracted" -Force
    
    $depsFolder = "$tempDir\DepsExtracted\x64"
    if (Test-Path $depsFolder) {
        $appxFiles = Get-ChildItem -Path $depsFolder -Filter *.appx -Recurse
        foreach ($file in $appxFiles) {
            Write-Host "Installing dependency: $($file.Name)" -ForegroundColor Gray
            Add-AppxPackage -Path $file.FullName -ErrorAction SilentlyContinue
        }
    } else {
        Write-Warning "Dependencies folder 'x64' not found in extracted zip."
    }
    
    Write-Host "Installing WinGet (App Installer)..." -ForegroundColor Gray
    Add-AppxPackage -Path "$tempDir\WinGet.msixbundle"
    
    # Initialize sources and remove unstable msstore source to prevent Rest API failures in guest sandbox
    try { & winget list --accept-source-agreements | Out-Null } catch {}
    try { & winget source remove -n msstore --ignore-warnings | Out-Null } catch {}
    
    Write-Host "WinGet bootstrapping completed successfully." -ForegroundColor Green
} catch {
    Write-Warning "Failed to bootstrap WinGet via MSIX direct packages: $_"
    
    try {
        Write-Host "Attempting Stage B fallback: provisioning WinGet via Microsoft.WinGet.Client module..." -ForegroundColor Cyan
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072 # TLS 1.2
        
        if (!(Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
            Write-Host "Installing NuGet package provider..." -ForegroundColor Gray
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope Process -ErrorAction SilentlyContinue | Out-Null
        }
        
        Write-Host "Installing Microsoft.WinGet.Client module..." -ForegroundColor Gray
        Install-Module -Name Microsoft.WinGet.Client -Force -Scope Process -Confirm:$false -AllowClobber -ErrorAction SilentlyContinue | Out-Null
        
        if (Get-Command "Repair-WinGetPackageManager" -ErrorAction SilentlyContinue) {
            Write-Host "Executing Repair-WinGetPackageManager to install latest WinGet dependencies..." -ForegroundColor Gray
            Repair-WinGetPackageManager -Force:$true -Latest -ErrorAction SilentlyContinue | Out-Null
            Write-Host "WinGet Stage B bootstrapping completed." -ForegroundColor Green
        } else {
            Write-Warning "Repair-WinGetPackageManager cmdlet is not available after module installation."
        }
    } catch {
        Write-Warning "Failed to bootstrap WinGet via Stage B fallback: $_"
    }
} finally {
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
