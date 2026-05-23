[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

if ($Undo) {
    Write-Host "Undo mode: Timezone changes are not automatically reverted." -ForegroundColor Yellow
    return
}

$timezone = $Config.system.timezone
if (!$timezone) { return }

if ($timezone -eq "auto") {
    if ($DryRun) {
        Write-Host "[DRY-RUN] Enable Geolocation & tzautoupdate services, set ConsentStore location to Allow, w32tm /resync" -ForegroundColor Yellow
        return
    }

    Write-Host "Auto timezone detection enabled. Setting up Windows Geolocation Services..." -ForegroundColor Cyan

    # 1. Enable location service globally and user-level in registry
    & "$PSScriptRoot/../utils/ziptie-set-registry.ps1" -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Value "Allow" -PropertyType "String"
    & "$PSScriptRoot/../utils/ziptie-set-registry.ps1" -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Value "Allow" -PropertyType "String"

    # 2. Configure and start Geolocation service (lfsvc)
    & "$PSScriptRoot/../utils/ziptie-set-service.ps1" -ServiceName "lfsvc" -StartupType "Manual" -State "Running"

    # 3. Configure and start Auto Time Zone Updater service (tzautoupdate)
    & "$PSScriptRoot/../utils/ziptie-set-service.ps1" -ServiceName "tzautoupdate" -StartupType "Manual" -State "Running"

    # 4. Sync clock with NTP server to trigger update
    & "$PSScriptRoot/../utils/ziptie-set-service.ps1" -ServiceName "w32time" -StartupType "Manual" -State "Running"

    Write-Host "Forcing NTP time synchronization..." -ForegroundColor Cyan
    & w32tm /resync
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Forced timezone update & NTP clock resync initiated successfully." -ForegroundColor Green
    } else {
        Write-Warning "NTP clock sync returned exit code $LASTEXITCODE. Geolocation services were started; auto-timezone may take a few moments."
    }
} else {
    if ($DryRun) {
        Write-Host "[DRY-RUN] & tzutil.exe /s '$timezone'" -ForegroundColor Yellow
        return
    }

    Write-Host "Setting system timezone to '$timezone'..." -ForegroundColor Cyan
    & "tzutil.exe" /s $timezone
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully set system timezone." -ForegroundColor Green
    } else {
        Write-Warning "Failed to set system timezone. tzutil exit code: $LASTEXITCODE"
    }
}
