<#
.SYNOPSIS
Health check for Windows Server 2022 FTP (IIS FTP)

.DESCRIPTION
Checks FTP services, FTP site state, and port 21 availability.
#>

param(
    [int]$Port = 21
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
$serviceNames = @("FTPSVC", "W3SVC", "WAS")
foreach ($svc in $serviceNames) {
    $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if (-not $service) {
        $results += New-Result "Service" $svc "FAIL" "Not found"
        continue
    }
    $status = if ($service.Status -eq "Running") { "OK" } else { "FAIL" }
    $results += New-Result "Service" $svc $status $service.Status
}

# FTP site status
try {
    Import-Module WebAdministration -ErrorAction Stop
    $ftpSites = Get-Website | Where-Object { $_.Bindings.Collection.bindingInformation -match ":$Port:" -and $_.Bindings.Collection.protocol -contains "ftp" }
    if ($ftpSites.Count -eq 0) {
        $results += New-Result "FTP Site" "Port $Port" "WARN" "No FTP site bound to port $Port"
    } else {
        foreach ($site in $ftpSites) {
            $status = if ($site.State -eq "Started") { "OK" } else { "FAIL" }
            $results += New-Result "FTP Site" $site.Name $status $site.State
        }
    }
} catch {
    $results += New-Result "FTP Site" "IIS" "WARN" "WebAdministration module not available"
}

# Port listening
try {
    $listening = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction Stop
    $results += New-Result "Port" "localhost:$Port" "OK" "Listening"
} catch {
    $results += New-Result "Port" "localhost:$Port" "FAIL" "Not listening"
}

# FTP banner check (best effort)
try {
    $client = New-Object System.Net.Sockets.TcpClient
    $client.Connect("127.0.0.1", $Port)
    $stream = $client.GetStream()
    $buffer = New-Object byte[] 256
    $read = $stream.Read($buffer, 0, $buffer.Length)
    $banner = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $read).Trim()
    $client.Close()
    if ($banner) {
        $results += New-Result "FTP" "Banner" "OK" $banner
    } else {
        $results += New-Result "FTP" "Banner" "WARN" "No banner received"
    }
} catch {
    $results += New-Result "FTP" "Banner" "WARN" "Could not read banner"
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
