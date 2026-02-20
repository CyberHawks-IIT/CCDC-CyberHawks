$currentDir = $PSScriptRoot
if (!$currentDir) { $currentDir = Get-Location }

$logFile = "$currentDir\net_audit.log"
$summaryFile = "$currentDir\connection_summary.txt"
$safeIpsFile = "$currentDir\safe-ips.txt"

# Track connections: Key -> @{ Count, Name, Path, FirstSeen }
$history = @{} 

if (!(Test-Path $safeIpsFile)) { New-Item $safeIpsFile -ItemType File; "8.8.8.8" | Out-File $safeIpsFile }

Write-Host "Monitoring for C2... Logs at: $currentDir" -ForegroundColor Cyan
Write-Host "Console will only show NEW or HIGH-FREQUENCY connections.`n"

while ($true) {
	$safeIps = Get-Content $safeIpsFile | Where-Object { $_ -match "\d+\.\d+\.\d+\.\d+" }
	$timestamp = (Get-Date).ToString("HH:mm:ss")
    
	$conns = Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue | 
	Where-Object { $_.RemoteAddress -notmatch "127.0.0.1|::1|0.0.0.0" -and $_.RemoteAddress -notin $safeIps }

	foreach ($c in $conns) {
		$procId = $c.OwningProcess
		$remote = "$($c.RemoteAddress):$($c.RemotePort)"
		$key = "$remote (PID: $procId)"

		if (-not $history.ContainsKey($key)) {
			# --- NEW CONNECTION DISCOVERED ---
			$proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
			$pName = if ($proc) { $proc.Name } else { "Unknown" }
			$pPath = if ($proc) { $proc.Path } else { "N/A" }
			$pCmd = (Get-CimInstance Win32_Process -Filter "ProcessId = $procId").CommandLine

			$history[$key] = @{ Count = 1; Name = $pName; Path = $pPath }

			# DETECTION LOGIC
			$isSuspicious = $false
			$reason = ""
            
			# 1. Path Check (Malware in Temp/Public)
			if ($pPath -match "Temp|Users\\Public|AppData") { $isSuspicious = $true; $reason = "UNUSUAL PATH" }
            
			# 2. SVCHost Masquerade Check
			if ($pName -eq "svchost" -and $pPath -notmatch "System32") { $isSuspicious = $true; $reason = "FAKE SVCHOST" }

			# Print to Console
			$msg = "[$timestamp] NEW: [$pName] -> $remote"
			if ($isSuspicious) {
				Write-Host "!! ALERT: $reason !! $msg" -ForegroundColor Red -BackgroundColor Black
				Write-Host "   Path: $pPath" -ForegroundColor Red
			}
			else {
				Write-Host $msg -ForegroundColor Green
			}

			# Detailed Log
			"[$timestamp] NEW | $pName | $key | Path: $pPath | Cmd: $pCmd" | Out-File $logFile -Append
		} 
		else {
			# --- REPEAT CONNECTION ---
			$history[$key].Count++
			$count = $history[$key].Count

			# Only alert console on milestones to prevent spam
			if ($count % 50 -eq 0) {
				Write-Host "[$timestamp] MILESTONE ($count`x): [$($history[$key].Name)] -> $remote" -ForegroundColor Cyan
			}
		}
	}

	# UPDATE SUMMARY FILE (Sorted by Count)
	$summaryData = $history.GetEnumerator() | Sort-Object { $_.Value.Count } -Descending | ForEach-Object {
		"{0,6}x | {1,-15} | {2}" -f $_.Value.Count, $_.Value.Name, $_.Key
	}
	$summaryData | Out-File -FilePath $summaryFile -Force

	Start-Sleep -Seconds 1
}