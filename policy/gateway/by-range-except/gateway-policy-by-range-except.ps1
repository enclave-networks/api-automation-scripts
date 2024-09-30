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

if ($apiKey -eq "") {
    $apiKey = $env:ENCLAVE_API_KEY
}

if ($apiKey -eq "") {
    Write-Error "No API key provided; either specify the 'apiKey' argument, or set the ENCLAVE_API_KEY environment variable."
    return;
}

$currentDateTime = Get-Date -Format "yyyy-MM-dd"
$notes = "Auto-provisioned by API on $currentDateTime, do not delete."

$headers = @{Authorization = "Bearer $apiKey"}
$contentType = "application/json";

# ------------

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

function Convert-IPToInteger {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ip
    )

    $ip -split "\." | ForEach-Object { [uint32]$_ } | ForEach-Object -Begin { $result = [uint32]0 } -Process { $result = $result * 256 + $_ } -End { $result }
}

function Convert-IntegerToIP {
    param (
        [Parameter(Mandatory = $true)]
        [uint32]$uint
    )

    $byte1 = $uint -shr 24
    $byte2 = ($uint -shr 16) -band 0xFF
    $byte3 = ($uint -shr 8) -band 0xFF
    $byte4 = $uint -band 0xFF
    "$byte1.$byte2.$byte3.$byte4"
}

function Get-DnsIPv4Addresses {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$dnsNames
    )
    $ipAddresses = @()

    foreach ($dnsName in $dnsNames)
    {
        try
        {
            # resolve name and expand the IPAddress property
            $resolved = Resolve-DnsName $dnsName -Type A | Select-Object -ExpandProperty IPAddress

            foreach ($ip in $resolved) {
                $ipAddresses += [PSCustomObject]@{
                    Name    = $dnsName
                    Address = $ip
                }
            }
        }
        catch {
            Write-Host "Failed resolving dnsName: $_"
        }
    }

    if ($ipAddresses.Count -eq 0) {
        Write-Error "No DNS addresses found for any of the provided DNS names."
        return
    }

    return $ipAddresses
}

function Get-IntegerRangesWithExclusions {
    param (
        [uint32[]]$Exclusions
    )
    $uint_min = 0
    $uint_max = 4294967295
    $ranges = @()

    # Sort the exclusions in ascending order
    $sortedExclusions = $Exclusions | Sort-Object

    # Start the current range at the minimum value
    $currentStart = $uint_min

    # Iterate over each exclusion
    foreach ($exclusion in $sortedExclusions)
    {
        # Skip exclusions less than the current start
        if ($exclusion -lt $currentStart) {
            continue
        }

        # Add the range from currentStart to one less than the current exclusion
        if ($currentStart -lt $exclusion)
        {
            $ranges += [PSCustomObject]@{
                Start = $currentStart
                End   = $($exclusion - 1)
            }
        }

        # Move currentStart to one more than the current exclusion
        $currentStart = $exclusion + 1
    }

    # Add the final range from currentStart to uint_max if needed
    if ($currentStart -le $uint_max)
    {
        $ranges += [PSCustomObject]@{
            Start = $currentStart
            End   = $uint_max
        }
    }

    return $ranges
}

function Get-RangesWithExclusions {
    param (
        [Parameter(Mandatory = $true)]
        [uint32[]]$integerExclusions
    )

    # build all ip address from 0 to 4294967295 as range sets, excluding the specified integer values
    $int_ranges = Get-IntegerRangesWithExclusions -Exclusions $exclusions

    # convert integer range sets to IPv4 encoding
    $ranges = $int_ranges | ForEach-Object {
        $startIP = Convert-IntegerToIP -uint $_.Start
        $endIP = Convert-IntegerToIP -uint $_.End
        [PSCustomObject]@{
            ipRange = "$startIP - $endIP"
            notes = "$notes"
        }
    }

    return $ranges;
}

function Main()
{
    try
    {
        # resolve hostnames into ipv4 addresses
        $ipAddressList = Get-DnsIPv4Addresses -dnsNames $dnsNames

        # convert each resolved address into a set of integer encoding for exclusion
        $exclusions = $ipAddressList | ForEach-Object {
            Convert-IPToInteger -ip $_.Address
        }
    
        # build ranges around the exclusion integers, return ipv4 formatted ranges
        $ranges = Get-RangesWithExclusions -integerExclusions $exclusions
        $ranges | Format-Table -AutoSize

        $response = Invoke-PaginatedApi -Method Get -Uri "https://api.enclave.io/org/$orgId/policies?search=$policyName";

        if ($response.total -eq 0)
        {
            Write-Error "No policies found with name $policyName."
            return;
        }
        elseif ($response.total -gt 1)
        {
            Write-Error "Multiple policies found with name $policyName; please provide a more specific name."
            return;
        }

        Write-Host "Found policy $($response.description) with id $($response.id)"

        $policyPatch = @{
            notes = "$notes Subnet filtering applied for $dnsNames"
            "gatewayAllowedIpRanges" = $ranges
        }

        if ($test)
        {
            Write-Host "Test mode enabled; not updating policy. Would have updated policy $($response.id) with the following patch:"
            Write-Host $($policyPatch | ConvertTo-Json -Depth 10)
        }
        else
        {
            Invoke-PaginatedApi -Method Patch -Uri "https://api.enclave.io/org/$orgId/policies/$($response.id)" -Body $policyPatch

            Write-Host "Updated policy with $($ranges.Count) IP ranges to filter out $dnsNames."
        }
    }
    catch
    {
        Write-Host "$($_.Exception.Message) at line $($_.InvocationInfo.ScriptLineNumber)"
    }
}

main