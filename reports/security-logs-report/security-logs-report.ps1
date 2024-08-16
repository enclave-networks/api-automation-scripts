Param(
    [Parameter(Mandatory=$false)]
    [string]$orgId,

    [Parameter(Mandatory=$false)]
    [string]$apiKey,

    [Parameter(Mandatory=$false)]
    [string]$outfile
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

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

if (-not $outfile) {
    $outfile = "output.csv"
}

$headers = @{Authorization = "Bearer $apiKey"}
$contentType = "application/json"

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

# ------------

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

function Get-AllEnclaveLogs {
    param (
        [Parameter(Mandatory = $true)]
        [string]$InitialUri,

        [Parameter(Mandatory = $false)]
        [hashtable]$Headers
    )

    $allItems = @()
    $currentUri = $InitialUri
    $i = 0

    while ($null -ne $currentUri) {
        $i++
        $response = Invoke-EnclaveApi -Method Get -Uri $currentUri

        Write-Host "Requesting page $i/$($response.metadata.lastPage+1)"

        # Cloudflare rate limit is 1200 requests over 300 seconds cumulativley. Lowest this value can safely be is 250ms
        Start-Sleep -Milliseconds 300

        if ($response -and $response.items) {
            $allItems += $response.items
        }

        if ($response.links -and $response.links.next) {
            $currentUri = $response.links.next
        } else {
            $currentUri = $null
        }
    }

    return $allItems
}

if (Test-Path -Path $OutFile) {
    Write-Host "Warning: The file '$OutFile' already exists and will be overwritten."
    $confirmation = Read-Host "Do you want to proceed? (y/n)"
    if ($confirmation -ne 'y') {
        Write-Host "Operation cancelled by the user."
        return
    }
}

# Request the maximum number of logs available from the API per query
$allLogs = Get-AllEnclaveLogs -InitialUri "https://api.enclave.io/org/$orgId/logs?page=0&per_page=200" -Headers $headers

$allLogs | Select-Object timeStamp, level, ipAddress, userName, message | Export-Csv -Path $outfile -NoTypeInformation

Write-Output "$($allLogs.Count) log entries successfully written to $outfile`n"