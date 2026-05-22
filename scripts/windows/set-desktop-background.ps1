[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [Object]$Config,
    [Switch]$DryRun,
    [Switch]$Undo
)

$bgConfig = $Config.lockdown.solidColorBackground
$shouldUndo = $Undo -or ($null -eq $bgConfig) -or ($bgConfig -eq $false)

$rgbColor = "0 0 0"
if ($bgConfig -eq $true) {
    $rgbColor = "0 0 0"
} elseif ($bgConfig -match '^#([A-Fa-f0-9]{6})$') {
    $cleanHex = $bgConfig.Replace("#", "")
    $r = [System.Convert]::ToInt32($cleanHex.Substring(0, 2), 16)
    $g = [System.Convert]::ToInt32($cleanHex.Substring(2, 2), 16)
    $b = [System.Convert]::ToInt32($cleanHex.Substring(4, 2), 16)
    $rgbColor = "$r $g $b"
}

$registryTweak = {
    Param([String]$Path, [String]$Name, [Object]$Value, [String]$Type, [Switch]$Remove, [Switch]$DryRun)
    & "$PSScriptRoot/../../src/powershell/utils/slab-set-registry.ps1" -Path $Path -Name $Name -Value $Value -PropertyType $Type -Remove:$Remove -DryRun:$DryRun
}

$userWallpapersPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers"
$userColorsPath = "HKCU:\Control Panel\Colors"
$userDesktopPath = "HKCU:\Control Panel\Desktop"

if ($shouldUndo) {
    Write-Host "Restoring default desktop background settings..." -ForegroundColor Cyan
    
    &$registryTweak -Path $userColorsPath -Name "Background" -Value "0 120 215" -Type "String" -DryRun:$DryRun
    &$registryTweak -Path $userDesktopPath -Name "Wallpaper" -Remove -DryRun:$DryRun
    &$registryTweak -Path $userWallpapersPath -Name "BackgroundType" -Value 0 -Type "DWord" -DryRun:$DryRun

    if (Test-Path "HKU:\DefaultUser") {
        &$registryTweak -Path "HKU:\DefaultUser\Control Panel\Colors" -Name "Background" -Value "0 120 215" -Type "String" -DryRun:$DryRun
        &$registryTweak -Path "HKU:\DefaultUser\Control Panel\Desktop" -Name "Wallpaper" -Remove -DryRun:$DryRun
        &$registryTweak -Path "HKU:\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers" -Name "BackgroundType" -Value 0 -Type "DWord" -DryRun:$DryRun
    }
} else {
    Write-Host "Setting desktop background to solid color ($rgbColor)..." -ForegroundColor Cyan
    
    &$registryTweak -Path $userColorsPath -Name "Background" -Value $rgbColor -Type "String" -DryRun:$DryRun
    &$registryTweak -Path $userDesktopPath -Name "Wallpaper" -Value "" -Type "String" -DryRun:$DryRun
    &$registryTweak -Path $userWallpapersPath -Name "BackgroundType" -Value 1 -Type "DWord" -DryRun:$DryRun

    if (Test-Path "HKU:\DefaultUser") {
        &$registryTweak -Path "HKU:\DefaultUser\Control Panel\Colors" -Name "Background" -Value $rgbColor -Type "String" -DryRun:$DryRun
        &$registryTweak -Path "HKU:\DefaultUser\Control Panel\Desktop" -Name "Wallpaper" -Value "" -Type "String" -DryRun:$DryRun
        &$registryTweak -Path "HKU:\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers" -Name "BackgroundType" -Value 1 -Type "DWord" -DryRun:$DryRun
    }
}

if (!$DryRun) {
    try {
        if (-not ("SlabWin32.Win32SystemParametersInfoBackground" -as [type])) {
            $sig = '[DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);'
            Add-Type -MemberDefinition $sig -Name "Win32SystemParametersInfoBackground" -Namespace "SlabWin32" -ErrorAction SilentlyContinue | Out-Null
        }
        [SlabWin32.Win32SystemParametersInfoBackground]::SystemParametersInfo(0x0014, 0, "", 3) | Out-Null
        Write-Host "Triggered active session desktop background refresh." -ForegroundColor Green
    } catch {
        Write-Warning "Could not refresh desktop background via Win32 API: $_"
    }
}
