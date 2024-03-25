# Filter an Enclave Gateway Policy to provide a route to Office 365 IP addresses

Microsoft publish the IP addresses and subnet ranges for their Office 365 services here [https://endpoints.office.com/endpoints/worldwide?clientrequestid=b10c5ed1-bad1-445f-b386-b919946339a7](https://endpoints.office.com/endpoints/worldwide?clientrequestid=b10c5ed1-bad1-445f-b386-b919946339a7).

This script extracts the `IPv4` addresses and uses the Enclave API surface to automatically update IP filtering rules on an Enclave Gateway policy.

We recommend you schedule execution of this script on your RMM platform or as an Azure Function on a recurring timer, using the platform's secrets management capability to safely provide the `<apiKey>` value to the PowerShell script.

```bash
 .\gateway-policy-o365-update.ps1 -orgId <orgId> `
                                  -apiKey <apiKey> `
                                  -policyName <policyName> `
                                  -test
```

Remove the `-test` argument to make the API call and change the Enclave policy configuration.