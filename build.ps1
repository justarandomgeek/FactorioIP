param (
    [Alias('v')]
    [string] $Version,
    [switch] $NoClean,
    [switch] $NoPublish,
    [string] $InfoPath = "config/buildinfo.json",
    [string] $SourceFolder = "src"
)

$buildInfo = Get-Content "$InfoPath" -Encoding ASCII| ConvertFrom-Json

if (-not [string]::IsNullOrWhiteSpace($Version))
{
    $buildInfo.info.version = $Version
}

$resolvedPath = Resolve-Path $buildInfo.output_directory
$modsDir = $resolvedPath.ToString()

if(!$NoClean) {
    $glob = "$modsDir\" + $buildInfo.info.name + "_*"
    $oldDirs = Get-ChildItem -Path $glob -Name
    foreach ($dir in $oldDirs)
    {
        Remove-Item "$modsDir\$dir" -Recurse
    }
}

if (!$NoPublish) {
    $newDir = "$modsDir\" + $buildInfo.info.name + "_" + $buildInfo.info.version
    Write-Output "$newDir"
    Copy-Item -Path "$SourceFolder" -Recurse -Destination "$newDir"
    ConvertTo-Json $buildInfo.info | % { [System.Text.RegularExpressions.Regex]::Unescape($_) } | Set-Content "$newDir\info.json" -Encoding UTF8
}