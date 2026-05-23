function Backup-ZiptieUtilities {
    param([string]$utilsDir)
    $projectRoot = Split-Path (Split-Path $utilsDir -Parent) -Parent
    $backupDir = "$projectRoot/.tmp"
    if (![System.IO.Directory]::Exists($backupDir)) {
        [System.IO.Directory]::CreateDirectory($backupDir) | Out-Null
    }
    $utilsBackupPath = "$backupDir/utils-backup"
    if (![System.IO.Directory]::Exists($utilsBackupPath)) {
        [System.IO.Directory]::CreateDirectory($utilsBackupPath) | Out-Null
    }

    [Console]::WriteLine("--- BACKUP-ZIPTIEUTILITIES STARTING ---")
    $files = [System.IO.Directory]::GetFiles($utilsDir, "*.ps1")
    foreach ($file in $files) {
        $fileName = [System.IO.Path]::GetFileName($file)
        $size = (New-Object System.IO.FileInfo($file)).Length
        [Console]::WriteLine("Backing up utility: $fileName (Size: $size bytes)")
        
        $backupDest = [System.IO.Path]::Combine($utilsBackupPath, $fileName)
        [System.IO.File]::Copy($file, $backupDest, $true)
        
        # Replace utility with a benign silent stub, except ziptie-init.ps1
        if ($fileName -ne "ziptie-init.ps1") {
            if ([System.IO.File]::Exists($file)) {
                [System.IO.File]::SetAttributes($file, [System.IO.FileAttributes]::Normal)
            }
            [System.IO.File]::WriteAllText($file, "Param([Switch]`$DryRun)")
        }
    }
}

function Restore-ZiptieUtilities {
    param([string]$utilsDir)
    $projectRoot = Split-Path (Split-Path $utilsDir -Parent) -Parent
    $utilsBackupPath = "$projectRoot/.tmp/utils-backup"
    if ([System.IO.Directory]::Exists($utilsDir) -and [System.IO.Directory]::Exists($utilsBackupPath)) {
        [Console]::WriteLine("--- RESTORE-ZIPTIEUTILITIES STARTING ---")
        $backupFiles = [System.IO.Directory]::GetFiles($utilsBackupPath, "*.ps1")
        foreach ($bf in $backupFiles) {
            $fileName = [System.IO.Path]::GetFileName($bf)
            $size = (New-Object System.IO.FileInfo($bf)).Length
            [Console]::WriteLine("Restoring backup file: $fileName (Size: $size bytes)")
            
            $destPath = [System.IO.Path]::Combine($utilsDir, $fileName)
            if ([System.IO.File]::Exists($destPath)) {
                [System.IO.File]::SetAttributes($destPath, [System.IO.FileAttributes]::Normal)
            }
            [System.IO.File]::Copy($bf, $destPath, $true)
        }
        
        [Console]::WriteLine("Attempting to delete backup folder: $utilsBackupPath")
        [System.IO.Directory]::Delete($utilsBackupPath, $true)
    } else {
        [Console]::WriteLine("Restore-ZiptieUtilities skipped! Backup path exists: $([System.IO.Directory]::Exists($utilsBackupPath))")
    }
}
