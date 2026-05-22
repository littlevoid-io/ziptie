Param(
    [Parameter(Mandatory=$true)]
    [String]$Path,
    [Parameter(Mandatory=$true)]
    [String]$Name,
    [Object]$Value,
    [String]$PropertyType = "DWord",
    [Switch]$Remove,
    [Switch]$DryRun
)

# Standardize path syntax if needed
if ($Path -like "HKU\DefaultUser*") {
    $Path = $Path -replace "HKU\\DefaultUser", "Registry::HKEY_USERS\DefaultUser"
} elseif ($Path -like "HKU:\DefaultUser*") {
    $Path = $Path -replace "HKU:\\DefaultUser", "Registry::HKEY_USERS\DefaultUser"
}

if ($Remove) {
    if ($DryRun) {
        Write-Host "[DRY-RUN] Remove-ItemProperty -Path '$Path' -Name '$Name'" -ForegroundColor Yellow
        return
    }
    if (Test-Path $Path) {
        Write-Host "Removing registry property '$Name' from '$Path'..." -ForegroundColor Cyan
        Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction SilentlyContinue
    }
    return
}

if ($DryRun) {
    Write-Host "[DRY-RUN] Set-ItemProperty -Path '$Path' -Name '$Name' -Value '$Value' -Type '$PropertyType'" -ForegroundColor Yellow
    return
}

# Ensure parent path exists
if (!(Test-Path $Path)) {
    Write-Host "Creating registry path: $Path" -ForegroundColor Gray
    New-Item -Path $Path -Force -ErrorAction SilentlyContinue | Out-Null
}

Write-Host "Setting registry: '$Path' -> '$Name' = '$Value' ($PropertyType)" -ForegroundColor Cyan
Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $PropertyType -Force -ErrorAction Stop
