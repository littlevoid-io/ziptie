# Common initializer for Slab lockdown scripts

$slabRegistryHelper = "$PSScriptRoot/slab-set-registry.ps1"

$registryTweak = {
    Param([String]$Path, [String]$Name, [Object]$Value, [String]$Type, [Switch]$Remove)
    & $slabRegistryHelper -Path $Path -Name $Name -Value $Value -PropertyType $Type -Remove:$Remove -DryRun:$DryRun
}
