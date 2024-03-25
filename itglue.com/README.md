# Filter an Enclave Gateway Policy to provide a route to IT Glue IP addresses

ITGlue do not publish the IP addresses of the services. If you wish to whitelist access to ITGlue using Enclave, you will need to schedule a script to dynamically resolve ITGlue server IP addresses on a regular basis and use the Enclave API surface to automatically update IP filtering rules on an Enclave Gateway policy.

We recommend you schedule execution of this script on your RMM platform or as an Azure Function on a recurring timer, using the platform's secrets management capability to safely provide the `<apiKey>` value to the PowerShell script.

```bash
 .\gateway-policy-dns-update.ps1 -orgId <orgId> `
                                 -apiKey <apiKey> `
                                 -policyName <policyName> `
                                 -dnsNames <dnsname1>,<dnsname2>,<dnsnameX> `
                                 -test
```

Remove the `-test` argument to make the API call and change the Enclave policy configuration.