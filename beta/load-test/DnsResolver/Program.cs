using System.Diagnostics;
using System.Net;

class DnsResolverProgram
{
    //private static string hostnamesFile = "../hosts.txt";
    private static readonly string hostnamesFile = "../tranco-list-top-1m.csv";
    private static readonly int maxLines = 20_000;
    private static readonly object _consoleLock = new();
    private static readonly Stopwatch stopwatch = Stopwatch.StartNew();
    private static readonly Random random = new();
    private static readonly ConsoleColor _originalColor = Console.ForegroundColor;
    private static readonly CancellationTokenSource cts = new();

    private static Timer? _dnsReportTimer;
    private static List<string> allHostnames = [];

    private static long _dnsQueriesScheduled;   // waiting for threadpool
    private static long _dnsQueriesExecuted;    // running in threadpool
    private static long _dnsQueriesInFlight;

    private static long _querySuccessCount;
    private static long _queryTimeoutCount;
    private static long _queryNoAnswerCount;
    private static long _queryExceptionCount;

    private static long _queryMaxDuration;
    private static long _queryMinDuration;
    private static long _querySumOfDurations;
    private static long _queryCountOfDurations;

    private static async Task Main(string[] args)
    {
        var (concurrency, interval, timeout) = ParseArguments(args);

        if (!LoadHostnames()) return;

        Console.CancelKeyPress += (sender, e) =>
        {
            e.Cancel = true;  // allow graceful shutdown
            cts.Cancel();     // trigger cancellation
        };

        ThreadPool.GetMaxThreads(out int workerThreads, out int completionPortThreads);
        ThreadPool.SetMaxThreads(workerThreads, completionPortThreads);

        var tcs = new TaskCompletionSource<bool>();

        cts.Token.Register(() => tcs.TrySetResult(true));

        // setup reporting timer
        _dnsReportTimer = new Timer(DnsQueryVolumeReport, null, 0, 1000);

        try
        {
            // --interval=n
            var timer = new Timer(_ =>
            {
                var hostnames = TakeSlice(concurrency);

                // --concurrency=n
                for (int i = 0; i < concurrency; i++)
                {
                    Interlocked.Increment(ref _dnsQueriesScheduled);

                    var hostname = hostnames[i];

                    _ = Task.Run(async () =>
                    {
                        await ResolveHostnameAsync(hostname, timeout, cts.Token);
                    }, cts.Token);
                }
            }, null, 0, interval);

            await tcs.Task;

            timer.Dispose();
        }
        catch (OperationCanceledException)
        {
            Console.WriteLine("Operation was canceled.");
        }
        finally
        {
            Console.WriteLine("Shutdown complete.");
        }
    }

    private static (int queryConcurrency, int queryInterval, int timeout) ParseArguments(string[] args)
    {
        int queryConcurrency = 1;
        int queryInterval = 1000; // milliseconds
        int queryTimeout = 3000; // milliseconds

        foreach (string arg in args)
        {
            if (arg.StartsWith("--concurrency="))
            {
                if (int.TryParse(arg.Substring("--concurrency=".Length), out int value))
                {
                    queryConcurrency = value;
                }
                else
                {
                    Console.WriteLine("Invalid value for Concurrency. Must be an integer. Using default value 1.");
                }
            }
            else if (arg.StartsWith("--interval="))
            {
                if (int.TryParse(arg.Substring("--interval=".Length), out int value))
                {
                    queryInterval = value;
                }
                else
                {
                    Console.WriteLine("Invalid value for Interval. Must be an integer. Using default value 1000 ms.");
                }
            }
            else if (arg.StartsWith("--timeout="))
            {
                if (int.TryParse(arg.Substring("--timeout=".Length), out int value))
                {
                    queryTimeout = value;
                }
                else
                {
                    Console.WriteLine("Invalid value for Timeout. Must be an integer. Using default value 3000 ms.");
                }
            }
        }

        return (queryConcurrency, queryInterval, queryTimeout);
    }

    private static bool LoadHostnames()
    {
        if (!File.Exists(hostnamesFile))
        {
            Console.WriteLine($"File not found: {hostnamesFile}");
            return false;
        }

        allHostnames = File.ReadLines(hostnamesFile) // Use ReadLines instead of ReadAllLines for lazy loading
                   .Take(maxLines)
                   .Where(line => !line.StartsWith("#") && !string.IsNullOrWhiteSpace(line)) // Skip comments and empty lines
                   .Select(line =>
                   {
                       // Split line by whitespace or comma and extract the last element (assuming it's the hostname)
                       var parts = line.Split(new[] { ' ', ',' }, StringSplitOptions.RemoveEmptyEntries);
                       return parts.Length > 0 ? parts[^1] : null; // Extract the last part as hostname
                   })
                   .Where(hostname => !string.IsNullOrWhiteSpace(hostname)) // Filter out any nulls or empty hostnames
                   .Cast<string>() // Cast to ensure all are non-null strings, matching the target type
                   .ToList();

        return allHostnames.Count > 0;
    }

