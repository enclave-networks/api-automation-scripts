# Define the list of domains with their respective checks
$domains = @(
    @{
        Name = "uksouth.management.azure.com"
        Checks = @("tcp/443")
    },
    @{
        Name = "api.enclave.io"
        Checks = @("tcp/443")
    },
    @{
        Name = "install.enclave.io"
        Checks = @("tcp/443")
    },
    @{
        Name = "discover.enclave.io"
        Checks = @("tcp/443")
    },
    @{
        Name = "relays.enclave.io"
        Checks = @("tcp/443", "icmp")
    }
)

# Function to resolve DNS
function Resolve-Dns {
    param (
        [string]$Domain
    )
    $addresses = Resolve-DnsName -Name $Domain -ErrorAction SilentlyContinue
    $results = @()
    
    $addresses | ForEach-Object {
        $result = [PSCustomObject]@{
            Name = $Domain
            Address = $_.IPAddress
            Type = $_.QueryType
        }
        # If the result is a CNAME, resolve the CNAME target recursively
        if ($_.QueryType -eq 'CNAME') {
            $cnameTarget = $_.NameHost
            $ip = Resolve-Dns -Domain $cnameTarget
            $results += $ip
            
        } else {
            $results += $result
        }
    }

    # Deduplicate the results
    $uniqueResults = $results | Sort-Object Address, Type -Unique
    
    return $uniqueResults
}

# Function to format output
function Format-Output {
    param (
        [string]$protocol,
        [string]$address,
        [string]$status,
        [int]$totalLength = 50
    )
    $line = "$protocol/$address"
    $dots = "." * ($totalLength - $line.Length - 4) # Subtract 4 for the brackets and spaces
    return "    $line $dots [$status]"
}

# Main script logic
foreach ($domain in $domains) {
    Write-Host "$($domain.Name)"
    
    $resolvedAddresses = Resolve-Dns -Domain $domain.Name

    $jobs = @()

    foreach ($address in $resolvedAddresses) {
        foreach ($check in $domain.Checks) {
            if ($check -eq "icmp") {
                $jobs += @{
                    Job = Start-Job -ScriptBlock {
                        param ($addr)
                        function Test-IcmpPing {
                            param (
                                [string]$Address
                            )
                            try {
                                $pingResult = Test-Connection -ComputerName $Address -Count 1 -WarningAction SilentlyContinue
                                if ($pingResult.StatusCode -eq 0) {
                                    return "ok $($pingResult.ResponseTime)ms"
                                } else {
                                    return "failure $($pingResult.ResponseTime)ms (timeout waiting for a response)"
                                }
                            } catch {
                                return "failure ($($_.Exception.Message))"
                            }
                        }
                        $status = Test-IcmpPing -Address $addr
                        return @{ Protocol = "icmp"; Address = $addr; Status = $status }
                    } -ArgumentList $address.Address
                }
            } elseif ($check -match "tcp/(\d+)") {
                $port = [int]$matches[1]
                $jobs += @{
                    Job = Start-Job -ScriptBlock {
                        param ($addr, $prt)
                        function Test-TcpPort {
                            param (
                                [string]$ComputerName,
                                [int]$Port,
                                [int]$Timeout = 10000
                            )
                            try {
                                $address = [System.Net.IPAddress]::Parse($ComputerName)
                                $addressFamily = $address.AddressFamily
                                $tcpClient = New-Object System.Net.Sockets.TcpClient($addressFamily)
                                $asyncResult = $tcpClient.BeginConnect($address, $Port, $null, $null)
                                $waitHandle = $asyncResult.AsyncWaitHandle
                                if ($waitHandle.WaitOne($Timeout, $false)) {
                                    $tcpClient.EndConnect($asyncResult)
                                    $tcpClient.Close()
                                    return "ok"
                                } else {
                                    $tcpClient.Close()
                                    return "failure (no response)"
                                }
                            } catch [System.Net.Sockets.SocketException] {
                                return "failure $($stopwatch.ElapsedMilliseconds)ms ($($_.Exception.Message))"
                            } catch {
                                return "failure $($stopwatch.ElapsedMilliseconds)ms ($($_.Exception.Message))"
                            }
                        }
                        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                        $tcpResult = Test-TcpPort -ComputerName $addr -Port $prt
                        $stopwatch.Stop()
                        $status = if ($tcpResult -match "ok") { "ok $($stopwatch.ElapsedMilliseconds)ms" } else { $tcpResult }
                        return @{ Protocol = "tcp"; Address = "$addr`:$prt"; Status = $status }
                    } -ArgumentList $address.Address, $port
                }
            }
        }
    }

    # Collect job results
    foreach ($job in $jobs) {
        $result = Receive-Job -Job $job.Job -Wait -AutoRemoveJob
        $formattedResult = Format-Output -protocol $result.Protocol -address $result.Address -status $result.Status
        Write-Host $formattedResult
    }
}
