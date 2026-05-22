[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.setPowerSettings
$shouldUndo = $Undo -or !$tweakEnabled

if ($shouldUndo) {
    Write-Host "Restoring default Balanced power plan and timeout settings..." -ForegroundColor Cyan
    if ($DryRun) {
        Write-Host "[DRY-RUN] powercfg /setactive SCHEME_BALANCED" -ForegroundColor Yellow
        Write-Host "[DRY-RUN] powercfg /change monitor-timeout-ac 15" -ForegroundColor Yellow
        Write-Host "[DRY-RUN] powercfg /change standby-timeout-ac 30" -ForegroundColor Yellow
        Write-Host "[DRY-RUN] powercfg /hibernate on" -ForegroundColor Yellow
    } else {
        # Balanced Plan
        Start-Process -FilePath "powercfg.exe" -ArgumentList "/setactive", "SCHEME_BALANCED" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
        # Restore standard timeouts (15m monitor, 30m standby)
        Start-Process -FilePath "powercfg.exe" -ArgumentList "/change", "monitor-timeout-ac", "15" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
        Start-Process -FilePath "powercfg.exe" -ArgumentList "/change", "standby-timeout-ac", "30" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
        Start-Process -FilePath "powercfg.exe" -ArgumentList "/hibernate", "on" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
    }
} else {
    Write-Host "Configuring optimized exhibit power settings (Never Sleep, Never Screen-Off)..." -ForegroundColor Cyan
    if ($DryRun) {
        Write-Host "[DRY-RUN] powercfg /setactive SCHEME_MIN" -ForegroundColor Yellow
        Write-Host "[DRY-RUN] powercfg /change monitor-timeout-ac 0" -ForegroundColor Yellow
        Write-Host "[DRY-RUN] powercfg /change standby-timeout-ac 0" -ForegroundColor Yellow
        Write-Host "[DRY-RUN] powercfg /hibernate off" -ForegroundColor Yellow
    } else {
        # High Performance Plan (SCHEME_MIN)
        Start-Process -FilePath "powercfg.exe" -ArgumentList "/setactive", "SCHEME_MIN" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
        # Configure timeouts to 0 (Never)
        Start-Process -FilePath "powercfg.exe" -ArgumentList "/change", "monitor-timeout-ac", "0" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
        Start-Process -FilePath "powercfg.exe" -ArgumentList "/change", "standby-timeout-ac", "0" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
        # Disable Hibernation
        Start-Process -FilePath "powercfg.exe" -ArgumentList "/hibernate", "off" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
    }
}
