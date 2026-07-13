// ClipboardAdv.cs
using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Forms;

class Entry
{
    public long Id { get; set; }
    public string Text { get; set; }
    public string Timestamp { get; set; }
    public string Category { get; set; }
    public bool Pinned { get; set; }
    public string SourceApp { get; set; }
    public int UsageCount { get; set; }
}

class ClipboardAdv
{
    private static List<Entry> history = new List<Entry>();
    private const int MaxHistory = 200;
    private const string DefaultCategory = "other";
    private const string HistoryFile = "clipboard_adv_history.json";
    private static string lastClipboard = "";
    private static bool running = true;

    static void Main()
    {
        LoadHistory();
        lastClipboard = Clipboard.GetText();

        // Monitor thread
        Thread monitor = new Thread(MonitorClipboard);
        monitor.IsBackground = true;
        monitor.Start();

        Console.WriteLine("=== Advanced Clipboard Manager ===");
        Console.WriteLine("Monitoring clipboard...");
        Console.WriteLine("Commands: 1=history, 2=add, 3=search, 4=paste, 5=delete, 6=pin, 7=category, 8=stats, 9=cleanup, 10=export, 11=import, 12=exit");

        while (running)
        {
            Console.Write("\n> ");
            string cmd = Console.ReadLine()?.Trim();
            switch (cmd)
            {
                case "1": ShowHistory(); break;
                case "2":
                    string text = Clipboard.GetText();
                    AddEntry(text);
                    Console.WriteLine($"Added: {Truncate(text, 50)}");
                    break;
                case "3":
                    Console.Write("Search query (regex supported: /pattern/i): ");
                    string query = Console.ReadLine();
                    if (!string.IsNullOrEmpty(query)) SearchHistory(query);
                    break;
                case "4":
                    Console.Write("Enter index: ");
                    if (int.TryParse(Console.ReadLine(), out int idx)) PasteEntry(idx);
                    break;
                case "5":
                    Console.Write("Enter index: ");
                    if (int.TryParse(Console.ReadLine(), out int delIdx)) DeleteEntry(delIdx);
                    break;
                case "6":
                    Console.Write("Enter index: ");
                    if (int.TryParse(Console.ReadLine(), out int pinIdx)) TogglePin(pinIdx);
                    break;
                case "7":
                    Console.Write("Enter index: ");
                    if (int.TryParse(Console.ReadLine(), out int catIdx))
                    {
                        Console.Write("Enter category (code/link/note/quote/other): ");
                        string cat = Console.ReadLine();
                        if (string.IsNullOrEmpty(cat)) cat = DefaultCategory;
                        SetCategory(catIdx, cat);
                    }
                    break;
                case "8": ShowStats(); break;
                case "9":
                    Console.Write("Remove entries older than N days: ");
                    if (int.TryParse(Console.ReadLine(), out int days)) Cleanup(days);
                    break;
                case "10":
                    Console.Write("Export format (json/csv): ");
                    string fmt = Console.ReadLine()?.ToLower();
                    Console.Write("Filename (default: export." + fmt + "): ");
                    string fname = Console.ReadLine();
                    if (string.IsNullOrEmpty(fname)) fname = "export." + fmt;
                    if (fmt == "json") ExportJSON(fname);
                    else if (fmt == "csv") ExportCSV(fname);
                    else Console.WriteLine("Unknown format.");
                    break;
                case "11":
                    Console.Write("Import format (json/csv): ");
                    fmt = Console.ReadLine()?.ToLower();
                    Console.Write("Filename: ");
                    fname = Console.ReadLine();
                    if (string.IsNullOrEmpty(fname)) { Console.WriteLine("Filename required."); break; }
                    if (fmt == "json") ImportJSON(fname);
                    else if (fmt == "csv") ImportCSV(fname);
                    else Console.WriteLine("Unknown format.");
                    break;
                case "12":
                    Console.WriteLine("Goodbye!");
                    running = false;
                    return;
                default:
                    Console.WriteLine("Invalid command.");
                    break;
            }
        }
    }

    static void LoadHistory()
    {
        try
        {
            string json = File.ReadAllText(HistoryFile);
            history = JsonSerializer.Deserialize<List<Entry>>(json) ?? new List<Entry>();
        }
        catch { history = new List<Entry>(); }
    }

