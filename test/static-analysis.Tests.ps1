function Get-AnalysisPaths {
    $scriptsPath = "$PSScriptRoot/../scripts/windows"
    if (!(Test-Path $scriptsPath)) { $scriptsPath = "./scripts/windows" }
    $scriptsDir = (Resolve-Path $scriptsPath).Path

    $utilsPath = "$PSScriptRoot/../scripts/utils"
    if (!(Test-Path $utilsPath)) { $utilsPath = "./scripts/utils" }
    $utilsDir = (Resolve-Path $utilsPath).Path

    return @{ ScriptsDir = $scriptsDir; UtilsDir = $utilsDir }
}

Describe "Ziptie Static Analysis" {
    Context "Static Analysis & Architecture Guidelines" {
        It "Should strictly cap every script under 100 lines of code" {
            $paths = Get-AnalysisPaths
            $scripts = Get-ChildItem -Path $paths.ScriptsDir -Filter "*.ps1" -Recurse
            $utils = Get-ChildItem -Path $paths.UtilsDir -Filter "*.ps1"
            
            foreach ($script in ($scripts + $utils)) {
                $lines = @(Get-Content -Path $script.FullName)
                $count = $lines.Count
                if ($count -ge 100) {
                    throw "Script '$($script.Name)' failed the line cap check: it has $count lines (exceeds 100 limit)! Path: $($script.FullName)"
                }
            }
        }

        It "Should not contain hardcoded plain-text passwords or secrets" {
            $paths = Get-AnalysisPaths
            $scripts = Get-ChildItem -Path $paths.ScriptsDir -Filter "*.ps1" -Recurse
            $utils = Get-ChildItem -Path $paths.UtilsDir -Filter "*.ps1"
            
            foreach ($script in ($scripts + $utils)) {
                $content = Get-Content -Raw -Path $script.FullName
                if ($null -ne $content -and $content -ne "") {
                    if ($content -match "password\s*=\s*'[^']+'" -or $content -match 'password\s*=\s*"[^"]+"') {
                        throw "Script '$($script.Name)' failed the secrets check: it contains a hardcoded password/secret! Path: $($script.FullName)"
                    }
                }
            }
        }
    }
}
