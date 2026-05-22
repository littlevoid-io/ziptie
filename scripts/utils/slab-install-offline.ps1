[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [String]$LocalPath,
    [Switch]$DryRun,
    [String]$RunRoot
)

$absolutePath = $LocalPath
if (!(Split-Path -Path $LocalPath -IsAbsolute)) {
    $absolutePath = Join-Path -Path $RunRoot -ChildPath $LocalPath
}

if (!(Test-Path $absolutePath)) {
    Write-Host "Offline fallback enabled but installers directory not found: $absolutePath" -ForegroundColor Yellow
    return
}

Write-Host "Scanning local installers folder '$absolutePath'..." -ForegroundColor Cyan
$installers = Get-ChildItem -Path $absolutePath -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '^\.(msi|exe)$' }

if (!$installers) {
    Write-Host "No local installer files (.msi or .exe) found in '$absolutePath'." -ForegroundColor Gray
    return
}

foreach ($file in $installers) {
    $filePath = $file.FullName
    $ext = $file.Extension.ToLower()

    if ($ext -eq ".msi") {
        if ($DryRun) {
            Write-Host "[DRY-RUN] msiexec.exe /i '$filePath' /qn /norestart" -ForegroundColor Yellow
        } else {
            Write-Host "Installing MSI '$($file.Name)' silently..." -ForegroundColor Cyan
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$filePath`" /qn /norestart" -Wait -NoNewWindow
            Write-Host "Finished installing '$($file.Name)'." -ForegroundColor Green
        }
    } elseif ($ext -eq ".exe") {
        $args = "/S"
        if ($file.Name -like "*node*") { $args = "/quiet" }
        elseif ($file.Name -like "*git*") { $args = "/VERYSILENT /NORESTART /NOCANCEL /SP-" }
        
        if ($DryRun) {
            Write-Host "[DRY-RUN] Start-Process -FilePath '$filePath' -ArgumentList '$args'" -ForegroundColor Yellow
        } else {
            Write-Host "Installing EXE '$($file.Name)' silently with args '$args'..." -ForegroundColor Cyan
            Start-Process -FilePath $filePath -ArgumentList $args -Wait -NoNewWindow
            Write-Host "Finished installing '$($file.Name)'." -ForegroundColor Green
        }
    }
}
