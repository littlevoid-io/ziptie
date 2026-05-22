[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.system.enableDailyReboot
$shouldUndo = $Undo -or !$tweakEnabled

$taskName = "Daily System Reboot"
$taskPath = "\Slab\"

if ($shouldUndo) {
    if ($DryRun) {
        Write-Host "[DRY-RUN] Unregister-ScheduledTask -TaskName '$taskName' -TaskPath '$taskPath'" -ForegroundColor Yellow
        return
    }
    
    $existing = Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "Removing scheduled reboot task '$taskName'..." -ForegroundColor Cyan
        Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false
    }
} else {
    $rebootTime = $Config.system.rebootTime
    if (!$rebootTime) { return }

    if ($DryRun) {
        Write-Host "[DRY-RUN] Register-ScheduledTask '$taskName' (Daily at $rebootTime)" -ForegroundColor Yellow
        return
    }

    Write-Host "Registering scheduled daily reboot task '$taskName' at $rebootTime..." -ForegroundColor Cyan
    $action = New-ScheduledTaskAction -Execute "shutdown.exe" -Argument "-r -f -t 0"
    $trigger = New-ScheduledTaskTrigger -Daily -At $rebootTime
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    
    Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
    Write-Host "Scheduled daily reboot task registered successfully." -ForegroundColor Green
}