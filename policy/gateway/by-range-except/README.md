# Filter an Enclave Gateway Policy to provide a route to ITGlue IP addresses

Enclave can help to protect access to ITGlue accounts by using ITGlue's [IP Access Control](https://www.itglue.com/features/ip-access-control/) feature and configuring Enclave to route traffic to their platform via an Enclave Gateway with a known static IP address.

If you do not wish to route all traffic through the Enclave gateway, follow these steps and use this script to configure an Enclave policy.

1. Setup an Enclave Gateway
2. Enable the Gateway to route traffic to any IP address, using `0.0.0.0/0`
3. Setup a Gateway Access Policy, choose sender tags and the Enclave Gateway
4. Configure subnet filtering rules on the policy to only route traffic for ITGlue IP addresses
5. Use ITGlue's [IP Access Control](https://www.itglue.com/features/ip-access-control/) to restrict access to the Enclave Gateway IP address

## Using this PowerShell script

Unfortunately, ITGlue do not publish IP addresses of their services so we need to dynamically resolve ITGlue server IP addresses from DNS.

This script accepts ITGlue service DNS records as inputs (e.g. `customer1.eu.itglue.com`), and resolves those hostnames into IP addresses (e.g. `18.196.134.151`) which are then added as IP filtering rules to the relevant Enclave Gateway Policy using the Enclave API.

You should schedule this script to run on a regular basis as ITGlue service IP addresses may change. We recommend this script is run by your RMM platform or as an Azure Function on a recurring timer. You should use the platform's secrets management capability to safely provide your `<apiKey>` to the script.

```bash
.\gateway-policy-by-dns.ps1 -orgId <orgId> `
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


```bash
.\gateway-policy-by-dns.ps1 -orgId <orgId> `
                                -apiKey <apiKey> `
                                -policyName <policyName> `
                                -dnsNames customer1.eu.itglue.com, `
                                          itglue-cdn-prod-itglue.com, `
                                          itg-api-prod-api-lb-us-west-2.itglue.com `
                                          itg-api-prod-eu-api-lb-eu-central-1.itglue.com `
                                -test
```

## Requirements

You will need to know:

- Your Enclave Organisation ID
- Your Enclave API Key
- Your Enclave Policy Name
- Your ITGlue service hostnames (DNS records)