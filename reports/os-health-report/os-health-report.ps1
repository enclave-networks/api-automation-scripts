$ErrorActionPreference = "Continue"

$hostname = $env:COMPUTERNAME
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$tempDir = Join-Path $env:TEMP "os-health-$hostname-$timestamp"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$script:manifestEntries = [System.Collections.ArrayList]::new()

# --- Helper functions ---

function Write-CommandOutput {
    param(
        [string]$FileName,
        [string]$Command,
        [string]$Output,
        [double]$DurationSeconds,
        [int]$ExitCode,
        [string]$Status,
        [datetime]$StartTime
    )

    $header = @"
================================================================================
Command:   $Command
Started:   $($StartTime.ToString("yyyy-MM-dd HH:mm:ss"))
Duration:  $("{0:F2}s" -f $DurationSeconds)
Exit Code: $ExitCode
Status:    $Status
================================================================================
"@

    $filePath = Join-Path $tempDir $FileName
    Set-Content -Path $filePath -Value ($header + "`n`n" + $Output) -Encoding UTF8

    $script:manifestEntries.Add([PSCustomObject]@{
        FileName = $FileName
        Command  = $Command
        Status   = $Status
        Duration = "{0:F1}s" -f $DurationSeconds
        ExitCode = $ExitCode
    }) | Out-Null
}

function Invoke-FastCommand {
    param(
        [string]$FileName,
        [string]$Command,
        [string]$Type
    )

    $startTime = Get-Date
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $exitCode = 0
    $status = "Success"
    $output = ""

    try {
        if ($Type -eq "cmd") {
            $output = & cmd.exe /c "$Command 2>&1" | Out-String
            $exitCode = $LASTEXITCODE
            if ($null -eq $exitCode) { $exitCode = 0 }
        } else {
            $output = Invoke-Expression $Command 2>&1 | Out-String
            $exitCode = 0
        }
    } catch {
        $status = "Error"
        $output = $_.Exception.Message
        $exitCode = 1
    }

    $stopwatch.Stop()
    $duration = $stopwatch.Elapsed.TotalSeconds

    Write-CommandOutput -FileName $FileName -Command $Command -Output $output `
        -DurationSeconds $duration -ExitCode $exitCode -Status $status -StartTime $startTime

    $durationStr = "{0:F1}s" -f $duration
    if ($status -eq "Success") {
        Write-Host "[+] $Command ($durationStr)"
    } else {
        $errorSnippet = ($output -split "`n")[0].Trim()
        Write-Host "[-] $Command ($durationStr) -- $errorSnippet" -ForegroundColor Red
    }
}

# --- Command definitions ---

$slowCommands = @(
    @{ FileName = "020-system-systeminfo.txt";                Command = "systeminfo";                                                         Type = "cmd" }
    @{ FileName = "200-ping-8.8.8.8.txt";                      Command = "ping -n 5 8.8.8.8";                                                  Type = "cmd" }
    @{ FileName = "201-ping-login.txt";                        Command = "ping -n 5 login.microsoftonline.com";                                 Type = "cmd" }
    @{ FileName = "202-ping-teams.txt";                        Command = "ping -n 5 teams.microsoft.com";                                      Type = "cmd" }
    @{ FileName = "230-ntp-stripchart.txt";                    Command = "w32tm /stripchart /computer:time.windows.com /samples:2 /dataonly";   Type = "cmd" }
)

