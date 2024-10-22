# Produce a report of active Enclave systems for a specific tenant

This PowerShell script takes an Enclave `Personal Access Token` and `Organisation Id` to generate a tabular report of the systems enrolled to the tenant. This can be useful to determine which systems have not connected to the platform for extended periods of time, or which systems are running versions of Enclave and need to be updated.

Example output:

```
PS C:\git\api-automation-scripts\reports\active-systems-report> .\active-systems-report.ps1
Please enter your Enclave Personal Access Token: 012345abcdefghijklmnopqrstuvwxyz67890abcdefghijklmnopqrstuvwxyz
Please enter your Enclave Organisation Id: b87f2e1a3d9f4c5eb5a67d9e2f8c3b7a

systemId virtualAddress   state        platformType lastSeen        enclaveVersion  hostname                          enrolledAt        description
-------- --------------   -----        ------------ --------        --------------  --------                          ----------        -----------
Q1BCD    100.92.45.101    Disconnected Darwin       530 days ago    2022.11.28.442  Johns-MacBook.local               16 December 2022  John's personal laptop
X3FGH    100.85.27.222    Disconnected Windows      492 days ago    2023.2.1        EMILY-PC                          25 November 2022  Emily's development machine
M8JKL    100.125.88.57    Disconnected Android      483 days ago    2023.2.1        samsung-galaxy-s10                01 February 2023  Dev team test device
R2QWP    100.114.105.189  Disconnected Android      483 days ago    2023.2.1        oneplus-8                         01 February 2023  QA test phone
B4ZKL    100.78.23.172    Disconnected iOS          480 days ago    2022.10.7       Sarahs-iPhone                     01 February 2023  Sarah's old phone
C7YXD    100.115.219.8    Disconnected iOS          455 days ago    2023.4.25       Roberts-MacBook-Pro               15 February 2023  Robert's previous work laptop
L9PLZ    100.113.67.109   Disconnected iOS          390 days ago    2023.4.25       Roberts-iPhone                    01 February 2023  Robert's iPhone
F3HQL    100.75.192.151   Disconnected iOS          385 days ago    2023.4.25       iPhone-88                         14 March 2023     Old iPhone for testing
K5Y9F    100.126.212.94   Connected    Windows      25 days ago     2024.4.30.1573  DESKTOP-J9FUI3J                   15 August 2020    Development machine
Z7MPT    100.86.127.12    Connected    Darwin       20 days ago     2022.10.7       Alices-MacBook.local              20 August 2020    Alice's MacBook
T6YHK    100.71.14.38     Connected    Windows      15 days ago     2024.4.30.1578  DESKTOP-U29X3CD                   01 September 2020 Development server
X1CVB    100.122.119.174  Connected    Windows      10 days ago     2024.4.30.1573  DESKTOP-AXYZ123                   02 July 2020      Office desktop
XW5X5    100.91.10.42     Connected    Darwin       6 days ago      2021.9.27.0     Andys-iMac.zyxel.com              07 October 2021   Andy's iMac
V88RY    100.88.199.33    Connected    Windows      19 hours ago    2024.4.30.1578  DESKTOP-U98V3DV                   01 April 2020     Emily's work laptop
L2D4D    100.72.221.161   Connected    Windows      3 hours ago     2024.4.30.1578  DESKTOP-LIG38H0                   25 July 2022      Emily's second work laptop
L9TYC    100.123.51.180   Connected    Linux        3 hours ago     2023.11.14.1726 dev-server-02                     12 March 2023     Development server
T4MNR    100.103.23.90    Connected    Android      2 hours ago     2022.12.12      pixel-4a                          03 July 2023      Development mobile
V2KZQ    100.124.166.121  Connected    Linux        1 hour ago      2023.12.12      staging-server-01                 24 November 2022  Staging server
J5CVB    100.117.210.157  Connected    Windows      30 minutes ago  2024.4.30.1578  DESKTOP-FS3JH9J                   01 March 2023     Development server
XWLX5    100.108.47.234   Connected    Darwin       17 minutes ago  2022.9.27.410   Alices-MBP                        10 May 2022       Alice's MacBook Pro
T1BGT    100.98.115.204   Connected    Darwin       15 minutes ago  2021.9.27.0     Andys-iMac.zyxel.com              07 October 2021   Andy's iMac
Q9PWF    100.123.219.89   Connected    Windows      10 minutes ago  2024.4.30.1578  LISA-PC                           29 April 2024     Lisa's home PC
P9HXC    100.106.30.12    Connected    Linux        10 minutes ago  2023.11.14.1726 ubuntu-server                     16 June 2022      Ubuntu demo server
G8XDR    100.111.66.157   Connected    Windows      6 minutes ago   2024.3.15.1514  DESKTOP-KL89UY                    12 May 2021       Jane's office desktop
N7YJP    100.116.124.74   Connected    iOS          5 minutes ago   2024.1.11.1411  james-iPhone                      12 July 2023      James' iPhone
B7WSV    100.96.92.201    Connected    Windows      5 minutes ago   2024.3.15.1514  WILLIAMS-LAPTOP                   20 March 2024     William's work laptop
K6TYD    100.87.25.11     Connected    Darwin       5 minutes ago   2023.6.1.601    Admin-MacBook.local               23 February 2023  Admin MacBook
J3GLZ    100.84.192.83    Connected    Windows      3 minutes ago   2024.1.11.1411  CHARLIE-PC                        16 December 2022  Charlie's work PC
M7HYQ    100.114.103.40   Connected    iOS          3 minutes ago   2024.1.11.1411  Emma-iPhone                       23 June 2023      Emma's iPhone
V8YXC    100.85.111.53    Connected    Android      2 minutes ago   2024.4.30.1578  pixel-5                           01 June 2021      QA test phone
D5HTV    100.116.244.13   Connected    iOS          2 minutes ago   2023.12.12      Ians-iPhone                       18 August 2023    Ian's iPhone
M4FJY    100.106.167.25   Connected    iOS          1 minute ago    2024.3.15       localhost                         16 December 2022  John's current iPhone

System count: 32
```

## Using this PowerShell script

You may run the PowerShell script without any arguments, it will prompt you to provide a personal access token and Organisation ID.

```
.\active-systems-report.ps1

Please enter your Enclave Personal Access Token: <apiKey>
Please enter your Enclave Organisation Id: <orgId>
```

Or you can provide arguments to the script:

```bash
.\active-systems-report.ps1 -orgId <orgId> -apiKey <apiKey>
```

## Requirements

You will need to know:

- Your Enclave Organisation Id
- Your Enclave API Key

You can find the Organisation Id by selecting the appropriate tenant in the Enclave Portal and visiting https://portal.enclave.io/my/settings, and visit your account page at https://portal.enclave.io/account to generate a Personal Access Token (API Key) if you don't already have one.