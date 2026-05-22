[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.uninstallOneDrive

if ($Undo) {
    Write-Host "OneDrive uninstallation cannot be automatically undone. Skipping." -ForegroundColor Yellow
    return
}

if (!$tweakEnabled) {
    return
}

Write-Host "Uninstalling Microsoft OneDrive client..." -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "[DRY-RUN] taskkill /f /im OneDrive.exe" -ForegroundColor Yellow
    Write-Host "[DRY-RUN] %SystemRoot%\System32\OneDriveSetup.exe /uninstall" -ForegroundColor Yellow
    Write-Host "[DRY-RUN] %SystemRoot%\SysWOW64\OneDriveSetup.exe /uninstall" -ForegroundColor Yellow
} else {
    Start-Process -FilePath "taskkill.exe" -ArgumentList "/f", "/im", "OneDrive.exe" -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
    
    $setup32 = "$env:SystemRoot\System32\OneDriveSetup.exe"
    $setup64 = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
    
    if (Test-Path $setup64) {
        Write-Host "Running 64-bit OneDrive uninstaller..." -ForegroundColor Gray
        Start-Process -FilePath $setup64 -ArgumentList "/uninstall" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
    } elseif (Test-Path $setup32) {
        Write-Host "Running 32-bit OneDrive uninstaller..." -ForegroundColor Gray
        Start-Process -FilePath $setup32 -ArgumentList "/uninstall" -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
    }
}