[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.uninstallBloatware
if ($Undo) {
    Write-Host "UWP Bloatware uninstallation cannot be automatically undone. Skipping." -ForegroundColor Yellow
    return
}

if (!$tweakEnabled) {
    return
}

Write-Host "Uninstalling standard Windows bloatware packages..." -ForegroundColor Cyan

$jsonPath = "$PSScriptRoot/bloatware-list.json"
if (!(Test-Path $jsonPath)) {
    Write-Warning "Bloatware list not found at: $jsonPath"
    return
}

$apps = Get-Content -Raw -Path $jsonPath | ConvertFrom-Json

foreach ($app in $apps) {
    & "$PSScriptRoot/../utils/ziptie-remove-appx.ps1" -PackageName $app -DryRun:$DryRun
}
