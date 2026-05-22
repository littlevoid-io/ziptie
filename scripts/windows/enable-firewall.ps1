[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

# Delegating to disable-firewall with inverted activation
& "$PSScriptRoot/disable-firewall.ps1" -Config $Config -DryRun:$DryRun -Undo:(!$Undo)