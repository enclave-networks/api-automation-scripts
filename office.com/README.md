# Filter an Enclave Gateway Policy to provide a route to Office 365 IP addresses

Enclave can help to protect access to Office 365 accounts. You can configure O365 to only accept logins from the known static IP addresses of one or more Enclave Gateways. If you wish to selectively route only O365 traffic through an Enclave gateway (and not all Internet traffic), follow these steps and use this script to configure an Enclave policy.

1. Setup an Enclave Gateway
2. Enable the Gateway to route traffic to any IP address, using `0.0.0.0/0`
3. Setup a Gateway Access Policy, choose sender tags and the Enclave Gateway
4. Configure subnet filtering rules on the policy to only route traffic for to Microsoft Office 365 service IP addresses

## Using this PowerShell script

Microsoft publish the IP addresses and subnet ranges for their Office 365 services here [https://endpoints.office.com/endpoints/worldwide?clientrequestid=b10c5ed1-bad1-445f-b386-b919946339a7](https://endpoints.office.com/endpoints/worldwide?clientrequestid=b10c5ed1-bad1-445f-b386-b919946339a7), however the document is complex, contains duplicated IP addresses and will change over time.

This script extracts and de-duplicates the `IPv4` addresses from the Microsoft JSON document and uses the Enclave API surface to automatically update the subnet filtering rules on an Enclave Gateway policy.

We recommend you schedule execution of this script on your RMM platform or as an Azure Function on a recurring timer to account for IP address changes, and use the platform's secrets management capability to safely provide your `<apiKey>` to the script.

```bash
 .\gateway-policy-o365-update.ps1 -orgId <orgId> `
                                  -apiKey <apiKey> `
                                  -policyName <policyName> `
                                  -test
```

Remove the `-test` argument to make the API call and change the Enclave policy configuration.

Once the script has run, the updated policy will contain a set of subnet filters similar to this:

| Allowed range | Description |
|-|-|
| 104.47.0.0/17 | Office 365 (Exchange Online) |
| 13.107.128.0/22 | Office 365 (Exchange Online) |
| 13.107.18.10/31 | Office 365 (Exchange Online) |
| 13.107.6.152/31 | Office 365 (Exchange Online) |
| 131.253.33.215/32 | Office 365 (Exchange Online) |
| 132.245.0.0/16 | Office 365 (Exchange Online) |
| 150.171.32.0/22 | Office 365 (Exchange Online) |
| 204.79.197.215/32 | Office 365 (Exchange Online) |
| 23.103.160.0/20 | Office 365 (Exchange Online) |
| 40.104.0.0/15 | Office 365 (Exchange Online) |
| 40.107.0.0/16 | Office 365 (Exchange Online) |
| 40.92.0.0/15 | Office 365 (Exchange Online) |
| 40.96.0.0/13 | Office 365 (Exchange Online) |
| 52.100.0.0/14 | Office 365 (Exchange Online) |
| 52.238.78.88/32 | Office 365 (Exchange Online) |
| 52.96.0.0/14 | Office 365 (Exchange Online) |
| 13.107.140.6/32 | Office 365 (Microsoft 365 Common and Office Online) |
| 13.107.18.15/32 | Office 365 (Microsoft 365 Common and Office Online) |
| 13.107.6.171/32 | Office 365 (Microsoft 365 Common and Office Online) |
| 13.107.6.192/32 | Office 365 (Microsoft 365 Common and Office Online) |
| 13.107.9.192/32 | Office 365 (Microsoft 365 Common and Office Online) |
| 20.190.128.0/18 | Office 365 (Microsoft 365 Common and Office Online) |
| 20.20.32.0/19 | Office 365 (Microsoft 365 Common and Office Online) |
| 20.231.128.0/19 | Office 365 (Microsoft 365 Common and Office Online) |
| 40.126.0.0/18 | Office 365 (Microsoft 365 Common and Office Online) |
| 52.108.0.0/14 | Office 365 (Microsoft 365 Common and Office Online) |
| 52.244.37.168/32 | Office 365 (Microsoft 365 Common and Office Online) |
| 104.146.128.0/17 | Office 365 (SharePoint Online and OneDrive for Business) |
| 13.107.136.0/22 | Office 365 (SharePoint Online and OneDrive for Business) |
| 150.171.40.0/22 | Office 365 (SharePoint Online and OneDrive for Business) |
| 40.108.128.0/17 | Office 365 (SharePoint Online and OneDrive for Business) |
| 52.104.0.0/14 | Office 365 (SharePoint Online and OneDrive for Business) |
| 13.107.64.0/18 | Office 365 (Skype for Business Online and Microsoft Teams) |
| 52.112.0.0/14 | Office 365 (Skype for Business Online and Microsoft Teams) |
| 52.122.0.0/15 | Office 365 (Skype for Business Online and Microsoft Teams) |
| 52.238.119.141/32 | Office 365 (Skype for Business Online and Microsoft Teams) |
| 52.244.160.207/32 | Office 365 (Skype for Business Online and Microsoft Teams) |

## Requirements

You will need to know:

- Your Enclave Organisation ID
- Your Enclave API Key
- Your Enclave Policy Name