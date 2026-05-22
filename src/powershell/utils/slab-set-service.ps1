Param(
    [Parameter(Mandatory=$true)]
    [String]$ServiceName,
    [String]$StartupType,
    [String]$State,
    [Switch]$DryRun
)

$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

if (!$service) {
    Write-Warning "Service '$ServiceName' not found on this system."
    return
}

if ($StartupType) {
    if ($DryRun) {
        Write-Host "[DRY-RUN] Set-Service '$ServiceName' -StartupType '$StartupType'" -ForegroundColor Yellow
    } else {
        Write-Host "Configuring service '$ServiceName' startup type to '$StartupType'..." -ForegroundColor Cyan
        Set-Service -Name $ServiceName -StartupType $StartupType -ErrorAction Stop
    }
}

if ($State) {
    if ($State -eq "Running" -and $service.Status -ne "Running") {
        if ($DryRun) {
            Write-Host "[DRY-RUN] Start-Service '$ServiceName'" -ForegroundColor Yellow
        } else {
            Write-Host "Starting service '$ServiceName'..." -ForegroundColor Cyan
            Start-Service -Name $ServiceName -ErrorAction Stop
        }
    }
    elseif ($State -eq "Stopped" -and $service.Status -ne "Stopped") {
        if ($DryRun) {
            Write-Host "[DRY-RUN] Stop-Service '$ServiceName'" -ForegroundColor Yellow
        } else {
            Write-Host "Stopping service '$ServiceName'..." -ForegroundColor Cyan
            Stop-Service -Name $ServiceName -Force -ErrorAction Stop
        }
    }
}
