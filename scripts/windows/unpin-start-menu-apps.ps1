[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.unpinStartMenuApps
$shouldUndo = $Undo -or !$tweakEnabled

$registryTweak = {
    Param([String]$Path, [String]$Name, [Object]$Value, [String]$Type, [Switch]$Remove, [Switch]$DryRun)
    & "$PSScriptRoot/../../src/powershell/utils/slab-set-registry.ps1" -Path $Path -Name $Name -Value $Value -PropertyType $Type -Remove:$Remove -DryRun:$DryRun
}

$osName = (Get-ComputerInfo | Select-Object -ExpandProperty OsName)
$isWin11 = $osName -match "Windows 11"

$explorerPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"

if ($isWin11) {
    if ($shouldUndo) {
        Write-Host "Restoring default Windows 11 Start Menu layout pins..." -ForegroundColor Cyan
        &$registryTweak -Path $explorerPath -Name "ConfigureStartPins" -Remove -DryRun:$DryRun
    } else {
        Write-Host "Configuring clean empty Start Menu layout pins on Windows 11..." -ForegroundColor Cyan
        $layoutJson = '{"pinnedList":[]}'
        &$registryTweak -Path $explorerPath -Name "ConfigureStartPins" -Value $layoutJson -Type "String" -DryRun:$DryRun
    }
} else {
    # Windows 10 legacy handling
    if ($shouldUndo) {
        Write-Host "Undo is not supported for legacy Windows 10 Start Menu unpinning. Skipping." -ForegroundColor Gray
        return
    }
    
    Write-Host "Windows 10 detected. Running legacy unpin script..." -ForegroundColor Cyan
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
