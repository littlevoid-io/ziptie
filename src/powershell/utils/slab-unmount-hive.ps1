Param(
    [Parameter(Mandatory=$true)]
    [String]$MountName,
    [Switch]$DryRun
)

if ($DryRun) {
    Write-Host "[DRY-RUN] Unmount Hive: reg unload '$MountName'" -ForegroundColor Yellow
    return
}

# Force garbage collection to release any locks PowerShell might hold on registry keys
[gc]::Collect()
[gc]::WaitForPendingFinalizers()

Write-Host "Unmounting registry hive '$MountName'..." -ForegroundColor Cyan
& reg.exe unload $MountName 2>&1 | Out-String | Write-Verbose

if ($LASTEXITCODE -ne 0) {
    # Sometimes it fails due to transient locks, wait and retry once
    Start-Sleep -Seconds 1
    [gc]::Collect()
    [gc]::WaitForPendingFinalizers()
    & reg.exe unload $MountName 2>&1 | Out-String | Write-Verbose
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to unload registry hive '$MountName'. Exit code: $LASTEXITCODE"
    } else {
        Write-Host "Successfully unmounted registry hive on retry." -ForegroundColor Green
    }
} else {
    Write-Host "Successfully unmounted registry hive." -ForegroundColor Green
}
