# Set console colors
$Host.UI.RawUI.BackgroundColor = "Black"
$Host.UI.RawUI.ForegroundColor = "White"
Clear-Host

Write-Host "==========================================================" -ForegroundColor Green
Write-Host "         SLAB AUTOMATED SANDBOX INTEGRATION TESTS          " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "Starting Slab configuration script in the sandbox..." -ForegroundColor Cyan

Write-Host "`n[TEST 1] Executing Slab in DRY-RUN mode..." -ForegroundColor Cyan
& "C:\slab\slab.ps1" -ConfigPath "C:\slab\slab-config.json" -DryRun
if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
    Write-Host "FAILED: Dry-run execution encountered errors." -ForegroundColor Red
    Exit 1
}
Write-Host "SUCCESS: Dry-run finished with no errors." -ForegroundColor Green

Write-Host "`n[TEST 2] Executing Slab in active modification mode..." -ForegroundColor Cyan
& "C:\slab\slab.ps1" -ConfigPath "C:\slab\slab-config.json"
Write-Host "Slab execution finished. Verifying system state..." -ForegroundColor Cyan

$success = $true

function Assert-Registry {
    Param([String]$Path, [String]$Name, [Object]$ExpectedValue)
    Write-Host "Asserting registry property '$Name' at '$Path'..." -NoNewline
    $val = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    if ($val -and $val.$Name -eq $ExpectedValue) {
        Write-Host " OK (Value: $ExpectedValue)" -ForegroundColor Green
    } else {
        Write-Host " FAILED (Expected: $ExpectedValue, Got: $($val ? $val.$Name : 'Not Found'))" -ForegroundColor Red
        $global:success = $false
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
Assert-Registry -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -ExpectedValue 0

Assert-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -ExpectedValue 1
Assert-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -ExpectedValue 2
Assert-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "ExcludeWUDriversInQualityUpdate" -ExpectedValue 1

Assert-Registry -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI" -Name "AllowEdgeSwipe" -ExpectedValue 0

Assert-ScheduledTask -TaskName "SlabExhibitLaunch" -TaskPath "\Slab\"

Write-Host "`n[TEST 3] Running Slab in UNDO mode..." -ForegroundColor Cyan
& "C:\slab\slab.ps1" -ConfigPath "C:\slab\slab-config.json" -Undo
Write-Host "Undo complete. Verifying system state restored..." -ForegroundColor Cyan

Write-Host "Asserting Scheduled Task 'SlabExhibitLaunch' removed..." -NoNewline
$task = Get-ScheduledTask -TaskName "SlabExhibitLaunch" -TaskPath "\Slab\" -ErrorAction SilentlyContinue
if (!$task) {
    Write-Host " OK (Removed)" -ForegroundColor Green
} else {
    Write-Host " FAILED (Still exists)" -ForegroundColor Red
    $success = $false
}

Assert-Registry -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -ExpectedValue 1

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
