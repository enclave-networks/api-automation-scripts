using System.Diagnostics;
using System.Net;
using System.Text;

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

    private static int queryCounter = 0;
    private static List<string> allHostnames = [];
    
    static async Task Main(string[] args)
    {
        var (concurrency, interval, timeout) = ParseArguments(args);

        if (!LoadHostnames()) return;

        Console.CancelKeyPress += (sender, e) =>
        {
            e.Cancel = true;  // allow graceful shutdown
            cts.Cancel();     // trigger cancellation
        };

        var tcs = new TaskCompletionSource<bool>();

        cts.Token.Register(() => tcs.TrySetResult(true));

        try
        {
            // --interval=n
            var timer = new Timer(_ =>
            {
                var hostnames = TakeSlice(concurrency);

                // --concurrency=n
                for (int i = 0; i < concurrency; i++)
                {
                    var hostname = hostnames[i];

                    _ = Task.Run(async () =>
                    {
                        await ResolveHostnameAsync(hostname, timeout, cts.Token);
                    });
                }

                Console.WriteLine($"{concurrency} queries queued.");

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

    static bool LoadHostnames()
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

    static List<string> TakeSlice(int sliceSize)
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

    static async Task ResolveHostnameAsync(string hostname, int timeout, CancellationToken cancellationToken)
    {
        var success = false;
        
        var output = new StringBuilder();
        
        var queryDuration = Stopwatch.StartNew();
        
        var counter = Interlocked.Increment(ref queryCounter);

        // --timeout=n
        var timeoutTask = Task.Delay(TimeSpan.FromMilliseconds(timeout), cancellationToken);
        
        var resolverTask = Dns.GetHostAddressesAsync(hostname, cancellationToken);

        try
        {
            
            var completedTask = await Task.WhenAny(resolverTask, timeoutTask);

            if (completedTask == resolverTask)
            {
                var addresses = await resolverTask;
                var ipAddresses = addresses.Select(addr => addr.ToString());

                success = true;

                output.Append($"Elapsed: {stopwatch.Elapsed.TotalSeconds,12}s, QueryTime: {queryDuration.Elapsed.TotalMilliseconds,12}ms, Counter: #{counter,-6} {hostname,-64}: {string.Join(", ", ipAddresses)}");
            }
            else
            {
                output.Append($"Elapsed: {stopwatch.Elapsed.TotalSeconds,12}s, QueryTime: {queryDuration.Elapsed.TotalMilliseconds,12}ms, Counter: #{counter,-6} {hostname,-64}: Query timeout");
            }
        }
        catch (OperationCanceledException)
        {
            // expected, swallow
        }
        catch (Exception ex)
        {
            output.Append($"Elapsed: {stopwatch.Elapsed.TotalSeconds,12}s, QueryTime: {queryDuration.Elapsed.TotalMilliseconds,12}ms, Counter: #{counter,-6} {hostname,-64}: {ex.Message}");
        }
        finally
        {
            lock (_consoleLock)
            {
                Console.ForegroundColor = (success == true) ? ConsoleColor.DarkGreen : ConsoleColor.DarkRed;
                Console.WriteLine(output);
                Console.ForegroundColor = _originalColor;
            }
        }
    }
}