$fastCommands = @(
    # Time / timezone
    @{ FileName = "010-time-timezone.txt";                    Command = "Get-TimeZone";                                                                                                                        Type = "ps"  }
    # System
    @{ FileName = "021-system-hostname.txt";                  Command = "hostname";                                                                                                                            Type = "cmd" }
    # Network config
    @{ FileName = "030-network-config-ipconfig.txt";          Command = "ipconfig /all";                                                                                                                       Type = "cmd" }
    @{ FileName = "031-network-config-getnetadapter.txt";     Command = "Get-NetAdapter | Format-List";                                                                                                        Type = "ps"  }
    @{ FileName = "032-network-config-getnetipconfig.txt";    Command = "Get-NetIPConfiguration | Format-List";                                                                                                Type = "ps"  }
    @{ FileName = "033-network-config-getnetipaddress.txt";   Command = "Get-NetIPAddress | Format-Table";                                                                                                     Type = "ps"  }
    # IPv4 routing
    @{ FileName = "040-network-ipv4-route-print.txt";         Command = "route print";                                                                                                                         Type = "cmd" }
    @{ FileName = "041-network-ipv4-arp.txt";                 Command = "arp -a";                                                                                                                              Type = "cmd" }
    @{ FileName = "042-network-ipv4-getnetroute.txt";         Command = "Get-NetRoute | Format-Table";                                                                                                         Type = "ps"  }
    # IPv6
    @{ FileName = "050-network-ipv6-6to4.txt";                Command = "netsh interface 6to4 show state";                                                                                                     Type = "cmd" }
    @{ FileName = "051-network-ipv6-teredo.txt";              Command = "netsh interface teredo show state";                                                                                                   Type = "cmd" }
    @{ FileName = "052-network-ipv6-isatap.txt";              Command = "netsh interface isatap show state";                                                                                                   Type = "cmd" }
    # Proxy
    @{ FileName = "060-network-proxy-netsh.txt";              Command = "netsh winhttp show proxy";                                                                                                            Type = "cmd" }
    @{ FileName = "061-network-proxy-ie.txt";                 Command = "Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' | Format-List";                                   Type = "ps"  }
    # Network state
    @{ FileName = "070-network-state-netstat-an.txt";         Command = "netstat -an";                                                                                                                         Type = "cmd" }
    @{ FileName = "071-network-state-netstat-e.txt";          Command = "netstat -e";                                                                                                                          Type = "cmd" }
    @{ FileName = "072-network-state-tcp-connections.txt";    Command = "Get-NetTCPConnection | Format-Table";                                                                                                 Type = "ps"  }
    @{ FileName = "073-network-state-udp-endpoints.txt";      Command = "Get-NetUDPEndpoint | Format-Table";                                                                                                   Type = "ps"  }
    @{ FileName = "074-network-state-netsh-firewall.txt";     Command = "netsh advfirewall show allprofiles";                                                                                                  Type = "cmd" }
    # DNS
    @{ FileName = "080-dns-nslookup-teams.txt";               Command = "nslookup teams.microsoft.com";                                                                                                        Type = "cmd" }
    @{ FileName = "081-dns-nslookup-login.txt";               Command = "nslookup login.microsoftonline.com";                                                                                                  Type = "cmd" }
    @{ FileName = "082-dns-tcp-teams-443.txt";                 Command = "`$c = New-Object Net.Sockets.TcpClient; `$c.Connect('teams.microsoft.com', 443); `$c.Close(); 'TCP connect to teams.microsoft.com:443 succeeded'";  Type = "ps"  }
    @{ FileName = "084-dns-getdnsclient.txt";                 Command = "Get-DnsClientServerAddress | Format-Table";                                                                                           Type = "ps"  }
    # NTP
    @{ FileName = "090-ntp-w32tm-query.txt";                  Command = "w32tm /query /status";                                                                                                                Type = "cmd" }
    @{ FileName = "091-ntp-w32tm-peers.txt";                  Command = "w32tm /query /peers";                                                                                                                 Type = "cmd" }
    # Event logs
    @{ FileName = "100-eventlog-system-50.txt";               Command = "wevtutil qe System /c:50 /rd:true /f:text";                                                                                           Type = "cmd" }
    @{ FileName = "101-eventlog-application-50.txt";          Command = "wevtutil qe Application /c:50 /rd:true /f:text";                                                                                      Type = "cmd" }
    # System resources
    @{ FileName = "110-resources-tasklist.txt";               Command = "tasklist";                                                                                                                             Type = "cmd" }
    @{ FileName = "111-resources-cpu.txt";                     Command = "Get-CimInstance Win32_Processor | Format-List Name,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed";                              Type = "ps"  }
    @{ FileName = "112-resources-memory.txt";                 Command = "Get-CimInstance Win32_OperatingSystem | Format-List TotalVisibleMemorySize,FreePhysicalMemory";                                        Type = "ps"  }
    @{ FileName = "113-resources-top-processes.txt";          Command = "Get-Process | Sort-Object -Property WorkingSet64 -Descending | Select-Object -First 20 Name,Id,CPU,WorkingSet64,Path | Format-Table";  Type = "ps"  }
)

