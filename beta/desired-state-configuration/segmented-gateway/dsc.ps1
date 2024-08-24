Param(
    [Parameter(Mandatory=$true)]
    [string]$orgId,

    [Parameter(Mandatory=$true)]
    [string]$apiKey = "",

    [switch]$dryrun  # will be $true if -dryrun argument is included
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

if ($apiKey -eq "") {
    $apiKey = $env:ENCLAVE_API_KEY
}

if ($apiKey -eq "") {
    Write-Error "No API key provided; either specify the 'apiKey' argument, or set the ENCLAVE_API_KEY environment variable."
    return;
}

# ------------

# Number of desired segments
$desiredUserSegments = 4

# Find all [client-alwayson] tagged systems, and attach a new tag, [segment-1]..[segment-2] etc. divided between marked systems
$userMarkerTag = "client-alwayson"

# Find all [docker-gw] tagged and configure each system to act as a gateway
$gatewayMarkerTag = "gw-host"

$gatewaySubnets = @(
    "10.11.5.10/32",
    "10.16.5.10/32",
    "10.17.5.10/32",
    "10.17.37.10/32",
    "10.17.69.10/32",
    "10.18.5.10/32",
    "10.11.0.0/16",
    "10.12.0.0/16",
    "10.16.0.0/16",
    "10.17.0.0/16",
    "10.18.0.0/16",
    "10.20.0.0/16"
)

# ------------

$currentDateTime = Get-Date -Format "yyyy-MM-dd"
$notes = "Auto-provisioned $currentDateTime"

$headers = @{Authorization = "Bearer $apiKey"}
$contentType = "application/json";

# ------------

function Invoke-EnclaveApi {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [string]$Method,

        [Parameter(Mandatory = $false)]
        [object]$Body
    )

    try {
        if ($null -ne $Body) {
            return Invoke-RestMethod -ContentType $contentType -Method $Method -Uri $Uri -Headers $headers -Body ($Body | ConvertTo-Json -Depth 10)
        } else {
            return Invoke-RestMethod -ContentType $contentType -Method $Method -Uri $Uri -Headers $headers
        }
    } catch {
        throw "Request to $Uri failed with error: $($_.Exception.Message)"
    }
}

function Invoke-PaginatedApi {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [string]$Method,

        [Parameter(Mandatory = $false)]
        [object]$Body
    )

    $allItems = @()
    $currentUri = $Uri
    $i = 1

    try
    {
        while ($null -ne $currentUri)
        {
            if ($null -ne $Body) {
                $response = Invoke-RestMethod -ContentType $contentType -Method $Method -Uri $currentUri -Headers $headers -Body ($Body | ConvertTo-Json -Depth 10)
            } else {
                $response = Invoke-RestMethod -ContentType $contentType -Method $Method -Uri $currentUri -Headers $headers
            }

            # Cloudflare rate limit is 1200 requests over 300 seconds cumulatively. Lowest this value can safely be is 250ms
            Start-Sleep -Milliseconds 300
    
            # Add items to the collection if they exist
            if ($response -and $response.items) {
                $allItems += $response.items
            }

            # Check links.next for pagination
            if ($response.links -and $response.links.next) {
                $currentUri = $response.links.next
            } else {
                $currentUri = $null
            }

            $i++
        }

        # returned object doesn't include .items[$i]
        return $allItems
    }
    catch
    {
        throw "Request to $Uri failed with error: $($_.Exception.Message)"
    }
}

# ------------

if ($dryrun) {
    Write-Host "Dry run flag detected, no changes will be made."
}

# ------------
# Arrange System Tags

# Find all systems with the userMarkerTag
$response = Invoke-PaginatedApi -Method Get -Uri "https://api.enclave.io/org/$orgId/systems?search=tags%3A%20$userMarkerTag"

if ($response.Count -le 0) {
    Write-Host "No systems tagged [$userMarkerTag]."
} else {
    Write-Host "Found $($response.Count) systems tagged [$userMarkerTag]. Adding a new [segment-n] tag to each..."

    $itemsPerSegment = [math]::Ceiling($response.Count / $desiredUserSegments)

    # Iterate over the systems and tag each with a new [segment-n] tag
    for ($i = 0; $i -lt $response.Count; $i++)
    {
        $systemId = $response[$i].systemId;
        $description  = $response[$i].description;

        # Calculate the segment number (1-based)
        $segmentNumber = [math]::Ceiling(($i + 1) / $itemsPerSegment)
        
        # Create the segment string
        $segmentTag = "segment-$segmentNumber"
        
        # Get current item's tags, removing any existing "segment-*" tags
        $tagSet = $($response[$i].tags | Where-Object { $_.tag -notmatch '^segment-\d+$' } | Select-Object -ExpandProperty tag)

        # Add the new [segment-n] tag
        $tagSet = $tagSet + $segmentTag

        # Create the patch object for this system
        $systemPatch = @{
            tags = $tagSet
        }

        # Display the updated tagset
        Write-Output "Updating system tagset $systemId ($description) to $(($systemPatch.tags | ForEach-Object { "[$_]" }) -join ', ')"

        # Patch the system
        if (-not $dryrun) {
            $null = Invoke-PaginatedApi -Method Patch -Uri "https://api.enclave.io/org/$orgId/systems/$systemId" -Body $systemPatch
        }
    }
}

