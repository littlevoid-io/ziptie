Param(
    [Parameter(Mandatory=$true)]
    [String]$MountName,
    [Parameter(Mandatory=$true)]
    [String]$HivePath,
    [Switch]$DryRun
)

if ($DryRun) {
    Write-Host "[DRY-RUN] Mount Hive: reg load '$MountName' '$HivePath'" -ForegroundColor Yellow
    return
}

if (!(Test-Path $HivePath -PathType Leaf)) {
    throw "Hive file does not exist: $HivePath"
}

Write-Host "Mounting registry hive '$HivePath' to '$MountName'..." -ForegroundColor Cyan
& reg.exe load $MountName $HivePath 2>&1 | Out-String | Write-Verbose

if ($LASTEXITCODE -ne 0) {
    throw "Failed to load registry hive '$HivePath' to '$MountName'. Exit code: $LASTEXITCODE"
}

Write-Host "Successfully mounted registry hive." -ForegroundColor Green
