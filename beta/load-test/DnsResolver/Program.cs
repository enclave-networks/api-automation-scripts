using DnsResolver;
using System.Diagnostics;
using System.Net;
using System.Net.Sockets;

class DnsResolverProgram
{
    public static readonly List<string> sourceListFileNames = ["hosts", "tranco-list-top-1m" ];
    public static readonly List<string> sourceListExtension = ["txt", "csv"];

    /// <summary>
    /// Maximum number of entries we'll read from a file to control memory usage. 
    /// We want enough to reduce the likelyhood of querying the same fqdn twice,
    /// but not so many that we run out of memory.
    /// </summary>
    private static readonly int maxLines = 20_000;

    private static readonly Random random = new();
    
    private static readonly ConsoleColor _originalColor = Console.ForegroundColor;
    
    private static readonly CancellationTokenSource cts = new();

    private static Timer? _dnsReportTimer;
    
    private static List<string> allHostnames = [];

    private static long _totalDnsQueriesScheduled;       // waiting for threadpool
    private static long _dnsQueriesScheduledPerInterval; // launched on threadpool
    private static long _dnsQueriesCompletedPerInterval; // completed on threadpool
    private static long _dnsQueriesInFlight;

    private static long _querySuccessCount;
    private static long _queryTimeoutCount;
    private static long _queryNoAnswerCount;
    private static long _queryExceptionCount;

    private static long _queryMaxDuration;
    private static long _queryMinDuration;
    private static long _querySumOfDurations;

    private static volatile bool isPaused = false;
    private static volatile bool isVerbose = false;

    private static readonly object _stateLock = new object();

    private static async Task Main(string[] args)
    {
        var options = ParseArguments(args);

        isVerbose = options.IsVerbose;

        if (!LoadDnsNameSourceList(options.SourceListFile)) return;

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
        _dnsReportTimer = new Timer(DnsQueryVolumeReport, null, 0, options.QueryInterval);

        try
        {
            // Calculate queries per interval based on concurrency and interval.
            // Each thread produces one query per interval.
            double queriesPerSecond = options.QueryConcurrency * (1000.0 / options.QueryInterval);

            Console.WriteLine($"Press 'P' to toggle scheduling (currently ON). Press 'V' to toggle verbose output. Ctrl+C to stop");
            Console.WriteLine();
            Console.WriteLine($"  Query rate . . . . : {queriesPerSecond:N0} {(queriesPerSecond == 1 ? "query" : "queries")}/second");
            Console.WriteLine($"  Query timeout. . . : {options.QueryTimeout:N0} ms");
            Console.WriteLine($"  Test duration. . . : {(options.Duration > 0 ? $"{options.Duration:N0} ms" : "Until stopped")}");
            Console.WriteLine();

            // Start a background thread to monitor for key presses.
            new Thread(() => {
                while (!cts.IsCancellationRequested)
                {
                    var key = Console.ReadKey(true);

                    if (key.Key == ConsoleKey.P)  // 'P' for Produce toggle.
                    {
                        lock (_stateLock)
                        {
                            isPaused = !isPaused;

                            Console.WriteLine($"[{DateTime.Now:HH:mm:ss.fff}] Query scheduling {(isPaused ? "PAUSED" : "ENABLED")}");
                        }
                    }
                    if (key.Key == ConsoleKey.V)  // 'V' for Verbose toggle.
                    {
                        lock (_stateLock)
                        {
                            isVerbose = !isVerbose;

                            Console.WriteLine($"[{DateTime.Now:HH:mm:ss.fff}] Verbose output {(isVerbose ? "ENABLED" : "DISABLED")}");
                        }
                    }
                }
            }) { IsBackground = true }.Start();

            if (options.Duration > 0)
            {
                cts.CancelAfter(options.Duration);
            }

            // --interval=n
            var timer = new Timer(_ =>
            {
                if (isPaused) return;

                var hostnames = TakeSlice(options.QueryConcurrency);

                // --concurrency=n
                for (int i = 0; i < options.QueryConcurrency; i++)
                {
                    Interlocked.Increment(ref _totalDnsQueriesScheduled);

                    var hostname = hostnames[i];

                    _ = Task.Run(async () =>
                    {
                        await ResolveHostnameAsync(hostname, options.QueryTimeout, cts.Token);
                    }, cts.Token);
                }
            }, null, 0, options.QueryInterval);

            await tcs.Task;

            timer.Dispose();

            _dnsReportTimer.Dispose();
        }
        catch (OperationCanceledException)
        {
            Console.WriteLine("Operation was canceled.");
        }
        finally
        {
            Console.WriteLine("Finished.");
        }
    }

