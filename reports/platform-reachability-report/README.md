# Availability report for the Enclave Platform

This script resolves and attempts to connect to key hostnames and IP addresses which comprise the Enclave platform. Use this script if you're having trouble enrolling, or establishing connectivity with Enclave. Note that PowerShell is rather slow to open TCP sockets, so the latency is not representative of real-world conditions. ICMP checks performed by PowerShell however, are quite accurate.

Example output:

```
PS C:\git\enclave\api-automation-scripts\reports\platform-reachability-report> .\platform-reachability-report.ps1
Nameservers

AddressFamily State InterfaceIndex InterfaceAlias Nameserver
------------- ----- -------------- -------------- ----------
IPv4          Up                 8 Ethernet       192.168.0.1


api.enclave.io
    tcp/104.21.19.68:443 .......................... [ok 100ms]
    tcp/172.67.185.152:443 ........................ [ok 94ms]
    tcp/2606:4700:3030::ac43:b998:443 ............. [ok 92ms]
    tcp/2606:4700:3035::6815:1344:443 ............. [ok 81ms]
install.enclave.io
    tcp/104.21.19.68:443 .......................... [ok 95ms]
    tcp/172.67.185.152:443 ........................ [ok 94ms]
    tcp/2606:4700:3030::ac43:b998:443 ............. [ok 79ms]
    tcp/2606:4700:3035::6815:1344:443 ............. [ok 81ms]
discover.enclave.io
    tcp/20.117.66.124:443 ......................... [ok 88ms]
relays.enclave.io
    tcp/13.85.27.150:443 .......................... [ok 207ms]
    icmp/13.85.27.150 ............................. [ok 124ms]
    tcp/172.190.177.249:443 ....................... [ok 166ms]
    icmp/172.190.177.249 .......................... [ok 89ms]
    tcp/172.190.182.223:443 ....................... [ok 177ms]
    icmp/172.190.182.223 .......................... [ok 89ms]
    tcp/20.36.12.227:443 .......................... [ok 236ms]
    icmp/20.36.12.227 ............................. [ok 155ms]
    tcp/40.78.102.193:443 ......................... [ok 239ms]
    icmp/40.78.102.193 ............................ [ok 160ms]
    tcp/51.11.130.243:443 ......................... [ok 102ms]
    icmp/51.11.130.243 ............................ [ok 17ms]
    tcp/51.11.135.52:443 .......................... [ok 109ms]
    icmp/51.11.135.52 ............................. [ok 16ms]
google.com
    tcp/142.250.178.14:443 ........................ [ok 95ms]
    icmp/142.250.178.14 ........................... [ok 16ms]
    tcp/2a00:1450:4009:81d::200e:443 .............. [ok 81ms]
    icmp/2a00:1450:4009:81d::200e ................. [ok 16ms]
management.azure.com
    tcp/2603:1030:a0b::10:443 ..................... [ok 88ms]
    icmp/2603:1030:a0b::10 ........................ [ok 19ms]
    tcp/4.150.240.10:443 .......................... [ok 101ms]
    icmp/4.150.240.10 ............................. [ok 22ms]
go.microsoft.com
    tcp/23.219.197.246:443 ........................ [ok 97ms]
    icmp/23.219.197.246 ........................... [ok 21ms]
    tcp/2a02:26f0:1780:589::2c1a:443 .............. [ok 93ms]
    icmp/2a02:26f0:1780:589::2c1a ................. [ok 17ms]
    tcp/2a02:26f0:1780:598::2c1a:443 .............. [ok 90ms]
    icmp/2a02:26f0:1780:598::2c1a ................. [ok 18ms]
```

## Using this PowerShell script

You may run the PowerShell script without any arguments, it will prompt you to provide a personal access token and Organisation ID.

```
.\platform-reachability-report.ps1
```

