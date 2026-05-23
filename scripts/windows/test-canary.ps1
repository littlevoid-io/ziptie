[CmdletBinding()]
Param([Switch]$DryRun)

if ($DryRun) {
    Write-Host "[DRY-RUN] Would create canary file"
} else {
    # Benign action: create a temporary file in the workspace .tmp folder
    New-Item -Path "$PSScriptRoot/../../.tmp/canary-file.txt" -ItemType "File" -Force | Out-Null
}
