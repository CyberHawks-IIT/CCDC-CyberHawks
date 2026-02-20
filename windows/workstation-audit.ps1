<#
.SYNOPSIS
Windows 11 workstation audit for AD/DNS, Web, and FTP servers

.DESCRIPTION
Performs remote health checks using port tests, DNS query, HTTP request, FTP port check,
and AD user existence checks via LDAP.
#>

param(
    [string]$AdServer = "172.20.240.102",
    [string]$WebServer = "172.20.240.101",
    [string]$FtpServer = "172.20.240.104",
    [string[]]$RequiredUsers = @("Administrator", "charles.labelle", "chase.logan")
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

function Test-Tcp {
    param([string]$Host, [int]$Port)
    try {
        $r = Test-NetConnection -ComputerName $Host -Port $Port -WarningAction SilentlyContinue
        return $r.TcpTestSucceeded
    } catch { return $false }
}

function Test-Udp {
    param([string]$Host, [int]$Port)
    try {
        $r = Test-NetConnection -ComputerName $Host -Port $Port -Udp -WarningAction SilentlyContinue
        return $r.UdpTestSucceeded
    } catch { return $false }
}

$results = @()

# AD/DNS/DHCP checks
$adPorts = @(53, 88, 389, 445)
foreach ($p in $adPorts) {
    $ok = Test-Tcp -Host $AdServer -Port $p
    $results += New-Result "AD Port" "$AdServer:$p" ($(if ($ok) { "OK" } else { "FAIL" })) "TCP"
}

$dhcpOk = Test-Udp -Host $AdServer -Port 67
$results += New-Result "DHCP Port" "$AdServer:67" ($(if ($dhcpOk) { "OK" } else { "WARN" })) "UDP"

try {
    $domain = $env:USERDNSDOMAIN
    if (-not [string]::IsNullOrWhiteSpace($domain)) {
        $null = Resolve-DnsName -Name $domain -Type A -Server $AdServer -ErrorAction Stop
        $results += New-Result "DNS" "Resolve $domain" "OK" "Query via $AdServer"
    } else {
        $results += New-Result "DNS" "Resolve domain" "WARN" "USERDNSDOMAIN not set"
    }
} catch {
    $results += New-Result "DNS" "Resolve domain" "FAIL" $_.Exception.Message
}

# AD user existence via LDAP
try {
    $root = [ADSI]("LDAP://$AdServer/RootDSE")
    $base = $root.defaultNamingContext
    if (-not [string]::IsNullOrWhiteSpace($base)) {
        foreach ($user in $RequiredUsers) {
            $ds = New-Object System.DirectoryServices.DirectorySearcher
            $ds.SearchRoot = [ADSI]("LDAP://$AdServer/$base")
            $ds.Filter = "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$user))"
            $ds.SearchScope = "Subtree"
            $found = $ds.FindOne()
            $results += New-Result "AD User" $user ($(if ($found) { "OK" } else { "FAIL" })) "LDAP query"
        }
    } else {
        $results += New-Result "AD User" "RootDSE" "FAIL" "defaultNamingContext not found"
    }
} catch {
    $results += New-Result "AD User" "LDAP" "FAIL" $_.Exception.Message
}

# Web server checks
$webOk = Test-Tcp -Host $WebServer -Port 80
$results += New-Result "Web Port" "$WebServer:80" ($(if ($webOk) { "OK" } else { "FAIL" })) "TCP"

try {
    $resp = Invoke-WebRequest -Uri ("http://{0}/" -f $WebServer) -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
    $status = if ($resp.StatusCode -eq 200) { "OK" } else { "WARN" }
    $results += New-Result "HTTP" "$WebServer/" $status ("StatusCode {0}" -f $resp.StatusCode)
} catch {
    $results += New-Result "HTTP" "$WebServer/" "FAIL" $_.Exception.Message
}

# FTP server checks
$ftpOk = Test-Tcp -Host $FtpServer -Port 21
$results += New-Result "FTP Port" "$FtpServer:21" ($(if ($ftpOk) { "OK" } else { "FAIL" })) "TCP"

$results | Format-Table -AutoSize

$fails = $results | Where-Object { $_.Status -eq "FAIL" }
if ($fails.Count -gt 0) {
    Write-Host "`nAudit: FAIL ($($fails.Count) issues)" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`nAudit: OK" -ForegroundColor Green
    exit 0
}