    private static List<string> TakeSlice(int sliceSize)
    {
        if (allHostnames.Count < sliceSize)
        {
            Console.WriteLine("Slice size exceeds total hostnames in file.");
            
            return [];
        }

        var hostnamesToResolve = allHostnames
            .OrderBy(_ => random.Next()) // Shuffle the list randomly
            .Take(sliceSize)
            .ToList();

        return hostnamesToResolve;
    }

    private static async Task ResolveHostnameAsync(string hostname, int timeout, CancellationToken cancellationToken)
    {
        var queryDuration = Stopwatch.StartNew();
        
        try
        {
            Interlocked.Increment(ref _dnsQueriesExecuted);
            Interlocked.Increment(ref _dnsQueriesInFlight);

            // --timeout=n
            var timeoutTask = Task.Delay(TimeSpan.FromMilliseconds(timeout), cancellationToken);

            var resolverTask = Dns.GetHostAddressesAsync(hostname, cancellationToken);

            var completedTask = await Task.WhenAny(resolverTask, timeoutTask);

            if (completedTask == resolverTask)
            {
                await resolverTask;

                var addresses = await resolverTask;
                var ipAddresses = addresses.Select(addr => addr.ToString());

                Interlocked.Increment(ref _querySuccessCount);
            }
            else
            {
                Interlocked.Increment(ref _queryNoAnswerCount);
            }
        }
        catch (OperationCanceledException)
        {
            // expected, swallow
        }
        catch (Exception)
        {
            Interlocked.Increment(ref _queryExceptionCount);
        }
        finally
        {
            Interlocked.Decrement(ref _dnsQueriesInFlight);

            var duration = (uint)stopwatch.ElapsedMilliseconds;
            var currentMax = Interlocked.Read(ref _queryMaxDuration);
            var currentMin = Interlocked.Read(ref _queryMinDuration);

            Interlocked.Increment(ref _queryCountOfDurations);

            Interlocked.Add(ref _querySumOfDurations, duration);

            if (duration > currentMax)
            {
                Interlocked.Exchange(ref _queryMaxDuration, duration);
            }

            if (duration < currentMin)
            {
                Interlocked.Exchange(ref _queryMinDuration, duration);
            }
        }
    }

    private static void DnsQueryVolumeReport(object? state)
    {
        var queriesScheduled = Interlocked.Read(ref _dnsQueriesScheduled);
        var queriesExecuted = Interlocked.Read(ref _dnsQueriesExecuted);
        var queriesInFlight = Interlocked.Read(ref _dnsQueriesInFlight);

        Interlocked.Exchange(ref _dnsQueriesExecuted, 0); // reset the count after every second

        var querySuccessCount = Interlocked.Read(ref _querySuccessCount);
        var queryTimeoutCount = Interlocked.Read(ref _queryTimeoutCount);
        var queryNoAnswerCount = Interlocked.Read(ref _queryNoAnswerCount);
        var queryExceptionCount = Interlocked.Read(ref _queryExceptionCount);

        Interlocked.Exchange(ref _querySuccessCount, 0);
        Interlocked.Exchange(ref _queryTimeoutCount, 0);
        Interlocked.Exchange(ref _queryNoAnswerCount, 0);
        Interlocked.Exchange(ref _queryExceptionCount, 0);

        var queryMinDuration = Interlocked.Read(ref _queryMinDuration);
        var queryMaxDuration = Interlocked.Read(ref _queryMaxDuration);
        var querySumOfDurations = Interlocked.Read(ref _querySumOfDurations);
        var queryCountOfDurations = Interlocked.Read(ref _queryCountOfDurations);

        Interlocked.Exchange(ref _queryMinDuration, long.MaxValue);
        Interlocked.Exchange(ref _queryMaxDuration, 0);
        Interlocked.Exchange(ref _querySumOfDurations, 0);
        Interlocked.Exchange(ref _queryCountOfDurations, 0);

        var failed = queryNoAnswerCount + queryTimeoutCount + queryExceptionCount;
        var total = querySuccessCount + failed;
        var successPercentage = total > 0 ? (double)querySuccessCount / total * 100 : 0;

        var averageDuration = queriesScheduled > 0 ? (double)querySumOfDurations / queriesScheduled : 0;

        // clamp min duration to 0 if all in-flights queries are yet to complete (so no minimum duration is known)
        queryMinDuration = queryMinDuration == long.MaxValue ? 0 : queryMinDuration;

        if (total > 0)
        {
            Console.WriteLine(
                "DNS queries queued: {0,-6} Queries scheduled per second: {1,-6} In-flight: {2,-6} Avg duration: {3,-4} ms, Success: {4,-4} ({5,3}%) Failed: {6,-4}",
                queriesScheduled,
                queriesExecuted,
                queriesInFlight,
                Math.Round(averageDuration, 0),
                querySuccessCount,
                Math.Round(successPercentage, 0),
                failed);
        }
    }
}
