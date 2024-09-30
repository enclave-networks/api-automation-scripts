# Filter an Enclave Gateway Policy to exclude routing traffic for specific DNS names

Enclave can be used to route all Internet traffic via systems acting as Enclave Gateways. This usually means that each Enclave Gateway is configured to provide a route to `0.0.0.0/0` for all connected clients, but sometimes you may not want all traffic to traverse the gateway hosts.

This script will help you programmatically convert DNS names (e.g. `google.com`) into Policy exclusions in Enclave for just such exclusions. It is advised that customers set this script to run at scheduled intervals as DNS names change periodically, and re-running this script will ensure Policy is configured to route based on the most up to date IP information available.

If you configure an Enclave Internet Gateway with DNS-based exclusions, follow these steps and use this script to configure an Enclave policy.

1. Setup an Enclave Gateway
2. Enable the Gateway to route traffic to any IP address, using `0.0.0.0/0`
3. Setup a Gateway Access Policy, choose sender tags and the Enclave Gateway
4. Run this script to configure subnet filtering rules on the above policy

## Using this PowerShell script

This script accepts a set of DNS records as inputs (e.g. `google.com, microsoft.com`), and resolves those hostnames into IP addresses (e.g. `20.70.246.20`) which are then added as IP filtering rules to the relevant Enclave Gateway Policy, using the Enclave API.

You should schedule this script to run on a regular basis as IP addresses may change. We recommend this script is run by your RMM platform or as an Azure Function on a recurring timer. You should use the platform's secrets management capability to safely provide your `<apiKey>` to the script.

```powershell
PS C:\> gateway-policy-by-range-except.ps1 -orgId <orgId> `
                                           -apiKey <apiKey> `
                                           -policyName <policyName> `
                                           -dnsNames <dnsname1>, `
                                                     <dnsname2>, `
                                                     <dnsnameX> `
                                           -test

```

Remove the `-test` argument to make the API call and change the Enclave policy configuration.

## Example

For example, if your tenant name is `customer1` you may use the script as follows:


```powershell
PS C:\> gateway-policy-by-range-except.ps1 -orgId <orgId> `
                                           -apiKey <apiKey> `
                                           -policyName <policyName> `
                                           -dnsNames microsoft.com, `
                                                     google.com `
                                           -test
```

## Requirements

You will need to know:

- Your Enclave Organisation ID
- Your Enclave API Key
- Your Enclave Policy Name
- The relevant hostnames (DNS records) of the services you wish to exclude from Gateways