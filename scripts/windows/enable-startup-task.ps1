[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.startupTask.enabled
$shouldUndo = $Undo -or !$tweakEnabled

$taskName = "Launch Exhibit"
$taskPath = "\Slab\"

if ($shouldUndo) {
    if ($DryRun) {
        Write-Host "[DRY-RUN] Unregister-ScheduledTask -TaskName '$taskName' -TaskPath '$taskPath'" -ForegroundColor Yellow
        return
    }
    
    $existing = Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "Removing scheduled task '$taskName'..." -ForegroundColor Cyan
        Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false
    }
} else {
    $workingDir = $Config.startupTask.workingDir
    $executable = $Config.startupTask.executable
    $triggerType = $Config.startupTask.trigger # AtLogon or AtStartup
    $delay = $Config.startupTask.delay # e.g. PT1M

    if ($DryRun) {
        Write-Host "[DRY-RUN] Register-ScheduledTask '$taskName' ($triggerType, Delay: $delay) Executable: '$executable' in '$workingDir'" -ForegroundColor Yellow
        return
    }

    Write-Host "Creating startup scheduled task '$taskName' ($triggerType, Delay: $delay)..." -ForegroundColor Cyan
    
    # Ensure working directory exists
    if (!(Test-Path $workingDir)) {
        New-Item -ItemType Directory -Path $workingDir -Force | Out-Null
    }

    # Standard command-line string splitting
    $actionExec = $executable
    $actionArgs = ""
    if ($executable -match '^"([^"]+)"\s*(.*)$') {
        $actionExec = $Matches[1]
        $actionArgs = $Matches[2]
    } elseif ($executable -match '^([^\s]+)\s*(.*)$') {
        $actionExec = $Matches[1]
        $actionArgs = $Matches[2]
    }

    if ($actionArgs) {
        $action = New-ScheduledTaskAction -Execute $actionExec -Argument $actionArgs -WorkingDirectory $workingDir
    } else {
        $action = New-ScheduledTaskAction -Execute $actionExec -WorkingDirectory $workingDir
    }
    
    if ($triggerType -eq "AtLogon") {
        $trigger = New-ScheduledTaskTrigger -AtLogon
    } else {
        $trigger = New-ScheduledTaskTrigger -AtStartup
    }
    
    if ($delay) {
        $trigger.Delay = $delay
    }
    
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    
    Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
    Write-Host "Scheduled task '$taskName' registered successfully." -ForegroundColor Green
}