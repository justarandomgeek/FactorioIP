param (
    [parameter(Position=0, Mandatory=$true)]
    [string] $Tag,
    [string] $InfoPath = "config/buildinfo.json",
    [string] $SourceFolder = "src",
    [string] $OutputPath = ""
)

# check for $Tag
#$tags = git tag

# if ([string]::IsNullOrWhiteSpace($Tag) -or [string]::IsNullOrWhiteSpace($tags) -or -not ($tags.split([Environment]::NewLine) -contains $Tag))
# {
#     Write-Output "Specified tag does not exist."
#     exit
# }

$buildInfo = Get-Content "$InfoPath"| ConvertFrom-Json

$buildInfo.info.version = $Tag

$ReleaseName = $buildInfo.info.name + "_" + $buildInfo.info.version

Write-Output "Making Temp Directory: $ReleaseName"
mkdir "$ReleaseName"

Write-Output "Copying files to temp location"
Copy-Item -Path "$SourceFolder\*" -Recurse -Destination "$ReleaseName"
$Control = $ReleaseName + "\control.lua"
(Get-Content $Control).replace("DEBUG = true", "DEBUG = false") | Set-Content $Control
ConvertTo-Json $buildInfo.info | % { [System.Text.RegularExpressions.Regex]::Unescape($_) } | Set-Content "$ReleaseName\info.json"
Write-Output "Removing Previous Zip File"

if (Test-Path "$ReleaseName.zip") 
{
    Remove-Item -Path "$ReleaseName.zip"
}

Write-Output "Making Zip File"
& 'C:\Program Files\7-Zip\7z.exe' a "$ReleaseName.zip" "$ReleaseName"

Remove-Item $ReleaseName -Recurse