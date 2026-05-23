Param(
    [Parameter(Mandatory=$true)]
    [String]$PackageName,
    [Switch]$DryRun
)

Write-Host "Searching for AppX packages matching '$PackageName'..." -ForegroundColor Cyan
$packages = Get-AppxPackage -AllUsers -Name $PackageName -ErrorAction SilentlyContinue

if (!$packages) {
    Write-Host "No packages matching '$PackageName' found." -ForegroundColor Gray
    return
}

foreach ($pkg in $packages) {
    if ($DryRun) {
        Write-Host "[DRY-RUN] Remove-AppxPackage -AllUsers -Package '$($pkg.PackageFullName)'" -ForegroundColor Yellow
    } else {
        Write-Host "Removing package '$($pkg.PackageFullName)' for all users..." -ForegroundColor Cyan
        Remove-AppxPackage -AllUsers -Package $pkg.PackageFullName -ErrorAction SilentlyContinue
        
        $prov = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq $pkg.Name }
        if ($prov) {
            Write-Host "Removing provisioned package '$($prov.DisplayName)'..." -ForegroundColor Cyan
            Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction SilentlyContinue
        }
    }
}
