using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using System.Threading.Tasks;

class DnsResolverProgram
{
    //static string hostnamesFile = "../hosts.txt";
    static string hostnamesFile = "../tranco-list-top-1m.csv";
    static int maxLines = 20_000;
    static int counter = 0;
    static object _consoleLock = new object();
    static Stopwatch stopwatch = Stopwatch.StartNew();
    static List<string> allHostnames = new List<string>();
    static Random random = new Random();

    static async Task Main(string[] args)
    {
        // Load the hostnames only once to reduce redundant I/O
        if (!LoadHostnames())
        {
            return;
        }

        // Create a CancellationTokenSource to manage graceful shutdown
        using CancellationTokenSource cts = new CancellationTokenSource();
        Console.CancelKeyPress += (sender, e) =>
        {
            e.Cancel = true; // Prevent the process from terminating immediately.
            cts.Cancel();     // Trigger cancellation to start graceful shutdown.
            Console.WriteLine("Cancellation requested... shutting down gracefully.");
        };

        try
        {
            // Pass the cancellation token to the loop for graceful shutdown
            while (!cts.Token.IsCancellationRequested)
            {
                await TakeSlice(30, cts.Token);
            }
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

    static async Task TakeSlice(int sliceSize, CancellationToken cancellationToken)
    {
        if (allHostnames.Count < sliceSize)
        {
            Console.WriteLine("Slice size exceeds total hostnames in file.");
            return;
        }

        var hostnamesToResolve = allHostnames
            .OrderBy(_ => random.Next()) // Shuffle the list randomly
            .Take(sliceSize) // Take the desired number of elements
            .ToList();

        // Resolve in parallel, respecting the cancellation token
        await Parallel.ForEachAsync(hostnamesToResolve, cancellationToken, async (hostname, token) =>
        {
            await ResolveHostnameAsync(hostname, token);
        });
    }

    static async Task ResolveHostnameAsync(string hostname, CancellationToken cancellationToken)
    {
        try
        {
            var addresses = await Dns.GetHostAddressesAsync(hostname);
            var ipAddresses = addresses.Where(addr => addr.AddressFamily == AddressFamily.InterNetwork).Select(addr => addr.ToString());

            lock (_consoleLock)
            {
                Console.ForegroundColor = ConsoleColor.DarkGreen;
                Console.WriteLine($"{stopwatch.Elapsed.TotalSeconds,12}s #{counter,-6} {hostname,-64}: {string.Join(", ", ipAddresses)}");
            }
        }
        catch (Exception ex) when (!(ex is OperationCanceledException))
        {
            lock (_consoleLock)
            {
                Console.ForegroundColor = ConsoleColor.DarkRed;
                Console.WriteLine($"{stopwatch.Elapsed.TotalSeconds,12}s #{counter,-6} {hostname,-64}: {ex.Message}");
            }
        }
        finally
        {
            Interlocked.Increment(ref counter);
        }

        Console.ForegroundColor = ConsoleColor.Black;
    }
}
