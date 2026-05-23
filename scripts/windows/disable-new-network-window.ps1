[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)] [Object]$Config,
    [Switch]$DryRun, [Switch]$Undo
)

. "$PSScriptRoot/../utils/ziptie-init.ps1"

$tweakEnabled = $Config.lockdown.disableNewNetworkWindow
$shouldUndo = $Undo -or !$tweakEnabled

$path = "HKLM:\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff"

if ($shouldUndo) {
    Write-Host "Re-enabling discoverability network prompts..." -ForegroundColor Cyan
    if ($DryRun) {
        Write-Host "[DRY-RUN] Remove-Item -Path '$path'" -ForegroundColor Yellow
    } else {
        if (Test-Path $path) {
            Remove-Item -Path $path -Force -Recurse -ErrorAction SilentlyContinue
        }
    }
} else {
    Write-Host "Disabling discoverability network prompts..." -ForegroundColor Cyan
    &$registryTweak -Path $path -Name "Enabled" -Value 1 -Type "DWord"
}
