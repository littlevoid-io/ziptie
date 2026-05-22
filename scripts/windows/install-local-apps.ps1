[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

if ($Undo) {
    Write-Host "Automatic uninstall is not supported for package installations. Please manage app removals manually." -ForegroundColor Yellow
    return
}

$provider = $Config.packageManager.provider
$allowOffline = $Config.packageManager.allowOfflineFallback
$localPath = $Config.packageManager.localInstallersPath
$apps = $Config.packageManager.apps

$isOnline = $false
try {
    $ping = New-Object System.Net.NetworkInformation.Ping
    $reply = $ping.Send("1.1.1.1", 1000)
    if ($reply.Status -eq "Success") { $isOnline = $true }
} catch {}

if ($provider -eq "winget" -and $isOnline) {
    Write-Host "System is online. Installing apps via Winget..." -ForegroundColor Cyan
    foreach ($app in $apps) {
        if ($DryRun) {
            Write-Host "[DRY-RUN] winget install --id '$app' --silent --accept-source-agreements --accept-package-agreements" -ForegroundColor Yellow
        } else {
            Write-Host "Installing '$app' via Winget..." -ForegroundColor Cyan
            & winget install --id $app --silent --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Successfully installed '$app'." -ForegroundColor Green
            } else {
                Write-Warning "Winget failed to install '$app'. Exit code: $LASTEXITCODE"
            }
        }
    }
} elseif ($allowOffline) {
    $absolutePath = $localPath
    if (!(Split-Path -Path $localPath -IsAbsolute)) {
        $absolutePath = Join-Path -Path $PSScriptRoot -ChildPath "../../$localPath"
    }
    
    if (!(Test-Path $absolutePath)) {
        Write-Host "Offline fallback enabled but installers directory not found: $absolutePath" -ForegroundColor Yellow
        return
    }

    Write-Host "Scanning local installers folder '$absolutePath'..." -ForegroundColor Cyan
    $installers = Get-ChildItem -Path $absolutePath -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -match '^\.(msi|exe)$' }

    if (!$installers) {
        Write-Host "No local installer files (.msi or .exe) found." -ForegroundColor Gray
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
} else {
    Write-Host "Skipping package installations (provider is none, or system is offline with fallback disabled)." -ForegroundColor Gray
}
