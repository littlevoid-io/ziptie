[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)] [Object]$Config,
    [Switch]$DryRun, [Switch]$Undo
)

. "$PSScriptRoot/../../src/powershell/utils/slab-init.ps1"

$tweakEnabled = $Config.lockdown.configureExplorer
$shouldUndo = $Undo -or !$tweakEnabled

$userPaths = @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer")
$searchPaths = @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Search")

if ($shouldUndo) {
    Write-Host "Restoring default Windows Explorer & Taskbar settings..." -ForegroundColor Cyan
    foreach ($base in $userPaths) {
        if ($base -like "*Advanced") {
            foreach ($prop in @("Hidden","HideFileExt","HideDrivesWithNoMedia","ShowSyncProviderNotifications","DisallowShaking","LaunchTo","AutoCheckSelect","TaskbarSizeMove","MMTaskbarEnabled","StoreAppsOnTaskbar")) {
                &$registryTweak -Path $base -Name $prop -Remove
            }
        } else {
            &$registryTweak -Path $base -Name "TaskbarNoMultimon" -Remove
        }
    }
    foreach ($p in $searchPaths) {
        &$registryTweak -Path $p -Name "SearchboxTaskbarMode" -Remove
        &$registryTweak -Path $p -Name "SearchboxTaskbarModeCache" -Remove
    }
    # Thumbs.db
    &$registryTweak -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "DisableThumbnailsOnNetworkFolders" -Remove
} else {
    Write-Host "Configuring Windows Explorer & Taskbar defaults for exhibit..." -ForegroundColor Cyan
    foreach ($base in $userPaths) {
        if ($base -like "*Advanced") {
            &$registryTweak -Path $base -Name "Hidden" -Value 1 -Type "DWord"
            &$registryTweak -Path $base -Name "HideFileExt" -Value 0 -Type "DWord"
            &$registryTweak -Path $base -Name "HideDrivesWithNoMedia" -Value 0 -Type "DWord"
            &$registryTweak -Path $base -Name "ShowSyncProviderNotifications" -Value 0 -Type "DWord"
            &$registryTweak -Path $base -Name "DisallowShaking" -Value 1 -Type "DWord"
            &$registryTweak -Path $base -Name "LaunchTo" -Value 1 -Type "DWord"
            &$registryTweak -Path $base -Name "AutoCheckSelect" -Value 0 -Type "DWord"
            &$registryTweak -Path $base -Name "TaskbarSizeMove" -Value 1 -Type "DWord"
            &$registryTweak -Path $base -Name "MMTaskbarEnabled" -Value 0 -Type "DWord"
            &$registryTweak -Path $base -Name "StoreAppsOnTaskbar" -Value 0 -Type "DWord"
        } else {
            &$registryTweak -Path $base -Name "TaskbarNoMultimon" -Value 0 -Type "DWord"
        }
    }
    # Hide Windows 11 Taskbar Search Box
    foreach ($p in $searchPaths) {
        &$registryTweak -Path $p -Name "SearchboxTaskbarMode" -Value 0 -Type "DWord"
        &$registryTweak -Path $p -Name "SearchboxTaskbarModeCache" -Value 0 -Type "DWord"
    }
    # Thumbs.db
    &$registryTweak -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "DisableThumbnailsOnNetworkFolders" -Value 1 -Type "DWord"

    # Hide taskbar StuckRects3 Settings
    $stuckPaths = @("Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3")
    if (Test-Path "Registry::HKEY_USERS\DefaultUser") {
        $stuckPaths += "Registry::HKEY_USERS\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3"
    }
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
