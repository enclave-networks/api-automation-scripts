# Produce an OS health report for Windows 10/11 machines

This PowerShell script collects point-in-time OS health and network diagnostics from a Windows 10/11 machine. It runs 35 diagnostic commands (network configuration, DNS, routing, system resources, event logs, NTP, and connectivity tests), writes each command's output to a file, zips everything into the temp directory, and cleans up after itself.

This is useful when end-customers report Enclave being slow and you need a snapshot of the machine's network and system state for analysis.

No administrator privileges are required. Commands that need elevation will have "Access Denied" recorded in their output file — the script continues regardless.

## Running the script

Run directly in PowerShell without cloning:

```
irm https://raw.githubusercontent.com/enclave-networks/api-automation-scripts/main/reports/os-health-report/os-health-report.ps1 | iex
```

Or clone the repo and run locally:

```
.\os-health-report.ps1
```

The script will print progress as each command completes:

```
[+] date /t (0.1s)
[+] ipconfig /all (0.8s)
[-] wevtutil qe System /c:50 /rd:true /f:text (0.3s) -- Access is denied
[+] systeminfo (34.2s)
[!] pathping teams.microsoft.com (180.0s) -- Timed out

Report saved to: C:\Users\<user>\AppData\Local\Temp\os-health-<HOSTNAME>-<yyyyMMdd-HHmmss>.zip
```

## What's collected

The zip contains individual text files for each diagnostic command, plus a `000-manifest.txt` summarising every command's status, duration, and exit code.

| Category | Commands |
|----------|----------|
| Time / timezone | `Get-TimeZone` |
| System | `hostname`, `systeminfo` |
| Network config | `ipconfig /all`, `Get-NetAdapter`, `Get-NetIPConfiguration`, `Get-NetIPAddress` |
| IPv4 routing | `route print`, `arp -a`, `Get-NetRoute` |
| IPv6 | `netsh interface 6to4/teredo/isatap show state` |
| Proxy | `netsh winhttp show proxy`, Internet Settings registry |
| Network state | `netstat -an`, `netstat -e`, `Get-NetTCPConnection`, `Get-NetUDPEndpoint`, `netsh advfirewall show allprofiles` |
| DNS | `nslookup teams.microsoft.com`, `nslookup login.microsoftonline.com`, `Get-DnsClientServerAddress`, TCP connect to teams.microsoft.com:443 |
| NTP | `w32tm /query /status`, `w32tm /query /peers`, `w32tm /stripchart` |
| Event logs | Last 50 System events, last 50 Application events |
| System resources | `tasklist`, CPU info, memory info, top 20 processes by memory |
| Connectivity | `ping -n 5` to 8.8.8.8, login.microsoftonline.com, teams.microsoft.com |

## Output file format

Each output file includes a metadata header:

```
================================================================================
Command:   ipconfig /all
Started:   2026-03-16 14:30:22
Duration:  0.87s
Exit Code: 0
Status:    Success
================================================================================
<command output>
```

Failed or timed-out commands are recorded the same way with `Status: Error` or `Status: TIMEOUT`. Timed-out commands include any partial output captured before the timeout (e.g. partial traceroute results).
