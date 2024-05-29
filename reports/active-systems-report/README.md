# Produce a report of active Enclave systems for a specific tenant

This PowerShell script takes an Enclave `Personal Access Token` and `Organisation Id` to generate a tabular report of the systems enrolled to the tenant. This can be useful to determine which systems have not connected to the platform for extended periods of time, or which systems are running versions of Enclave and need to be updated.

Example output:

```
PS C:\git\api-automation-scripts\reports\active-systems-report> .\active-systems-report.ps1
Please enter your Enclave Personal Access Token: 012345abcdefghijklmnopqrstuvwxyz67890abcdefghijklmnopqrstuvwxyz
Please enter your Enclave Organisation Id: b87f2e1a3d9f4c5eb5a67d9e2f8c3b7a

systemId state        platformType lastSeen        enclaveVersion  hostname                          enrolledAt        description
-------- -----        ------------ --------        --------------  --------                          ----------        -----------
Q1BCD    Disconnected Darwin       530 days ago    2022.11.28.442  Johns-MacBook.local               16 December 2022  John's personal laptop
X3FGH    Disconnected Windows      492 days ago    2023.2.1        EMILY-PC                          25 November 2022  Emily's development machine
M8JKL    Disconnected Android      483 days ago    2023.2.1        samsung-galaxy-s10                01 February 2023  Dev team test device
R2QWP    Disconnected Android      483 days ago    2023.2.1        oneplus-8                         01 February 2023  QA test phone
B4ZKL    Disconnected iOS          480 days ago    2022.10.7       Sarahs-iPhone                     01 February 2023  Sarah's old phone
C7YXD    Disconnected iOS          455 days ago    2023.4.25       Roberts-MacBook-Pro               15 February 2023  Robert's previous work laptop
L9PLZ    Disconnected iOS          390 days ago    2023.4.25       Roberts-iPhone                    01 February 2023  Robert's iPhone
F3HQL    Disconnected iOS          385 days ago    2023.4.25       iPhone-88                         14 March 2023     Old iPhone for testing
K5Y9F    Connected    Windows      25 days ago     2024.4.30.1573  DESKTOP-J9FUI3J                   15 August 2020    Development machine
Z7MPT    Connected    Darwin       20 days ago     2022.10.7       Alices-MacBook.local              20 August 2020    Alice's MacBook
T6YHK    Connected    Windows      15 days ago     2024.4.30.1578  DESKTOP-U29X3CD                   01 September 2020 Development server
X1CVB    Connected    Windows      10 days ago     2024.4.30.1573  DESKTOP-AXYZ123                   02 July 2020      Office desktop
XW5X5    Connected    Darwin       6 days ago      2021.9.27.0     Andys-iMac.zyxel.com              07 October 2021   Andy's iMac
V88RY    Connected    Windows      19 hours ago    2024.4.30.1578  DESKTOP-U98V3DV                   01 April 2020     Emily's work laptop
L2D4D    Connected    Windows      3 hours ago     2024.4.30.1578  DESKTOP-LIG38H0                   25 July 2022      Emily's second work laptop
L9TYC    Connected    Linux        3 hours ago     2023.11.14.1726 dev-server-02                     12 March 2023     Development server
T4MNR    Connected    Android      2 hours ago     2022.12.12      pixel-4a                          03 July 2023      Development mobile
V2KZQ    Connected    Linux        1 hour ago      2023.12.12      staging-server-01                 24 November 2022  Staging server
J5CVB    Connected    Windows      30 minutes ago  2024.4.30.1578  DESKTOP-FS3JH9J                   01 March 2023     Development server
XWLX5    Connected    Darwin       17 minutes ago  2022.9.27.410   Alices-MBP                        10 May 2022       Alice's MacBook Pro
T1BGT    Connected    Darwin       15 minutes ago  2021.9.27.0     Andys-iMac.zyxel.com              07 October 2021   Andy's iMac
Q9PWF    Connected    Windows      10 minutes ago  2024.4.30.1578  LISA-PC                           29 April 2024     Lisa's home PC
P9HXC    Connected    Linux        10 minutes ago  2023.11.14.1726 ubuntu-server                     16 June 2022      Ubuntu demo server
G8XDR    Connected    Windows      6 minutes ago   2024.3.15.1514  DESKTOP-KL89UY                    12 May 2021       Jane's office desktop
N7YJP    Connected    iOS          5 minutes ago   2024.1.11.1411  james-iPhone                      12 July 2023      James' iPhone
B7WSV    Connected    Windows      5 minutes ago   2024.3.15.1514  WILLIAMS-LAPTOP                   20 March 2024     William's work laptop
K6TYD    Connected    Darwin       5 minutes ago   2023.6.1.601    Admin-MacBook.local               23 February 2023  Admin MacBook
J3GLZ    Connected    Windows      3 minutes ago   2024.1.11.1411  CHARLIE-PC                        16 December 2022  Charlie's work PC
M7HYQ    Connected    iOS          3 minutes ago   2024.1.11.1411  Emma-iPhone                       23 June 2023      Emma's iPhone
V8YXC    Connected    Android      2 minutes ago   2024.4.30.1578  pixel-5                           01 June 2021      QA test phone
D5HTV    Connected    iOS          2 minutes ago   2023.12.12      Ians-iPhone                       18 August 2023    Ian's iPhone
M4FJY    Connected    iOS          1 minute ago    2024.3.15       localhost                         16 December 2022  John's current iPhone

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