Param(
    [Parameter(Mandatory=$false)]
    [string]$orgId,

    [Parameter(Mandatory=$false)]
    [string]$apiKey
)

$ErrorActionPreference = "Stop"

if (-not $apiKey) {
    $apiKey = if ($env:ENCLAVE_API_KEY) {
        $env:ENCLAVE_API_KEY
    } else {
        Read-Host "Please enter your Enclave Personal Access Token"
    }
}

if (-not $apiKey) {
    Write-Error "No API key provided; either specify the '-apiKey' argument, or set the ENCLAVE_API_KEY environment variable."
    return;
}

if (-not $orgId) {
    $orgId = Read-Host "Please enter your Enclave Organisation Id"
}

function Get-HumanReadableTimeDifference {
    param ([datetime]$pastTime)

    $timeDifference = [datetime]::Now - $pastTime

    if ($timeDifference.TotalDays -ge 2) {
        return "{0} days ago" -f [math]::Floor($timeDifference.TotalDays)
    } elseif ($timeDifference.TotalHours -ge 2) {
        return "{0} hours ago" -f [math]::Floor($timeDifference.TotalHours)
    } elseif ($timeDifference.TotalMinutes -ge 2) {
        return "{0} minutes ago" -f [math]::Floor($timeDifference.TotalMinutes)
    } else {
        return "{0} seconds ago" -f [math]::Floor($timeDifference.TotalSeconds)
    }
}
function Format-DateTime {
    param (
        [datetime]$dateTime
    )
    return Get-Date $dateTime -Format "dd MMMM yyyy"
}

$headers = @{Authorization = "Bearer $apiKey"}
$contentType = "application/json"

$uri = "https://api.enclave.io/org/$orgId/systems"
$systems = @()

do {
    $response = Invoke-RestMethod -ContentType $contentType -Method Get -Uri $uri -Headers $headers
    $systems += $response.items | Select-Object systemId, state, lastSeen, enrolledAt, enclaveVersion, hostname, platformType, description, virtualAddress

    $uri = if ($null -ne $response.links.next -and $response.links.next -ne "") { $response.links.next } else { $null }
} while ($uri)


$systems = $systems | Sort-Object lastSeen

foreach ($system in $systems) {
    $system.lastSeen = if ($system.lastSeen) { Get-HumanReadableTimeDifference -pastTime $system.lastSeen } else { "Never seen" }
    $system.enrolledAt = Format-DateTime -dateTime $system.enrolledAt
}

$systems | Format-Table -Property systemId, virtualAddress, state, platformType, lastSeen, enclaveVersion, hostname, enrolledAt, description -AutoSize

Write-Output "System count: $($systems.Count)`n"