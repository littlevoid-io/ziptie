[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.disableFirewall
$shouldUndo = $Undo -or !$tweakEnabled

if ($shouldUndo) {
    if ($DryRun) {
        Write-Host "[DRY-RUN] Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True" -ForegroundColor Yellow
    } else {
        Write-Host "Enabling Windows Defender Firewall..." -ForegroundColor Cyan
        Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True -ErrorAction Stop
    }
} else {
    if ($DryRun) {
        Write-Host "[DRY-RUN] Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False" -ForegroundColor Yellow
    } else {
        Write-Host "Disabling Windows Defender Firewall (Domain, Public, Private profiles)..." -ForegroundColor Cyan
        Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False -ErrorAction Stop
    }
}