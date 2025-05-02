namespace DnsResolver
{
    public record CommandLineOptions(
        int Duration,
        int QueryConcurrency,
        int QueryInterval,
        int QueryTimeout,
        FileInfo? SourceListFile,
        bool IsVerbose
    );
}
