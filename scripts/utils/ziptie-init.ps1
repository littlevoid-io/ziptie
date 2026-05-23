# Common initializer for Ziptie lockdown scripts

$script:ziptieDryRun = $DryRun
$ziptieRegistryHelper = "$PSScriptRoot/ziptie-set-registry.ps1"

$registryTweak = {
    Param([String]$Path, [String]$Name, [Object]$Value, [String]$Type, [Switch]$Remove)
    & $ziptieRegistryHelper -Path $Path -Name $Name -Value $Value -PropertyType $Type -Remove:$Remove -DryRun:$script:ziptieDryRun
}
