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
    // Parameters
    static string hostnamesFile = "../hosts.txt";
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

        while (true)
        {
            await TakeSlice(30);
        }
    }

    static bool LoadHostnames()
    {
        if (!File.Exists(hostnamesFile))
        {
            Console.WriteLine($"File not found: {hostnamesFile}");
            return false;
        }

        // Load hostnames, skipping comments and invalid lines
        allHostnames = File.ReadAllLines(hostnamesFile)
                           .Where(line => !line.StartsWith("#") && !string.IsNullOrWhiteSpace(line) && line.Contains(" "))
                           .Select(line => line.Split(' ')[1]) // Extract hostname
                           .Where(hostname => !string.IsNullOrWhiteSpace(hostname))
                           .ToList();

        return allHostnames.Count > 0;
    }

    static async Task TakeSlice(int sliceSize)
    {
        if (allHostnames.Count < sliceSize)
        {
            Console.WriteLine("Slice size exceeds total hostnames in file.");
            return;
        }

        // Randomly select a slice using Fisher-Yates algorithm
        var hostnamesToResolve = new List<string>();
        for (int i = 0; i < sliceSize; i++)
        {
            int randomIndex = random.Next(allHostnames.Count);
            hostnamesToResolve.Add(allHostnames[randomIndex]);
        }

        // Resolve hostnames in parallel using Parallel.ForEachAsync (available in .NET 6 and later)
        await Parallel.ForEachAsync(hostnamesToResolve, async (hostname, cancellationToken) =>
        {
            await ResolveHostnameAsync(hostname);
        });
    }

    // Async function to resolve DNS for a single hostname
    static async Task ResolveHostnameAsync(string hostname)
    {
        try
        {
            var addresses = await Dns.GetHostAddressesAsync(hostname);
            var ipAddresses = addresses.Where(addr => addr.AddressFamily == AddressFamily.InterNetwork).Select(addr => addr.ToString());

            lock (_consoleLock)
            {
                Console.ForegroundColor = ConsoleColor.DarkGreen;
                Console.WriteLine($"#{counter} {stopwatch.Elapsed.TotalSeconds}s -- {hostname}: {string.Join(", ", ipAddresses)}");
            }
        }
        catch (Exception ex)
        {
            lock (_consoleLock)
            {
                Console.ForegroundColor = ConsoleColor.DarkRed;
                Console.WriteLine($"#{counter} {stopwatch.Elapsed.TotalSeconds}s -- {hostname}: {ex.Message}");
            }
        }
        finally
        {
            Interlocked.Increment(ref counter);
        }

        Console.ForegroundColor = ConsoleColor.Black;
    }
}