    static void SaveHistory()
    {
        string json = JsonSerializer.Serialize(history, new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(HistoryFile, json);
    }

    static void AddEntry(string text)
    {
        if (string.IsNullOrEmpty(text)) return;
        if (history.Count > 0 && history[0].Text == text) return;
        var entry = new Entry
        {
            Id = DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
            Text = text,
            Timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"),
            Category = DefaultCategory,
            Pinned = false,
            SourceApp = "unknown",
            UsageCount = 0
        };
        history.Insert(0, entry);
        if (history.Count > MaxHistory)
        {
            for (int i = history.Count - 1; i >= 0; i--)
            {
                if (!history[i].Pinned)
                {
                    history.RemoveAt(i);
                    break;
                }
            }
            if (history.Count > MaxHistory) history.RemoveAt(history.Count - 1);
        }
        SaveHistory();
    }

    static void MonitorClipboard()
    {
        while (running)
        {
            try
            {
                string current = Clipboard.GetText();
                if (!string.IsNullOrEmpty(current) && current != lastClipboard)
                {
                    lastClipboard = current;
                    AddEntry(current);
                }
            }
            catch { }
            Thread.Sleep(500);
        }
    }

    static string Truncate(string s, int n) => s.Length > n ? s.Substring(0, n) + "..." : s;

    static void ShowHistory()
    {
        if (history.Count == 0) { Console.WriteLine("History is empty."); return; }
        for (int i = 0; i < history.Count; i++)
        {
            var e = history[i];
            string pin = e.Pinned ? "★ " : "";
            Console.WriteLine($"[{i+1}] {pin}{e.Category}: {Truncate(e.Text, 50)}  ({e.Timestamp})  [used: {e.UsageCount}]");
        }
    }

    static void SearchHistory(string query)
    {
        bool isRegex = false, caseSensitive = true;
        string pattern = query;
        if (query.StartsWith("/") && (query.EndsWith("/") || query.EndsWith("/i")))
        {
            isRegex = true;
            if (query.EndsWith("/i"))
            {
                pattern = query.Substring(1, query.Length - 3);
                caseSensitive = false;
            }
            else
            {
                pattern = query.Substring(1, query.Length - 2);
                caseSensitive = true;
            }
        }
        List<Entry> results = new List<Entry>();
        foreach (var e in history)
        {
            if (isRegex)
            {
                try
                {
                    var options = caseSensitive ? RegexOptions.None : RegexOptions.IgnoreCase;
                    if (Regex.IsMatch(e.Text, pattern, options)) results.Add(e);
                }
                catch { Console.WriteLine("Invalid regex."); return; }
            }
            else
            {
                if (e.Text.ToLower().Contains(query.ToLower())) results.Add(e);
            }
        }
        if (results.Count == 0) { Console.WriteLine("No matches found."); return; }
        for (int i = 0; i < results.Count; i++)
        {
            var e = results[i];
            string pin = e.Pinned ? "★ " : "";
            Console.WriteLine($"[{i+1}] {pin}{e.Category}: {Truncate(e.Text, 50)}  ({e.Timestamp})  [used: {e.UsageCount}]");
        }
    }

    static void PasteEntry(int index)
    {
        if (index < 1 || index > history.Count) { Console.WriteLine("Invalid index."); return; }
        var e = history[index-1];
        Clipboard.SetText(e.Text);
        e.UsageCount++;
        SaveHistory();
        Console.WriteLine($"Copied to clipboard: {Truncate(e.Text, 50)}");
    }

    static void DeleteEntry(int index)
    {
        if (index < 1 || index > history.Count) { Console.WriteLine("Invalid index."); return; }
        var removed = history[index-1];
        history.RemoveAt(index-1);
        SaveHistory();
        Console.WriteLine($"Deleted: {Truncate(removed.Text, 50)}");
    }

    static void TogglePin(int index)
    {
        if (index < 1 || index > history.Count) { Console.WriteLine("Invalid index."); return; }
        var e = history[index-1];
        e.Pinned = !e.Pinned;
        SaveHistory();
        Console.WriteLine($"Entry { (e.Pinned ? "pinned" : "unpinned") }: {Truncate(e.Text, 50)}");
    }

    static void SetCategory(int index, string category)
    {
        if (index < 1 || index > history.Count) { Console.WriteLine("Invalid index."); return; }
        var e = history[index-1];
        e.Category = category;
        SaveHistory();
        Console.WriteLine($"Category updated: {Truncate(e.Text, 50)} -> {category}");
    }

    static void ShowStats()
    {
        int total = history.Count;
        if (total == 0) { Console.WriteLine("No entries."); return; }
        var categories = new Dictionary<string, int>();
        int pinnedCount = 0, totalUsage = 0, mostUsed = 0;
        var now = DateTime.Now;
        List<double> ages = new List<double>();
        foreach (var e in history)
        {
            categories[e.Category] = categories.ContainsKey(e.Category) ? categories[e.Category] + 1 : 1;
            if (e.Pinned) pinnedCount++;
            totalUsage += e.UsageCount;
            if (e.UsageCount > mostUsed) mostUsed = e.UsageCount;
            if (DateTime.TryParse(e.Timestamp, out DateTime ts))
                ages.Add((now - ts).TotalDays);
        }
        double avgAge = ages.Count > 0 ? ages.Average() : 0;
        Console.WriteLine("Statistics:");
        Console.WriteLine($"  Total entries: {total}");
        Console.WriteLine($"  Pinned: {pinnedCount}");
        Console.WriteLine($"  Categories: {string.Join(", ", categories.Select(kv => $"{kv.Key}:{kv.Value}"))}");
        Console.WriteLine($"  Most used count: {mostUsed}");
        Console.WriteLine($"  Total usage: {totalUsage}");
        Console.WriteLine($"  Average age: {avgAge:F1} days");
    }

    static void Cleanup(int days)
    {
        if (days <= 0) { Console.WriteLine("Days must be positive."); return; }
        var now = DateTime.Now;
        int removed = 0;
        var kept = new List<Entry>();
        foreach (var e in history)
        {
            if (e.Pinned) { kept.Add(e); continue; }
            if (DateTime.TryParse(e.Timestamp, out DateTime ts) && (now - ts).TotalDays > days)
                removed++;
            else
                kept.Add(e);
        }
        history = kept;
        SaveHistory();
        Console.WriteLine($"Removed {removed} entries older than {days} days.");
    }

    static void ExportJSON(string filename)
    {
        string json = JsonSerializer.Serialize(history, new JsonSerializerOptions { WriteIndented = true });
        File.WriteAllText(filename, json);
        Console.WriteLine($"Exported to {filename}");
    }

    static void ExportCSV(string filename)
    {
        using var writer = new StreamWriter(filename);
        writer.WriteLine("Text,Category,Timestamp,Pinned,UsageCount");
        foreach (var e in history)
            writer.WriteLine($"\"{e.Text}\",\"{e.Category}\",\"{e.Timestamp}\",{e.Pinned},{e.UsageCount}");
        Console.WriteLine($"Exported to {filename}");
    }

    static void ImportJSON(string filename)
    {
        try
        {
            string json = File.ReadAllText(filename);
            var imported = JsonSerializer.Deserialize<List<Entry>>(json);
            if (imported != null) { history = imported; SaveHistory(); Console.WriteLine($"Imported {history.Count} entries from {filename}"); }
            else Console.WriteLine("Invalid format.");
        }
        catch { Console.WriteLine("File not found or invalid JSON."); }
    }

    static void ImportCSV(string filename)
    {
        try
        {
            var lines = File.ReadAllLines(filename);
            if (lines.Length < 2) { Console.WriteLine("Empty CSV."); return; }
            var imported = new List<Entry>();
            for (int i = 1; i < lines.Length; i++)
            {
                var parts = lines[i].Split(',');
                if (parts.Length < 5) continue;
                var text = parts[0].Trim('"');
                var category = parts[1].Trim('"');
                var timestamp = parts[2].Trim('"');
                bool pinned = bool.Parse(parts[3]);
                int usage = int.Parse(parts[4]);
                var entry = new Entry
                {
                    Text = text,
                    Category = category,
                    Timestamp = timestamp,
                    Pinned = pinned,
                    UsageCount = usage,
                    Id = DateTimeOffset.UtcNow.ToUnixTimeSeconds() + i,
                    SourceApp = "imported"
                };
                imported.Add(entry);
            }
            history = imported;
            SaveHistory();
            Console.WriteLine($"Imported {history.Count} entries from {filename}");
        }
        catch (Exception e) { Console.WriteLine($"Error: {e.Message}"); }
    }
}
