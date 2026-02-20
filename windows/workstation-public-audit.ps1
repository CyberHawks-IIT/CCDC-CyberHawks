<#
.SYNOPSIS
Windows 11 public IP audit for all services

.DESCRIPTION
Tests public IP ports for Windows and Linux services. Team number is required to
calculate the public IP octet (172.25.(20+team).x).
#>

param(
    [Parameter(Mandatory = $true)]
    [int]$TeamNumber
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

function Test-Tcp {
    param([string]$TargetHost, [int]$Port)
    try {
        $r = Test-NetConnection -ComputerName $TargetHost -Port $Port -WarningAction SilentlyContinue
        return $r.TcpTestSucceeded
    } catch { return $false }
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
        $ok = Test-Tcp -TargetHost $svc.Host -Port $p
        $results += New-Result $svc.Name "${svc.Host}:$p" ($(if ($ok) { "OK" } else { "FAIL" })) "TCP"
    }
}

# Best-effort HTTP checks for web services
$httpTargets = @(
    @{ Name = "Web (2019 IIS)";     Url = "http://172.25.$octet.140/" },
    @{ Name = "Ubuntu Ecom";        Url = "http://172.25.$octet.11/"  },
    @{ Name = "Ubuntu Ecom HTTPS";  Url = "https://172.25.$octet.11/" },
    @{ Name = "Fedora Webmail";     Url = "http://172.25.$octet.39/"  },
    @{ Name = "Fedora Webmail HTTPS"; Url = "https://172.25.$octet.39/" }
)

foreach ($t in $httpTargets) {
    try {
        $resp = Invoke-WebRequest -Uri $t.Url -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        $status = if ($resp.StatusCode -eq 200) { "OK" } else { "WARN" }
        $results += New-Result $t.Name $t.Url $status ("StatusCode {0}" -f $resp.StatusCode)
    } catch {
        $results += New-Result $t.Name $t.Url "WARN" $_.Exception.Message
    }
}

$results | Sort-Object Service, Target | Format-Table -AutoSize

$fails = $results | Where-Object { $_.Status -eq "FAIL" }
if ($fails.Count -gt 0) {
    Write-Host "`nPublic audit: FAIL ($($fails.Count) issues)" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`nPublic audit: OK" -ForegroundColor Green
    exit 0
}
