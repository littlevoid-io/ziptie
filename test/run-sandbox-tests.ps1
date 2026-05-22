# Set UTF-8 encoding
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$slabRoot = Resolve-Path "$PSScriptRoot/.."

Clear-Host
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "         SLAB AUTOMATED SANDBOX INTEGRATION TESTS          " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "`nExecuting Slab in active modification mode..." -ForegroundColor Cyan
& "$slabRoot\dist\slab.exe" -c "$slabRoot\slab.default.config.json" -y
Write-Host "Slab execution finished. Verifying system state..." -ForegroundColor Cyan

$success = $true
function Assert-Registry {
    Param([String]$Path, [String]$Name, [Object]$ExpectedValue, [Switch]$AllowUcpdFallback)
    Write-Host "Asserting registry property '$Name' at '$Path'..." -NoNewline
    $val = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    if ($val -and $val.$Name -eq $ExpectedValue) {
        Write-Host " OK (Value: $ExpectedValue)" -ForegroundColor Green
    } else {
        $got = if ($val) { $val.$Name } else { 'Not Found' }
        if ($AllowUcpdFallback) { Write-Host " WARNING (Expected: $ExpectedValue, Got: $got - UCPD protected)" -ForegroundColor Yellow }
        else { Write-Host " FAILED (Expected: $ExpectedValue, Got: $got)" -ForegroundColor Red; $global:success = $false }
    }
}
function Assert-ScheduledTask {
    Param([String]$TaskName, [String]$TaskPath)
    Write-Host "Asserting Scheduled Task '$TaskName' at '$TaskPath'..." -NoNewline
    if (Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction SilentlyContinue) {
        Write-Host " OK" -ForegroundColor Green
    } else { Write-Host " FAILED (Not Found)" -ForegroundColor Red; $global:success = $false }
}

$config = Get-Content -Raw -Path "$slabRoot\slab.default.config.json" | ConvertFrom-Json
Write-Host "`n--- SYSTEM STATE VERIFICATIONS ---" -ForegroundColor Yellow

if ($config.lockdown.disableWindowsWidgets) {
    Assert-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -ExpectedValue 0
    Assert-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" -Name "EnableFeeds" -ExpectedValue 0
    Assert-Registry -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -ExpectedValue 0 -AllowUcpdFallback
}
if ($config.lockdown.disableWindowsUpdate) {
    Assert-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -ExpectedValue 1
    Assert-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -ExpectedValue 2
    Assert-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "ExcludeWUDriversInQualityUpdate" -ExpectedValue 1
    Assert-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "TargetReleaseVersion" -ExpectedValue 1
}
if ($config.lockdown.disableEdgeSwipes) {
    Assert-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI" -Name "AllowEdgeSwipe" -ExpectedValue 0
}
if ($config.lockdown.disableCopilotRecall) {
    Assert-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -ExpectedValue 1
    Assert-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis" -ExpectedValue 1
}
if ($config.lockdown.configureExplorer) {
    Assert-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "ConfigureStartPins" -ExpectedValue '{"pinnedList":[]}'
    Assert-Registry -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -ExpectedValue 0
}
if ($config.lockdown.clearDesktopIcons) {
    Assert-Registry -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideIcons" -ExpectedValue 1
}
if ($config.startupTask.enabled) { Assert-ScheduledTask -TaskName "Launch Exhibit" -TaskPath "\Slab\" }
if ($config.system.timezone -eq "auto") {
    Assert-Registry -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -ExpectedValue "Allow"
}

# Dynamic Background
$bg = $config.lockdown.solidColorBackground
if ($null -ne $bg -and $bg -ne $false) {
    $rgb = "0 0 0"
    if ($bg -match '^#([A-Fa-f0-9]{6})$') {
        $c = $bg.Replace("#", "")
        $rgb = "$([System.Convert]::ToInt32($c.Substring(0, 2), 16)) $([System.Convert]::ToInt32($c.Substring(2, 2), 16)) $([System.Convert]::ToInt32($c.Substring(4, 2), 16))"
    }
    Assert-Registry -Path "HKCU:\Control Panel\Colors" -Name "Background" -ExpectedValue $rgb
    Assert-Registry -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers" -Name "BackgroundType" -ExpectedValue 1
}
if ($config.lockdown.enableDarkMode) {
    Assert-Registry -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -ExpectedValue 0
    Assert-Registry -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -ExpectedValue 0
}
if ($config.lockdown.setPowerSettings) {
    Write-Host "Asserting active power scheme..." -NoNewline
    if ((powercfg /getactivescheme) -match "77777777-7777-7777-7777-777777777777") {
        Write-Host " OK (Active Scheme: Exhibit Power Scheme)" -ForegroundColor Green
    } else { Write-Host " FAILED" -ForegroundColor Red; $global:success = $false }
}

Write-Host "`n==========================================================" -ForegroundColor Yellow
if ($success) { Write-Host "          ALL SANDBOX TESTS PASSED SUCCESSFULLY!          " -ForegroundColor Green }
else { Write-Host "          SANDBOX INTEGRATION TESTS ENCOUNTERED FAILURES! " -ForegroundColor Red }
Write-Host "==========================================================`nYou can now perform manual spot-checks. Press any key to exit..."
[void][System.Console]::ReadKey($true)
