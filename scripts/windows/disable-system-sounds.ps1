[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)] [Object]$Config,
    [Switch]$DryRun, [Switch]$Undo
)

. "$PSScriptRoot/../utils/slab-init.ps1"

$tweakEnabled = $Config.lockdown.disableSystemSounds
$shouldUndo = $Undo -or !$tweakEnabled

# Define paths to modify. Both HKCU and the Default User Hive (if mounted) are checked.
$hivePaths = @("Registry::HKEY_CURRENT_USER")
if (Test-Path "Registry::HKEY_USERS\DefaultUser") {
    $hivePaths += "Registry::HKEY_USERS\DefaultUser"
}

if ($shouldUndo) {
    Write-Host "Restoring default system sounds..." -ForegroundColor Cyan
} else {
    Write-Host "Disabling system sounds (muting all audio feedback)..." -ForegroundColor Cyan
}

foreach ($hive in $hivePaths) {
    $schemesPath = "$hive\AppEvents\Schemes"
    if (!(Test-Path $schemesPath)) { continue }

    # 1. Configure the primary sound scheme
    $schemeValue = if ($shouldUndo) { ".Default" } else { ".None" }
    &$registryTweak -Path $schemesPath -Name "(Default)" -Value $schemeValue -Type "String"

    # 2. Iterate and update individual sound events under AppEvents\Schemes\Apps
    $appsPath = "$schemesPath\Apps"
    if (Test-Path $appsPath) {
        $events = Get-ChildItem -Path $appsPath -Recurse | Where-Object { $_.PSChildName -eq ".Current" }
        foreach ($event in $events) {
            # $event.Name contains relative path from Schemes (e.g. "Apps\.Default\SystemAsterisk\.Current")
            $fullCurrentPath = "$schemesPath\$($event.Name)"
            $fullDefaultPath = $fullCurrentPath -replace "\.Current$", ".Default"

            if ($shouldUndo) {
                # Restore to the default value defined in the .Default sibling key
                $defaultValue = (Get-Item -Path $fullDefaultPath -ErrorAction SilentlyContinue).GetValue("")
                if ($defaultValue -eq $null) { $defaultValue = "" }

                if ($DryRun) {
                    Write-Host "[DRY-RUN] Set-ItemProperty -Path '$fullCurrentPath' -Name '(Default)' -Value '$defaultValue'" -ForegroundColor Yellow
                } else {
                    Set-ItemProperty -Path $fullCurrentPath -Name "(Default)" -Value $defaultValue -Force -ErrorAction SilentlyContinue
                }
            } else {
                # Mute by setting the active sound file value to empty
                if ($DryRun) {
                    Write-Host "[DRY-RUN] Set-ItemProperty -Path '$fullCurrentPath' -Name '(Default)' -Value ''" -ForegroundColor Yellow
                } else {
                    Set-ItemProperty -Path $fullCurrentPath -Name "(Default)" -Value "" -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}
