[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$tweakEnabled = $Config.lockdown.configureExplorer
$shouldUndo = $Undo -or !$tweakEnabled

$registryTweak = {
    Param([String]$Path, [String]$Name, [Object]$Value, [String]$Type, [Switch]$Remove, [Switch]$DryRun)
    & "$PSScriptRoot/../../src/powershell/utils/slab-set-registry.ps1" -Path $Path -Name $Name -Value $Value -PropertyType $Type -Remove:$Remove -DryRun:$DryRun
}

$userPaths = @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer")
if (Test-Path "HKU:\DefaultUser") {
    $userPaths += @("HKU:\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "HKU:\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer")
}

if ($shouldUndo) {
    Write-Host "Restoring default Windows Explorer configurations..." -ForegroundColor Cyan
    foreach ($base in $userPaths) {
        if ($base -like "*Advanced") {
            &$registryTweak -Path $base -Name "Hidden" -Remove -DryRun:$DryRun
            &$registryTweak -Path $base -Name "HideFileExt" -Remove -DryRun:$DryRun
            &$registryTweak -Path $base -Name "HideDrivesWithNoMedia" -Remove -DryRun:$DryRun
            &$registryTweak -Path $base -Name "ShowSyncProviderNotifications" -Remove -DryRun:$DryRun
            &$registryTweak -Path $base -Name "DisallowShaking" -Remove -DryRun:$DryRun
            &$registryTweak -Path $base -Name "LaunchTo" -Remove -DryRun:$DryRun
            &$registryTweak -Path $base -Name "AutoCheckSelect" -Remove -DryRun:$DryRun
            &$registryTweak -Path $base -Name "TaskbarSizeMove" -Remove -DryRun:$DryRun
            &$registryTweak -Path $base -Name "MMTaskbarEnabled" -Remove -DryRun:$DryRun
            &$registryTweak -Path $base -Name "StoreAppsOnTaskbar" -Remove -DryRun:$DryRun
        } else {
            &$registryTweak -Path $base -Name "TaskbarNoMultimon" -Remove -DryRun:$DryRun
        }
    }
    # Thumbs.db
    $thumbPaths = @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer")
    if (Test-Path "HKU:\DefaultUser") { $thumbPaths += "HKU:\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" }
    foreach ($p in $thumbPaths) {
        &$registryTweak -Path $p -Name "DisableThumbnailsOnNetworkFolders" -Remove -DryRun:$DryRun
    }
} else {
    Write-Host "Configuring Windows Explorer defaults for exhibit..." -ForegroundColor Cyan
    foreach ($base in $userPaths) {
        if ($base -like "*Advanced") {
            &$registryTweak -Path $base -Name "Hidden" -Value 1 -Type "DWord" -DryRun:$DryRun
            &$registryTweak -Path $base -Name "HideFileExt" -Value 0 -Type "DWord" -DryRun:$DryRun
            &$registryTweak -Path $base -Name "HideDrivesWithNoMedia" -Value 0 -Type "DWord" -DryRun:$DryRun
            &$registryTweak -Path $base -Name "ShowSyncProviderNotifications" -Value 0 -Type "DWord" -DryRun:$DryRun
            &$registryTweak -Path $base -Name "DisallowShaking" -Value 1 -Type "DWord" -DryRun:$DryRun
            &$registryTweak -Path $base -Name "LaunchTo" -Value 1 -Type "DWord" -DryRun:$DryRun
            &$registryTweak -Path $base -Name "AutoCheckSelect" -Value 0 -Type "DWord" -DryRun:$DryRun
            &$registryTweak -Path $base -Name "TaskbarSizeMove" -Value 1 -Type "DWord" -DryRun:$DryRun
            &$registryTweak -Path $base -Name "MMTaskbarEnabled" -Value 0 -Type "DWord" -DryRun:$DryRun
            &$registryTweak -Path $base -Name "StoreAppsOnTaskbar" -Value 0 -Type "DWord" -DryRun:$DryRun
        } else {
            &$registryTweak -Path $base -Name "TaskbarNoMultimon" -Value 0 -Type "DWord" -DryRun:$DryRun
        }
    }
    # Thumbs.db
    $thumbPaths = @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer")
    if (Test-Path "HKU:\DefaultUser") { $thumbPaths += "HKU:\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" }
    foreach ($p in $thumbPaths) {
        &$registryTweak -Path $p -Name "DisableThumbnailsOnNetworkFolders" -Value 1 -Type "DWord" -DryRun:$DryRun
    }
    # Hide taskbar StuckRects3 Settings
    $stuckPaths = @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3")
    if (Test-Path "HKU:\DefaultUser") { $stuckPaths += "HKU:\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3" }
    foreach ($p in $stuckPaths) {
        if ($DryRun) {
            Write-Host "[DRY-RUN] Auto-hide taskbar via StuckRects3 Settings" -ForegroundColor Yellow
        } else {
            if (Test-Path $p) {
                $v = (Get-ItemProperty -Path $p -Name Settings -ErrorAction SilentlyContinue).Settings
                if ($v) { $v[8] = 3; Set-ItemProperty -Path $p -Name Settings -Value $v -Force -ErrorAction SilentlyContinue }
            }
        }
    }
    # Remove namespace folders from This PC (HKLM)
    $namespaces = @(
        "MyComputer\NameSpace\{1CF1260C-4DD0-4ebb-811F-33C572699FDE}", "MyComputer\NameSpace\{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}",
        "MyComputer\NameSpace\{3ADD1653-EB32-4cb0-BBD7-DFA0ABB5ACCA}", "MyComputer\NameSpace\{24ad3ad4-a569-4530-98e1-ab02f9417aa8}",
        "MyComputer\NameSpace\{A0953C92-50DC-43bf-BE83-3742FED03C9C}", "MyComputer\NameSpace\{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}",
        "MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}"
    )
    foreach ($ns in $namespaces) {
        if ($DryRun) {
            Write-Host "[DRY-RUN] Remove namespace: $ns" -ForegroundColor Yellow
        } else {
            Remove-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\$ns" -Force -Recurse -ErrorAction SilentlyContinue
            Remove-Item "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\$ns" -Force -Recurse -ErrorAction SilentlyContinue
        }
    }
}
