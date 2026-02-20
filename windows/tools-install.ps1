<#
.SYNOPSIS
Download common tools to C:\Tools

.DESCRIPTION
Creates C:\Tools if missing and downloads Sysinternals, Wireshark, and Firefox installers.
#>

$toolsDir = "C:\Tools"
if (!(Test-Path $toolsDir)) {
    New-Item -ItemType Directory -Path $toolsDir | Out-Null
}

$downloads = @{
    "Sysinternals" = "https://download.sysinternals.com/files/SysinternalsSuite.zip"
    "Wireshark"    = "https://2.na.dl.wireshark.org/win64/Wireshark-latest-x64.exe"
    "Firefox"      = "https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=en-US"
}

foreach ($name in $downloads.Keys) {
    Write-Host "Downloading $name..."
    $ext = if ($downloads[$name] -like "*.zip*") { ".zip" } else { ".exe" }
    Invoke-WebRequest -Uri $downloads[$name] -OutFile (Join-Path $toolsDir "$name$ext")
}
