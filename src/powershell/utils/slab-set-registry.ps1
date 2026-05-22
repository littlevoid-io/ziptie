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
} elseif ($Path -like "HKCU:\*") {
    $Path = $Path -replace "^HKCU:\\", "Registry::HKEY_CURRENT_USER\"
} elseif ($Path -like "HKLM:\*") {
    $Path = $Path -replace "^HKLM:\\", "Registry::HKEY_LOCAL_MACHINE\"
}

if ($Remove) {
    if ($DryRun) {
        Write-Host "[DRY-RUN] Remove-ItemProperty -Path '$Path' -Name '$Name'" -ForegroundColor Yellow
        return
    }
    if (Test-Path $Path) {
        Write-Host "Removing registry property '$Name' from '$Path'..." -ForegroundColor Cyan
        try {
            Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction Stop
        } catch {
            Write-Warning "Failed to remove registry property '$Name' from '$Path'. It may be protected by the OS. Error: $_"
        }
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
    try {
        New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
    } catch {
        Write-Warning "Failed to create registry path '$Path'. It may be protected by the OS. Error: $_"
    }
}

Write-Host "Setting registry: '$Path' -> '$Name' = '$Value' ($PropertyType)" -ForegroundColor Cyan
try {
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $PropertyType -Force -ErrorAction Stop
} catch {
    Write-Warning "Failed to set registry property '$Name' at '$Path'. It may be protected by the OS (e.g. UCPD/Policy). Error: $_"
}
