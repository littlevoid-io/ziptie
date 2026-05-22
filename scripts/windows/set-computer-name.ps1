[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

if ($Undo) {
    Write-Host "Undo mode: Computer name changes are not automatically reverted." -ForegroundColor Yellow
    return
}

$computername = $Config.system.computerName
if (!$computername) { return }

$currentHostname = hostname
if ($currentHostname -eq $computername) {
    Write-Host "Computer name already set to '$computername'" -ForegroundColor Green
    return
}

if ($DryRun) {
    Write-Host "[DRY-RUN] Rename-Computer -NewName '$computername'" -ForegroundColor Yellow
    return
}

Write-Host "Setting computer name from '$currentHostname' to '$computername'..." -ForegroundColor Cyan
Rename-Computer -NewName $computername -Force -ErrorAction SilentlyContinue
Write-Host "Computer renamed. Please restart for changes to apply." -ForegroundColor Green
