# Produce a report of active Enclave systems for a specific tenant

This PowerShell script takes an Enclave `Personal Access Token` and `Organisation Id` to generate a CSV report of the tenant security log.

Example output:

```
PS C:\git\api-automation-scripts\reports\security-logs-report> .\security-logs-report.ps1
Warning: The file 'output.csv' already exists and will be overwritten.
Do you want to proceed? (y/n): y
Requesting page 1/43
Requesting page 2/43
..
Requesting page 43/43
8617 log entries successfully written to output.csv
```

## Using this PowerShell script

You may run the PowerShell script without any arguments, it will prompt you to provide a personal access token and Organisation ID and save the retrived logs into `.\output.csv`

```
.\security-logs-report.ps1

Please enter your Enclave Personal Access Token: <apiKey>
Please enter your Enclave Organisation Id: <orgId>
```

Or you can provide arguments to the script:

```bash
.\security-logs-report.ps1 -orgId <orgId> -apiKey <apiKey> -outFile <filename>
```

## Requirements

You will need to know:

- Your Enclave Organisation Id
- Your Enclave API Key

You can find the Organisation Id by selecting the appropriate tenant in the Enclave Portal and visiting https://portal.enclave.io/my/settings, and visit your account page at https://portal.enclave.io/account to generate a Personal Access Token (API Key) if you don't already have one.