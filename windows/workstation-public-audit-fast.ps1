<#
.SYNOPSIS
Fast public IP audit for all services (short TCP timeouts)

.DESCRIPTION
Uses TcpClient with a short timeout to speed up port checks.
#>

param(
    [Parameter(Mandatory = $true)]
    [int]$TeamNumber,
    [int]$TimeoutMs = 500
)

function New-Result {
    param($Service, $Target, $Status, $Details)
    [PSCustomObject]@{
        Service = $Service
        Target  = $Target
        Status  = $Status
        Details = $Details
    }
}

function Test-TcpFast {
    param([string]$TargetHost, [int]$Port, [int]$TimeoutMs)
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $async = $client.BeginConnect($TargetHost, $Port, $null, $null)
        if ($async.AsyncWaitHandle.WaitOne($TimeoutMs)) {
            $client.EndConnect($async) | Out-Null
            $client.Dispose()
            return $true
        }
        $client.Dispose()
        return $false
    } catch {
        return $false
    }
}

$octet = 20 + $TeamNumber

$services = @(
    # Windows
    @{ Name = "AD/DNS/DHCP (2019)"; Host = "172.25.$octet.155"; Ports = @(53, 67, 68, 88, 389, 445) },
    @{ Name = "Web (2019 IIS)";     Host = "172.25.$octet.140"; Ports = @(80) },
    @{ Name = "FTP (2022)";         Host = "172.25.$octet.162"; Ports = @(21) },

    # Linux
    @{ Name = "Ubuntu Ecom (OpenCart)"; Host = "172.25.$octet.11"; Ports = @(80, 443) },
    @{ Name = "Fedora Webmail";         Host = "172.25.$octet.39"; Ports = @(25, 587, 465, 143, 993, 110, 995, 80, 443) },
    @{ Name = "Splunk";                 Host = "172.25.$octet.9";  Ports = @(8000, 8089, 9997) }
)

$results = @()

foreach ($svc in $services) {
    foreach ($p in $svc.Ports) {
        $ok = Test-TcpFast -TargetHost $svc.Host -Port $p -TimeoutMs $TimeoutMs
        $results += New-Result $svc.Name "${svc.Host}:$p" ($(if ($ok) { "OK" } else { "FAIL" })) ("TCP ${TimeoutMs}ms")
    }
}

$results | Sort-Object Service, Target | Format-Table -AutoSize

$fails = $results | Where-Object { $_.Status -eq "FAIL" }
if ($fails.Count -gt 0) {
    Write-Host "`nPublic audit (fast): FAIL ($($fails.Count) issues)" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`nPublic audit (fast): OK" -ForegroundColor Green
    exit 0
}
