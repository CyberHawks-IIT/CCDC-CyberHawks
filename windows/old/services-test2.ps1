<#
.SYNOPSIS
Batch Port Scanner with Parallel Processing for CCDC Targets

.DESCRIPTION
This script scans a list of servers (both local and public IPs) for specific ports using parallel processing with RunspacePool.

.PARAMETER TeamNumber
The team number is used to calculate the public IP octet dynamically.

#>

# Prompt for team number to calculate public IP octet
$teamNumber = Read-Host "Enter your team number"
$octet = 20 + $teamNumber

# Define server targets
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

# Function to test a single port on a target
function Test-Port {
    param(
        [string]$ComputerName,
        [int]$Port,
        [int]$TimeoutMs = 500
    )
    
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $asyncResult = $tcpClient.BeginConnect($ComputerName, $Port, $null, $null)
        $waitHandle = $asyncResult.AsyncWaitHandle
        if ($waitHandle.WaitOne($TimeoutMs)) {
            $tcpClient.EndConnect($asyncResult)
            $tcpClient.Dispose()
            return $true
        } else {
            $tcpClient.Dispose()
            return $false
        }
    } catch {
        return $false
    }
}

# Create a RunspacePool for parallel processing
$maxThreads = 50 # Number of concurrent threads
$runspacePool = [runspacefactory]::CreateRunspacePool(1, $maxThreads)
$runspacePool.Open()

# Prepare jobs for scanning all servers and ports
$jobs = @()
foreach ($server in $servers) {
    foreach ($ip in @($server.LocalIP, $server.PublicIP)) {
        foreach ($port in $server.Ports) {
            # Create a PowerShell instance for each scan job
            $psInstance = [powershell]::Create().AddScript({
                param($ServerName, $IPAddress, $PortNumber)
                @{
                    ServerName   = $ServerName
                    IPAddress    = $IPAddress
                    Port         = $PortNumber
                    Status       = if (Test-Port -ComputerName $IPAddress -Port $PortNumber -TimeoutMs 500) { "Open" } else { "Closed" }
                }
            }).AddArgument($server.Name).AddArgument($ip).AddArgument($port)

            # Assign the RunspacePool to the PowerShell instance and start the job
            $psInstance.RunspacePool = $runspacePool
            $jobHandle = @{
                PowerShellInstance = $psInstance
                AsyncResult       = $psInstance.BeginInvoke()
            }
            $jobs += $jobHandle
        }
    }
}

# Collect results from all jobs
Write-Host "`nScanning ports... Please wait." -ForegroundColor Cyan
$results = @()
foreach ($job in $jobs) {
    # Wait for each job to complete and collect results
    $job.PowerShellInstance.EndInvoke($job.AsyncResult) | ForEach-Object {
        $results += $_
    }
    # Dispose of the PowerShell instance after completion
    $job.PowerShellInstance.Dispose()
}

# Close the RunspacePool after all jobs are completed
$runspacePool.Close()

# Display results in a table format
Write-Host "`nScan Results:`n" -ForegroundColor Yellow
$results | Sort-Object ServerName, IPAddress, Port | Format-Table @{
    Label       = 'Server'
    Expression  = { $_.ServerName }
}, @{
    Label       = 'IP Address'
    Expression  = { $_.IPAddress }
}, @{
    Label       = 'Port'
    Expression  = { $_.Port }
}, @{
    Label       = 'Status'
    Expression  = { $_.Status }
} -AutoSize

Write-Host "`nScan complete!" -ForegroundColor Green

Read-Host -Prompt "Press Enter to exit"
Read-Host -Prompt "Press Enter to exit"
Read-Host -Prompt "Press Enter to exit"


