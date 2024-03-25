Param(
    [Parameter(Mandatory=$true)]
    [string]$orgId,

    [Parameter()]
    [string]$apiKey = "",

    [Parameter(Mandatory=$true)]
    [string]$policyName,

    [Parameter(Mandatory=$true)]
    [String[]]$dnsNames,

    [Parameter()]
    [switch]$test = $false
)

$ErrorActionPreference = "Stop"

if ($apiKey -eq "")
{
    $apiKey = $env:ENCLAVE_API_KEY
}

if ($apiKey -eq "")
{
    Write-Error "No API key provided; either specify the 'apiKey' argument, or set the ENCLAVE_API_KEY environment variable."
    return;
}

# Attach our api key to each request.
$headers = @{Authorization = "Bearer $apiKey"}
$contentType = "application/json";

$policies = Invoke-RestMethod -ContentType $contentType -Method Get -Uri "https://api.enclave.io/org/$orgId/policies?search=$policyName" -Headers $headers;

if ($policies.total -eq 0)
{
    Write-Error "No policies found with name $policyName."
    return;
}
elseif ($policies.total -gt 1)
{
    Write-Error "Multiple policies found with name $policyName; please provide a more specific name."
    return;
}

$policyId = $policies.items[0].id;

Write-Host "Found policy $policyName with id $policyId."

# Get all IPv4 addresses for all provided DNS names:
$dnsAddresses = @();

foreach ($dnsName in $dnsNames)
{
    "Querying DNS for $dnsName..."
    try {
        $dnsAddresses += Resolve-DnsName $dnsName A | 
            Select-Object -ExpandProperty IPAddress | 
            ForEach-Object {@{
                ipRange = "$_"
                description = "$dnsName" 
            }}
    }
    catch {
        <#Do this if a terminating exception happens#>
        Write-Host "Failed to resolve DNS name $dnsName; continuing : $_"
    }
}

if ($dnsAddresses.Count -eq 0)
{
    Write-Error "No DNS addresses found for any of the provided DNS names."
    return;
}

$policyPatch = @{
    "gatewayAllowedIpRanges" = $dnsAddresses
} | ConvertTo-Json

if ($test)
{
    Write-Host "Test mode enabled; not updating policy."
    Write-Host "Would have updated policy $policyId with the following patch:"
    Write-Host $policyPatch
}
else
{
   Invoke-RestMethod -ContentType $contentType -Method Patch -Uri "https://api.enclave.io/org/$orgId/policies/$policyId" -Headers $headers -Body $policyPatch

   Write-Host "Updated policy with $($dnsAddresses.Count) IP addresses."
}