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
        Write-Host "[DRY-RUN] powercfg /delete 77777777-7777-7777-7777-777777777777" -ForegroundColor Yellow
        Write-Host "[DRY-RUN] Re-enable USB selective suspend" -ForegroundColor Yellow
        Write-Host "[DRY-RUN] Restore timeout settings" -ForegroundColor Yellow
    } else {
        # Balanced Plan
        Start-Process -FilePath "powercfg.exe" -ArgumentList "/setactive", "SCHEME_BALANCED" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
        # Clean custom power plan
        $existing = powercfg /list
        if ($existing -match "77777777-7777-7777-7777-777777777777") {
            Start-Process -FilePath "powercfg.exe" -ArgumentList "/delete", "77777777-7777-7777-7777-777777777777" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
        }
        # Enable USB selective suspend (1)
        Start-Process -FilePath "powercfg.exe" -ArgumentList "/setacvalueindex", "SCHEME_BALANCED", "2a84c37e-a4b2-482f-a9c1-ad2ee10062c2", "48e6d7a6-33e3-445b-921e-0e257b20e47f", "1" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
        Start-Process -FilePath "powercfg.exe" -ArgumentList "/setdcvalueindex", "SCHEME_BALANCED", "2a84c37e-a4b2-482f-a9c1-ad2ee10062c2", "48e6d7a6-33e3-445b-921e-0e257b20e47f", "1" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
        # Restore standard timeouts (15m monitor, 30m standby)
        Start-Process -FilePath "powercfg.exe" -ArgumentList "/change", "monitor-timeout-ac", "15" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
        Start-Process -FilePath "powercfg.exe" -ArgumentList "/change", "standby-timeout-ac", "30" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
        Start-Process -FilePath "powercfg.exe" -ArgumentList "/hibernate", "on" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
    }
} else {
    Write-Host "Configuring optimized exhibit power settings (Never Sleep, Never Screen-Off)..." -ForegroundColor Cyan
    if ($DryRun) {
        Write-Host "[DRY-RUN] Import custom power plan if present, fallback to SCHEME_MIN" -ForegroundColor Yellow
        Write-Host "[DRY-RUN] Disable USB selective suspend (AC and DC)" -ForegroundColor Yellow
        Write-Host "[DRY-RUN] Configure timeouts to 0 and disable hibernation" -ForegroundColor Yellow
    } else {
        # Import and configure custom power plan
        $powPath = Join-Path $PSScriptRoot "presets/exhibit_power_config.pow"
        if (Test-Path $powPath) {
            $existing = powercfg /list
            if ($existing -match "77777777-7777-7777-7777-777777777777") {
                if ($existing -match "\*.*77777777-7777-7777-7777-777777777777") {
                    Start-Process -FilePath "powercfg.exe" -ArgumentList "/setactive", "SCHEME_BALANCED" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
                }
                Start-Process -FilePath "powercfg.exe" -ArgumentList "/delete", "77777777-7777-7777-7777-777777777777" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
            }
            Start-Process -FilePath "powercfg.exe" -ArgumentList "/import", "`"$powPath`"", "77777777-7777-7777-7777-777777777777" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
            Start-Process -FilePath "powercfg.exe" -ArgumentList "/setactive", "77777777-7777-7777-7777-777777777777" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
        } else {
            # High Performance Plan (SCHEME_MIN)
            Start-Process -FilePath "powercfg.exe" -ArgumentList "/setactive", "SCHEME_MIN" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
        }

        # Disable USB selective suspend for both AC and DC (active scheme)
        Start-Process -FilePath "powercfg.exe" -ArgumentList "/setacvalueindex", "SCHEME_CURRENT", "2a84c37e-a4b2-482f-a9c1-ad2ee10062c2", "48e6d7a6-33e3-445b-921e-0e257b20e47f", "0" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
        Start-Process -FilePath "powercfg.exe" -ArgumentList "/setdcvalueindex", "SCHEME_CURRENT", "2a84c37e-a4b2-482f-a9c1-ad2ee10062c2", "48e6d7a6-33e3-445b-921e-0e257b20e47f", "0" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null

        # Re-apply active power plan to enforce changes
        $activePlan = (powercfg /getactivescheme) -replace '^.*GUID: ([a-f0-9-]+)\s*.*$', '$1'
        Start-Process -FilePath "powercfg.exe" -ArgumentList "/setactive", $activePlan -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null

        # Configure timeouts to 0 (Never)
        Start-Process -FilePath "powercfg.exe" -ArgumentList "/change", "monitor-timeout-ac", "0" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
        Start-Process -FilePath "powercfg.exe" -ArgumentList "/change", "standby-timeout-ac", "0" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
        # Disable Hibernation
        Start-Process -FilePath "powercfg.exe" -ArgumentList "/hibernate", "off" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue | Out-Null
    }
}
