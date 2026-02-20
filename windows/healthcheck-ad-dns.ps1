<#
.SYNOPSIS
Health check for Windows Server 2019 AD/DNS/DHCP

.DESCRIPTION
Checks critical services, DNS responsiveness, and required AD users.
#>

param(
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

$results = @()

# Services
$serviceNames = @("NTDS", "DNS", "DHCPServer", "Netlogon", "KDC", "W32Time")
foreach ($svc in $serviceNames) {
    $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if (-not $service) {
        $results += New-Result "Service" $svc "FAIL" "Not found"
        continue
    }
    $status = if ($service.Status -eq "Running") { "OK" } else { "FAIL" }
    $results += New-Result "Service" $svc $status $service.Status
}

# DNS resolution test
$domain = $env:USERDNSDOMAIN
if ([string]::IsNullOrWhiteSpace($domain)) {
    $results += New-Result "DNS" "Resolve" "WARN" "USERDNSDOMAIN not set; skipping DNS query"
} else {
    try {
        $null = Resolve-DnsName -Name $domain -Type A -Server 127.0.0.1 -ErrorAction Stop
        $results += New-Result "DNS" "Resolve $domain" "OK" "Query succeeded"
    } catch {
        $results += New-Result "DNS" "Resolve $domain" "FAIL" $_.Exception.Message
    }
}

# AD module checks
$adModuleLoaded = $false
try {
    Import-Module ActiveDirectory -ErrorAction Stop
    $adModuleLoaded = $true
} catch {
    $results += New-Result "AD" "Module" "WARN" "ActiveDirectory module not available; using ADSI fallback"
}

# User existence checks
if ($adModuleLoaded) {
    foreach ($user in $RequiredUsers) {
        try {
            $u = Get-ADUser -Identity $user -ErrorAction Stop
            $results += New-Result "User" $user "OK" "Found ($($u.SamAccountName))"
        } catch {
            $results += New-Result "User" $user "FAIL" "Not found"
        }
    }

    # Group membership sanity checks
    try {
        $adminGroups = Get-ADPrincipalGroupMembership -Identity "Administrator" | Select-Object -ExpandProperty Name
        $inDA = $adminGroups -contains "Domain Admins"
        $results += New-Result "Group" "Administrator -> Domain Admins" ($(if ($inDA) { "OK" } else { "FAIL" })) "Membership check"
    } catch {
        $results += New-Result "Group" "Administrator -> Domain Admins" "WARN" "Could not verify membership"
    }

    foreach ($user in @("charles.labelle", "chase.logan")) {
        try {
            $groups = Get-ADPrincipalGroupMembership -Identity $user | Select-Object -ExpandProperty Name
            $inDU = $groups -contains "Domain Users"
            $results += New-Result "Group" "$user -> Domain Users" ($(if ($inDU) { "OK" } else { "FAIL" })) "Membership check"
        } catch {
            $results += New-Result "Group" "$user -> Domain Users" "WARN" "Could not verify membership"
        }
    }
} else {
    # ADSI fallback for user lookup
    try {
        $root = [ADSI]"LDAP://RootDSE"
        $base = $root.defaultNamingContext
        if (-not [string]::IsNullOrWhiteSpace($base)) {
            foreach ($user in $RequiredUsers) {
                $ds = New-Object System.DirectoryServices.DirectorySearcher
                $ds.SearchRoot = [ADSI]("LDAP://$base")
                $ds.Filter = "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$user))"
                $ds.SearchScope = "Subtree"
                $found = $ds.FindOne()
                $results += New-Result "User" $user ($(if ($found) { "OK" } else { "FAIL" })) "ADSI search"
            }
        } else {
            $results += New-Result "AD" "RootDSE" "FAIL" "defaultNamingContext not found"
        }
    } catch {
        $results += New-Result "AD" "ADSI" "FAIL" $_.Exception.Message
    }
}

# Summary output
$results | Format-Table -AutoSize

$fails = $results | Where-Object { $_.Status -eq "FAIL" }
if ($fails.Count -gt 0) {
    Write-Host "`nHealth check: FAIL ($($fails.Count) issues)" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`nHealth check: OK" -ForegroundColor Green
    exit 0
}