# ------------
# Arrange System Gateways

# Find all systems with the gatewayMarkerTag
$response = Invoke-PaginatedApi -Method Get -Uri "https://api.enclave.io/org/$orgId/systems?search=tags%3A%20$gatewayMarkerTag"

if ($response.Count -le 0) {
    Write-Host "No systems tagged [$gatewayMarkerTag]."
} else {
    Write-Host "Found $($response.Count) systems tagged [$gatewayMarkerTag]. Configuring each system to act as a gateway..."

    # Iterate over the systems and enable each to act as a gateway overwriting any existing routes.
    for ($i = 0; $i -lt $response.Count; $i++)
    {
        $systemId = $response[$i].systemId;
        $description  = $response[$i].description;

        # Initialize the gatewayRoutes array
        $gatewayRoutes = @()

        # Build the gatewayRoutes array based on the gatewaySubnets list
        foreach ($subnet in $gatewaySubnets) {
            $gatewayRoutes += @{
                subnet = $subnet
                userEntered = $true
                weight = 0
                name = $notes
            }
        }

        # Create the patch object for this system
        $systemPatch = @{
            gatewayRoutes = $gatewayRoutes
        }
        
        # Display the updated tagset
        Write-Output "Updating system $systemId ($description) to act as a gateway, setting routes: $gatewaySubnets"

        # Patch the system
        if (-not $dryrun) {
            $null = Invoke-PaginatedApi -Method Patch -Uri "https://api.enclave.io/org/$orgId/systems/$systemId" -Body $systemPatch
        }
    }
}

# ------------
# Arrange Policies

Write-Host "Creating template policies..."

# Array to hold all policy models
$policiesModel = @()

# Create the desired number of policies, one for each Segment
for ($i = 1; $i -le $desiredUserSegments; $i++) {
    # Create a new policy model object
    $policyModel = @{
        type = "Gateway"
        description = "Segment-$i Template"
        isEnabled = $true
        notes = "$notes"
        senderTags = @(
            "segment-$i"
        )
        acls = @(
            @{
                protocol = "Tcp"
                ports = "135"
                description = "Microsoft RPC Endpoint Mapper"
            },
            @{
                protocol = "Tcp"
                ports = "49152-65535"
                description = "Dynamic/Private Port Range"
            },
            @{
                protocol = "Tcp"
                ports = "389"
                description = "LDAP over TCP"
            },
            @{
                protocol = "Udp"
                ports = "389"
                description = "LDAP over UDP"
            },
            @{
                protocol = "Tcp"
                ports = "636"
                description = "LDAPS over SSL"
            },
            @{
                protocol = "Tcp"
                ports = "3268-3269"
                description = "LDAP Global Catalog Service"
            },
            @{
                protocol = "Tcp"
                ports = "53"
                description = "DNS over TCP"
            },
            @{
                protocol = "Udp"
                ports = "53"
                description = "DNS over UDP"
            },
            @{
                protocol = "Tcp"
                ports = "88"
                description = "Kerberos Authentication over TCP"
            },
            @{
                protocol = "Udp"
                ports = "88"
                description = "Kerberos Authentication over UDP"
            },
            @{
                protocol = "Tcp"
                ports = "445"
                description = "Microsoft SMB File Sharing"
            },
            @{
                protocol = "Tcp"
                ports = "464"
                description = "Kerberos Password Change/Set over TCP"
            },
            @{
                protocol = "Udp"
                ports = "464"
                description = "Kerberos Password Change/Set over UDP"
            },
            @{
                protocol = "Udp"
                ports = "123"
                description = "NTP (Network Time Protocol) (UDP/123)"
            },
            @{
                protocol = "Icmp"
                description = "ICMP"
            },
            @{
                protocol = "Tcp"
                ports = "443"
                description = "HTTPS"
            }        
        )
        gateways = @()
        gatewayTrafficDirection = "Exit"
        gatewayAllowedIpRanges = @()
        gatewayPriority = "Balanced"
    }

    # Add the created policy model to the array
    $policiesModel += $policyModel
}

$response = Invoke-PaginatedApi -Method Get -Uri "https://api.enclave.io/org/$orgId/policies?include_disabled=true"

foreach ($policyModel in $policiesModel)
{
    # create policy
    Write-Host "  Creating policy: $($policyModel.description)"
    $null = Invoke-PaginatedApi -Method Post -Uri "https://api.enclave.io/org/$orgId/policies" -Body $policyModel
    
}

Write-Host "Done"