    private static CommandLineOptions ParseArguments(string[] args)
    {
        int duration = -1; 
        int queryConcurrency = 1; // Default values
        int queryInterval = 1000; // Milliseconds
        int queryTimeout = 3000; // Milliseconds
        FileInfo? sourceListFile = null;
        bool isVerbose = false;

        var argParsers = new Dictionary<string, Action<string>>
        {
            ["--duration="] = value => {
                if (!int.TryParse(value, out int result))
                    Console.WriteLine($"Invalid value for duration: {value}. Using default: {duration}");
                else
                    duration = result;
            },

            ["--concurrency="] = value => {
                if (!int.TryParse(value, out int result))
                    Console.WriteLine($"Invalid value for concurrency: {value}. Using default: {queryConcurrency}");
                else
                    queryConcurrency = result;
            },

            ["--interval="] = value => {
                if (!int.TryParse(value, out int result))
                    Console.WriteLine($"Invalid value for interval: {value}. Using default: {queryInterval} ms");
                else
                    queryInterval = result;
            },

            ["--timeout="] = value => {
                if (!int.TryParse(value, out int result))
                    Console.WriteLine($"Invalid value for timeout: {value}. Using default: {queryTimeout} ms");
                else
                    queryTimeout = result;
            },

            ["--list="] = value => {
                if (string.IsNullOrWhiteSpace(value))
                {
                    Console.WriteLine("A valid file path must be provided after the '--list=' parameter.");
                    return;
                }

                if (!File.Exists(value))
                {
                    Console.WriteLine($"Specified --list file path does not exist: '{value}'. Exiting.");
                    Environment.Exit(1);
                    return;
                }

                // Use null-forgiving operator since we've already checked for null/empty
                sourceListFile = new FileInfo(value!);
            }
        };

        foreach (string arg in args)
        {
            if (arg == "--verbose")
            {
                isVerbose = true;
                continue;
            }

            bool handled = false;
            foreach (var parser in argParsers)
            {
                if (arg.StartsWith(parser.Key))
                {
                    string value = arg[parser.Key.Length..];
                    parser.Value(value);
                    handled = true;
                    break;
                }
            }

            if (!handled && !arg.StartsWith("--help"))
            {
                Console.WriteLine($"Unrecognized argument: {arg}");
            }
        }

        return new CommandLineOptions(
            duration,
            queryConcurrency,
            queryInterval,
            queryTimeout,
            sourceListFile,
            isVerbose
        );
    }

    private static bool LoadDnsNameSourceList(FileInfo? sourceList)
    {
        // No source list provided, search for known source list files in the current directory
        if (sourceList == null)
        {
            FileInfo? foundFile = sourceListFileNames
                .SelectMany(file => sourceListExtension.Select(ext =>
                    new FileInfo(Path.Combine(Directory.GetCurrentDirectory(), $"{file}.{ext}"))))
                .FirstOrDefault(fi => fi.Exists);

            // Only assign if a file was actually found
            if (foundFile != null)
            {
                sourceList = foundFile;
            }
        }

        if (sourceList == null)
        {
            Console.WriteLine("Source list of hostnames not found. Provide a list of hostnames using --list=filename.txt");
            return false;
        }
        else
        {
            Console.WriteLine($"Using DNS source list: {sourceList.FullName} (limit: {maxLines:N0} lines)");
        }

        allHostnames = File.ReadLines(sourceList.FullName) // Use ReadLines instead of ReadAllLines for lazy loading
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

        Console.WriteLine($"Loaded {allHostnames.Count:N0} hostnames");

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

        var errorMessage = string.Empty;

        IEnumerable<string> answer = [];

        try
        {
            Interlocked.Increment(ref _dnsQueriesScheduledPerInterval);
            Interlocked.Increment(ref _dnsQueriesInFlight);

            // --timeout=n
            var timeoutTask = Task.Delay(TimeSpan.FromMilliseconds(timeout), cancellationToken);

            var resolverTask = Dns.GetHostAddressesAsync(hostname, cancellationToken);

            var completedTask = await Task.WhenAny(resolverTask, timeoutTask);

            if (completedTask == resolverTask)
            {
                await resolverTask;

                var addresses = await resolverTask;

                answer = addresses.Select(addr => addr.ToString());

                Interlocked.Increment(ref _querySuccessCount);
            }
            else
            {
                Interlocked.Increment(ref _queryTimeoutCount);

                errorMessage = $"Timeout Elapsed ({timeout} ms)";
            }
        }
        catch (SocketException)
        {
            // expected, swallow
            Interlocked.Increment(ref _queryNoAnswerCount);
        }
        catch (OperationCanceledException)
        {
            // expected when SIGTERM arrives, swallow
            Interlocked.Increment(ref _queryExceptionCount);

            errorMessage = "OperationCanceled";
        }
        catch (Exception ex)
        {
            Interlocked.Increment(ref _queryExceptionCount);

            errorMessage = ex.Message;
        }
        finally
        {
            queryDuration.Stop();

            var duration = (uint)queryDuration.ElapsedMilliseconds;
            var currentMax = Interlocked.Read(ref _queryMaxDuration);
            var currentMin = Interlocked.Read(ref _queryMinDuration);

            Interlocked.Decrement(ref _dnsQueriesInFlight);

            Interlocked.Increment(ref _dnsQueriesCompletedPerInterval);

            Interlocked.Add(ref _querySumOfDurations, duration);

            if (duration > currentMax)
            {
                Interlocked.Exchange(ref _queryMaxDuration, duration);
            }

            if (duration < currentMin)
            {
                Interlocked.Exchange(ref _queryMinDuration, duration);
            }

            if (isVerbose)
            {
                if (string.IsNullOrEmpty(errorMessage) == false)
                {
                    Console.WriteLine($"[{DateTime.Now:HH:mm:ss.fff}]    {hostname,-64} {duration,8:N0} ms {errorMessage}");
                }
                else
                {
                    Console.WriteLine($"[{DateTime.Now:HH:mm:ss.fff}]    {hostname,-64} {duration,8:N0} ms [{string.Join(", ", answer.Select(item => item.Trim()))}]");
                }
            }
        }
    }

