[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.unpinStartMenuApps

if ($Undo -or !$tweakEnabled) {
    return
}

# Slab targets modern Windows 11
$osName = (Get-ComputerInfo | Select-Object -ExpandProperty OsName)
if ($osName -match "Windows 11") {
    Write-Host "Unpinning legacy Start Menu apps is a Windows 10 specific operation. Modern Windows 11 pins are managed via JSON layouts or GPOs. Skipping." -ForegroundColor Gray
} else {
    Write-Host "Windows 10 detected. Running unpin script..." -ForegroundColor Cyan
    # Legacy unpin shell COM verbs implementation for Windows 10
    if ($DryRun) {
        Write-Host "[DRY-RUN] Unpin default apps from Windows 10 Start Menu" -ForegroundColor Yellow
    } else {
        try {
            $shell = New-Object -Com Object Shell.Application
            $folder = $shell.NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}')
            if ($folder) {
                $items = $folder.Items()
                foreach ($item in $items) {
                    $item.Verbs() | Where-Object { $_.Name.Replace('&','') -match 'From "Start" UnPin|Unpin from Start' } | ForEach-Object {
                        $_.DoIt()
                    }
                }
            }
        } catch {
            Write-Warning "Failed to unpin some Start Menu apps: $_"
        }
    }
}
