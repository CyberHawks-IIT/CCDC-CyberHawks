<#
.SYNOPSIS
Health check for Windows Server 2019 Web (IIS)

.DESCRIPTION
Checks IIS services, site status, HTTP responsiveness, and web root content.
#>

param(
    [string]$WebRoot = "C:\inetpub\wwwroot",
    [string]$SiteName = "Default Web Site",
    [int]$Port = 80
)

function New-Result {
    param($Check, $Target, $Status, $Details)
    [PSCustomObject]@{
        Check   = $Check
        Target  = $Target
        Status  = $Status
        Details = $Details
    }
}

$results = @()

# Services
$serviceNames = @("W3SVC", "WAS")
foreach ($svc in $serviceNames) {
    $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if (-not $service) {
        $results += New-Result "Service" $svc "FAIL" "Not found"
        continue
    }
    $status = if ($service.Status -eq "Running") { "OK" } else { "FAIL" }
    $results += New-Result "Service" $svc $status $service.Status
}

# Site status (IIS)
try {
    Import-Module WebAdministration -ErrorAction Stop
    $site = Get-Website -Name $SiteName -ErrorAction Stop
    $status = if ($site.State -eq "Started") { "OK" } else { "FAIL" }
    $results += New-Result "IIS Site" $SiteName $status $site.State
} catch {
    $results += New-Result "IIS Site" $SiteName "WARN" "WebAdministration module not available"
}

# Web root content
if (Test-Path $WebRoot) {
    $hasIndex = Test-Path (Join-Path $WebRoot "index.html") -PathType Leaf -ErrorAction SilentlyContinue
    $hasIndex = $hasIndex -or (Test-Path (Join-Path $WebRoot "index.htm") -PathType Leaf -ErrorAction SilentlyContinue)
    $status = if ($hasIndex) { "OK" } else { "WARN" }
    $details = if ($hasIndex) { "index file present" } else { "index.html/index.htm not found" }
    $results += New-Result "WebRoot" $WebRoot $status $details
} else {
    $results += New-Result "WebRoot" $WebRoot "FAIL" "Path not found"
}

# Port listening
try {
    $listening = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction Stop
    $results += New-Result "Port" "localhost:$Port" "OK" "Listening"
} catch {
    $results += New-Result "Port" "localhost:$Port" "FAIL" "Not listening"
}

# HTTP request
try {
    $resp = Invoke-WebRequest -Uri ("http://localhost:{0}/" -f $Port) -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    $status = if ($resp.StatusCode -eq 200) { "OK" } else { "WARN" }
    $results += New-Result "HTTP" "GET /" $status ("StatusCode {0}" -f $resp.StatusCode)
} catch {
    $results += New-Result "HTTP" "GET /" "FAIL" $_.Exception.Message
}

$results | Format-Table -AutoSize

$fails = $results | Where-Object { $_.Status -eq "FAIL" }
if ($fails.Count -gt 0) {
    Write-Host "`nHealth check: FAIL ($($fails.Count) issues)" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`nHealth check: OK" -ForegroundColor Green
    exit 0
}