    private static void DnsQueryVolumeReport(object? state)
    {
        var totalQueriesScheduled = Interlocked.Read(ref _totalDnsQueriesScheduled);

        var queriesScheduledPerInterval = Interlocked.Read(ref _dnsQueriesScheduledPerInterval);
        var queriesCompletedPerInterval = Interlocked.Read(ref _dnsQueriesCompletedPerInterval);

        var queriesInFlight = Interlocked.Read(ref _dnsQueriesInFlight);

        Interlocked.Exchange(ref _dnsQueriesScheduledPerInterval, 0); // reset the count after every interval
        Interlocked.Exchange(ref _dnsQueriesCompletedPerInterval, 0); // reset the count after every interval

        var querySuccessCount = Interlocked.Read(ref _querySuccessCount);
        var queryTimeoutCount = Interlocked.Read(ref _queryTimeoutCount);
        var queryNoAnswerCount = Interlocked.Read(ref _queryNoAnswerCount);
        var queryExceptionCount = Interlocked.Read(ref _queryExceptionCount);
        var queryFailedCount = queryTimeoutCount + queryNoAnswerCount + queryExceptionCount;

        Interlocked.Exchange(ref _querySuccessCount, 0);
        Interlocked.Exchange(ref _queryTimeoutCount, 0);
        Interlocked.Exchange(ref _queryNoAnswerCount, 0);
        Interlocked.Exchange(ref _queryExceptionCount, 0);

        var queryMinDuration = Interlocked.Read(ref _queryMinDuration);
        var queryMaxDuration = Interlocked.Read(ref _queryMaxDuration);
        var querySumOfDurations = Interlocked.Read(ref _querySumOfDurations);

        Interlocked.Exchange(ref _queryMinDuration, long.MaxValue);
        Interlocked.Exchange(ref _queryMaxDuration, 0);
        Interlocked.Exchange(ref _querySumOfDurations, 0);

        //var scheduled = querySuccessCount + queryFailedCount;
        var successPercentage = queriesCompletedPerInterval > 0 ? (double)querySuccessCount / queriesCompletedPerInterval * 100 : 0;

        var averageDuration = queriesCompletedPerInterval > 0 ? (double)querySumOfDurations / queriesCompletedPerInterval : 0;
        var durationMs = $"{Math.Round(averageDuration):N0} ms";

        // clamp min duration to 0 if all in-flights queries are yet to complete (so no minimum duration is known)
        queryMinDuration = queryMinDuration == long.MaxValue ? 0 : queryMinDuration;

        if (queriesCompletedPerInterval > 0)
        {
            Console.WriteLine(
                $"[{DateTime.Now:HH:mm:ss.fff}] " +
                $"Total: {totalQueriesScheduled,6:N0}, " +
                $"scheduled: {queriesScheduledPerInterval:N0}, " +
                $"in-flight: {queriesInFlight,-4:N0} " +
                $"avg: {durationMs,8}, " +
                $"success: {querySuccessCount,3:N0} ({Math.Round(successPercentage,0),3}%), " +
                $"failed: {queryFailedCount,-4:N0} " +
                $"(no-answer: {queryNoAnswerCount:N0}, timeout: {queryTimeoutCount:N0}, exception: {queryExceptionCount:N0})"
            );
        }
    }
}

