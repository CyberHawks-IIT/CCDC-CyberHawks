<#
.SYNOPSIS
CCDC Service Port Scanner with Preconfigured Public IPs

.DESCRIPTION
Scans predefined services using server objects with embedded public IP patterns
#>

$teamNumber = Read-Host "Enter your team number"
$octet = 20 + $teamNumber

$servers = @(
    [PSCustomObject]@{
        Name = "Docker/Remote"
        LocalIP = "172.20.240.10"
        PublicIP = "172.25.$octet.97"
        Ports = @(22, 2375, 2376)
    },
    [PSCustomObject]@{
        Name = "Debian 10 DNS/NTP"
        LocalIP = "172.20.240.20"
        PublicIP = "172.25.$octet.20"
        Ports = @(53, 123)
    },
    [PSCustomObject]@{
        Name = "Ubuntu 18 Web"
        LocalIP = "172.20.242.10"
        PublicIP = "172.25.$octet.23"
        Ports = @(80, 443)
    },
    [PSCustomObject]@{
        Name = "2019 AD/DNS/DHCP"
        LocalIP = "172.20.242.200"
        PublicIP = "172.25.$octet.27"
        Ports = @(53, 67, 68, 88, 389)
    },
    [PSCustomObject]@{
        Name = "Splunk"
        LocalIP = "172.20.241.20"
        PublicIP = "172.25.$octet.9"
        Ports = @(8089, 9997)
    },
    [PSCustomObject]@{
        Name = "CentOS 7 E-Comm"
        LocalIP = "172.20.241.30"
        PublicIP = "172.25.$octet.11"
        Ports = @(80, 443, 3306)
    },
    [PSCustomObject]@{
        Name = "Fedora 21 Webmail/WebApps"
        LocalIP = "172.20.241.40"
        PublicIP = "172.25.$octet.39"
        Ports = @(25, 80, 443, 587)
    }
)

# Scan function with integrated status display
function Invoke-CCDCScan {
    param($Server)
    
    $results = @()
    foreach ($target in @($Server.LocalIP, $Server.PublicIP)) {
        if ($target -eq 'dynamic') { continue }
        
        foreach ($port in $Server.Ports) {
            $test = Test-NetConnection -ComputerName $target -Port $port -WarningAction SilentlyContinue
            $status = if ($test.TcpTestSucceeded) {"Open"} else {"Closed"}
            
            $results += [PSCustomObject]@{
                Server = $Server.Name
                IPType = if ($target -eq $Server.LocalIP) {"Local"} else {"Public"}
                IP = $target
                Port = $port
                Status = $status
            }
        }
    }
    $results
}

# Perform and display scans
Clear-Host
Write-Host "CCDC Network Scan (Team $teamNumber)`n" -ForegroundColor Cyan
Write-Host "Scanning targets with public IP octet: $octet`n"

$servers | ForEach-Object {
    $scanResults = Invoke-CCDCScan -Server $_
    $scanResults | ForEach-Object {
        $color = if ($_.Status -eq "Open") { "Green" } else { "Red" }
        Write-Host ("{0,-22} {1,-7} {2,-15} {3,-5} {4}" -f $_.Server, $_.IPType, $_.IP, $_.Port, $_.Status) -ForegroundColor $color
    }
    Write-Host ""
}
