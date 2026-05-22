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