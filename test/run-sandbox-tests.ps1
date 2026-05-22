# Set console colors
$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "White"
Clear-Host

Write-Host "==========================================================" -ForegroundColor Green
Write-Host "         SLAB AUTOMATED SANDBOX INTEGRATION TESTS          " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "Starting Slab configuration script in the sandbox..." -ForegroundColor Cyan

Write-Host "`nExecuting Slab in active modification mode (running changes live)..." -ForegroundColor Cyan
& "C:\slab\slab.ps1" -ConfigPath "C:\slab\slab-config.json"
Write-Host "Slab execution finished. Verifying system state..." -ForegroundColor Cyan

$success = $true

function Assert-Registry {
    Param([String]$Path, [String]$Name, [Object]$ExpectedValue, [Switch]$AllowUcpdFallback)
    Write-Host "Asserting registry property '$Name' at '$Path'..." -NoNewline
    $val = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    if ($val -and $val.$Name -eq $ExpectedValue) {
        Write-Host " OK (Value: $ExpectedValue)" -ForegroundColor Green
    } else {
        $gotValue = 'Not Found'
        if ($null -ne $val) {
            $gotValue = $val.$Name
        }
        if ($AllowUcpdFallback) {
            Write-Host " WARNING (Expected: $ExpectedValue, Got: $gotValue - Ignored due to UCPD protection)" -ForegroundColor Yellow
        } else {
            Write-Host " FAILED (Expected: $ExpectedValue, Got: $gotValue)" -ForegroundColor Red
            $global:success = $false
        }
    }
}

function Assert-ScheduledTask {
    Param([String]$TaskName, [String]$TaskPath)
    Write-Host "Asserting Scheduled Task '$TaskName' at '$TaskPath'..." -NoNewline
    $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction SilentlyContinue
    if ($task) {
        Write-Host " OK" -ForegroundColor Green
    } else {
        Write-Host " FAILED (Not Found)" -ForegroundColor Red
        $global:success = $false
    }
}

Write-Host "`n--- SYSTEM STATE VERIFICATIONS ---" -ForegroundColor Yellow

Assert-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" -Name "AllowNewsAndInterests" -ExpectedValue 0
Assert-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" -Name "EnableFeeds" -ExpectedValue 0
Assert-Registry -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -ExpectedValue 0 -AllowUcpdFallback

Assert-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -ExpectedValue 1
Assert-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -ExpectedValue 2
Assert-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "ExcludeWUDriversInQualityUpdate" -ExpectedValue 1

Assert-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI" -Name "AllowEdgeSwipe" -ExpectedValue 0

Assert-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -ExpectedValue 1
Assert-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis" -ExpectedValue 1
Assert-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "TargetReleaseVersion" -ExpectedValue 1
Assert-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "ConfigureStartPins" -ExpectedValue '{"pinnedList":[]}'

Assert-ScheduledTask -TaskName "SlabExhibitLaunch" -TaskPath "\Slab\"



Write-Host "Asserting Copilot policy removed..." -NoNewline
$copilotVal = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" -Name "TurnOffWindowsCopilot" -ErrorAction SilentlyContinue
if (!$copilotVal) { Write-Host " OK" -ForegroundColor Green } else { Write-Host " FAILED (Still exists)" -ForegroundColor Red; $success = $false }

Write-Host "Asserting Windows AI Recall policy removed..." -NoNewline
$aiVal = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" -Name "DisableAIDataAnalysis" -ErrorAction SilentlyContinue
if (!$aiVal) { Write-Host " OK" -ForegroundColor Green } else { Write-Host " FAILED (Still exists)" -ForegroundColor Red; $success = $false }

Write-Host "Asserting Start Menu Pins policy removed..." -NoNewline
$pinsVal = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" -Name "ConfigureStartPins" -ErrorAction SilentlyContinue
if (!$pinsVal) { Write-Host " OK" -ForegroundColor Green } else { Write-Host " FAILED (Still exists)" -ForegroundColor Red; $success = $false }

Write-Host "Asserting Windows Update TargetRelease policy removed..." -NoNewline
$trVal = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "TargetReleaseVersion" -ErrorAction SilentlyContinue
if (!$trVal) { Write-Host " OK" -ForegroundColor Green } else { Write-Host " FAILED (Still exists)" -ForegroundColor Red; $success = $false }

Write-Host "`n==========================================================" -ForegroundColor Yellow
if ($success) {
    Write-Host "          ALL SANDBOX TESTS PASSED SUCCESSFULLY!          " -ForegroundColor Green
} else {
    Write-Host "          SANDBOX INTEGRATION TESTS ENCOUNTERED FAILURES! " -ForegroundColor Red
}
Write-Host "==========================================================" -ForegroundColor Yellow

Write-Host "`nYou can now perform manual spot-checks in this Sandbox window." -ForegroundColor Gray
Write-Host "Press any key to exit..."
[void][System.Console]::ReadKey($true)