# --- Step 1: Start slow commands as background jobs ---

$jobs = @()
foreach ($cmd in $slowCommands) {
    $startTime = Get-Date
    $job = Start-Job -ScriptBlock {
        param($Command, $Type)
        $ErrorActionPreference = "Continue"
        try {
            if ($Type -eq "cmd") {
                & cmd.exe /c "$Command 2>&1"
            } else {
                Invoke-Expression $Command 2>&1
            }
        } catch {
            "ERROR: $($_.Exception.Message)"
        }
    } -ArgumentList $cmd.Command, $cmd.Type

    $jobs += @{
        Job       = $job
        FileName  = $cmd.FileName
        Command   = $cmd.Command
        StartTime = $startTime
    }
}

# --- Step 2: Run fast commands sequentially ---

foreach ($cmd in $fastCommands) {
    Invoke-FastCommand -FileName $cmd.FileName -Command $cmd.Command -Type $cmd.Type
}

# --- Step 3: Wait for slow jobs and collect results ---

foreach ($entry in $jobs) {
    $job = $entry.Job
    $null = $job | Wait-Job -Timeout 15

    $duration = ((Get-Date) - $entry.StartTime).TotalSeconds

    if ($job.State -eq "Completed") {
        $output = (Receive-Job -Job $job 2>&1) | Out-String
        $status = "Success"
        $exitCode = 0
    } elseif ($job.State -eq "Failed") {
        $output = (Receive-Job -Job $job 2>&1) | Out-String
        $status = "Error"
        $exitCode = 1
    } else {
        Stop-Job -Job $job
        $output = (Receive-Job -Job $job 2>&1) | Out-String
        $status = "TIMEOUT"
        $exitCode = -1
    }

    Remove-Job -Job $job -Force

    Write-CommandOutput -FileName $entry.FileName -Command $entry.Command -Output $output `
        -DurationSeconds $duration -ExitCode $exitCode -Status $status -StartTime $entry.StartTime

    $durationStr = "{0:F1}s" -f $duration
    if ($status -eq "Success") {
        Write-Host "[+] $($entry.Command) ($durationStr)"
    } elseif ($status -eq "TIMEOUT") {
        Write-Host "[!] $($entry.Command) ($durationStr) -- Timed out" -ForegroundColor Yellow
    } else {
        $errorSnippet = ($output -split "`n")[0].Trim()
        Write-Host "[-] $($entry.Command) ($durationStr) -- $errorSnippet" -ForegroundColor Red
    }
}

# --- Step 4: Write manifest ---

$manifestPath = Join-Path $tempDir "000-manifest.txt"
$manifestHeader = @"
OS Health Report Manifest
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Hostname:  $hostname

"@
$manifestBody = $script:manifestEntries | Sort-Object FileName | Format-Table FileName, Command, Status, Duration, ExitCode -AutoSize | Out-String
Set-Content -Path $manifestPath -Value ($manifestHeader + $manifestBody) -Encoding UTF8

# --- Step 5: Create zip ---

$zipPath = Join-Path $env:TEMP "os-health-$hostname-$timestamp.zip"

Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force

# --- Step 6: Cleanup ---

Remove-Item -Path $tempDir -Recurse -Force

Write-Host ""
Write-Host "Report saved to: $zipPath"
