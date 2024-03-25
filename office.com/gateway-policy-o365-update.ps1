Param(
    [Parameter(Mandatory=$true)]
    [string]$orgId,

    [Parameter()]
    [string]$apiKey = "",

    [Parameter(Mandatory=$true)]
    [string]$policyName,

    [Parameter()]
    [switch]$test = $false
)

$ErrorActionPreference = "Stop"

if ($apiKey -eq "") {
    $apiKey = $env:ENCLAVE_API_KEY
}

if ($apiKey -eq "") {
    Write-Error "No API key provided; either specify the 'apiKey' argument, or set the ENCLAVE_API_KEY environment variable."
    return;
}

$headers = @{Authorization = "Bearer $apiKey"}
$contentType = "application/json";

$jsonUrl = "https://endpoints.office.com/endpoints/worldwide?clientrequestid=b10c5ed1-bad1-445f-b386-b919946339a7"
$jsonResponse = Invoke-RestMethod -Uri $jsonUrl -Method Get -Headers $headers

$subnets = @()

foreach ($item in $jsonResponse) {
    if ($item.ips) {
        foreach ($ip in $item.ips) {
            if ($ip -match '\.') {
                $description = if ($item.serviceAreaDisplayName) { "Office 365 ($($item.serviceAreaDisplayName))" } else { "Office 365" }
                $subnet = @{
                    ipRange = $ip
                    description = $description
                }
                $subnets += $subnet
            }
        }
    }
}

$policies = Invoke-RestMethod -ContentType $contentType -Method Get -Uri "https://api.enclave.io/org/$orgId/policies?search=$policyName.Trim()" -Headers $headers;

if ($policies.total -eq 0) {
    Write-Error "No policies found with name $policyName."
    return;
}
elseif ($policies.total -gt 1) {
    Write-Error "Multiple policies found with name $policyName; please provide a more specific name."
    return;
}

$policyId = $policies.items[0].id;

Write-Host $policies | ConvertTo-Json;

Write-Host "Found policy $policyName with id $policyId."

$policyPatch = @{
    "gatewayAllowedIpRanges" = $subnets
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

    Write-Host "Updated policy with $($subnets.Count) IP addresses."
}
