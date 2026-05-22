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

$isUserPath = $Path.StartsWith("Registry::HKEY_CURRENT_USER")
$pathsToModify = @($Path)
if ($isUserPath -and (Test-Path "Registry::HKEY_USERS\DefaultUser")) {
    $defaultUserPath = $Path -replace "^Registry::HKEY_CURRENT_USER", "Registry::HKEY_USERS\DefaultUser"
    $pathsToModify += $defaultUserPath
}

if ($Remove) {
    foreach ($p in $pathsToModify) {
        if ($DryRun) {
            Write-Host "[DRY-RUN] Remove-ItemProperty -Path '$p' -Name '$Name'" -ForegroundColor Yellow
            continue
        }
        if (Test-Path $p) {
            Write-Host "Removing registry property '$Name' from '$p'..." -ForegroundColor Cyan
            try {
                Remove-ItemProperty -Path $p -Name $Name -Force -ErrorAction Stop
            } catch {
                Write-Warning "Failed to remove registry property '$Name' from '$p'. It may be protected by the OS. Error: $_"
            }
        }
    }
    return
}

foreach ($p in $pathsToModify) {
    if ($DryRun) {
        Write-Host "[DRY-RUN] Set-ItemProperty -Path '$p' -Name '$Name' -Value '$Value' -Type '$PropertyType'" -ForegroundColor Yellow
        continue
    }

    # Ensure parent path exists
    if (!(Test-Path $p)) {
        Write-Host "Creating registry path: $p" -ForegroundColor Gray
        try {
            New-Item -Path $p -Force -ErrorAction Stop | Out-Null
        } catch {
            Write-Warning "Failed to create registry path '$p'. It may be protected by the OS. Error: $_"
        }
    }

    Write-Host "Setting registry: '$p' -> '$Name' = '$Value' ($PropertyType)" -ForegroundColor Cyan
    try {
        Set-ItemProperty -Path $p -Name $Name -Value $Value -Type $PropertyType -Force -ErrorAction Stop
    } catch {
        Write-Warning "Failed to set registry property '$Name' at '$p'. It may be protected by the OS (e.g. UCPD/Policy). Error: $_"
    }
}

