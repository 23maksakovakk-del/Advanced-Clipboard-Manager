// ClipboardAdv.java
import java.awt.*;
import java.awt.datatransfer.*;
import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.List;
import java.util.regex.*;
import com.google.gson.*;

public class ClipboardAdv {
    private static List<Entry> history = new ArrayList<>();
    private static final int MAX_HISTORY = 200;
    private static final String DEFAULT_CATEGORY = "other";
    private static final String HISTORY_FILE = "clipboard_adv_history.json";
    private static String lastClipboard = "";
    private static boolean running = true;

    static class Entry {
        long id;
        String text;
        String timestamp;
        String category;
        boolean pinned;
        String source_app;
        int usage_count;
    }

    public static void main(String[] args) throws Exception {
        loadHistory();
        lastClipboard = getClipboardText();

        // Monitor thread
        Thread monitor = new Thread(() -> {
            while (running) {
                try {
                    String current = getClipboardText();
                    if (current != null && !current.equals(lastClipboard) && !current.isEmpty()) {
                        lastClipboard = current;
                        addEntry(current);
                    }
                    Thread.sleep(500);
                } catch (Exception e) {}
            }
        });
        monitor.setDaemon(true);
        monitor.start();

        Scanner scanner = new Scanner(System.in);
        System.out.println("=== Advanced Clipboard Manager ===");
        System.out.println("Monitoring clipboard...");
        System.out.println("Commands: 1=history, 2=add, 3=search, 4=paste, 5=delete, 6=pin, 7=category, 8=stats, 9=cleanup, 10=export, 11=import, 12=exit");

        while (running) {
            System.out.print("\n> ");
            String cmd = scanner.nextLine().trim();
            switch (cmd) {
                case "1": showHistory(); break;
                case "2":
                    String text = getClipboardText();
                    if (text != null) { addEntry(text); System.out.println("Added: " + truncate(text, 50)); }
                    break;
                case "3":
                    System.out.print("Search query (regex supported: /pattern/i): ");
                    String query = scanner.nextLine().trim();
                    if (!query.isEmpty()) searchHistory(query);
                    break;
                case "4":
                    System.out.print("Enter index: ");
                    try { int idx = Integer.parseInt(scanner.nextLine().trim()); pasteEntry(idx); }
                    catch (NumberFormatException e) { System.out.println("Invalid index."); }
                    break;
                case "5":
                    System.out.print("Enter index: ");
                    try { int idx = Integer.parseInt(scanner.nextLine().trim()); deleteEntry(idx); }
                    catch (NumberFormatException e) { System.out.println("Invalid index."); }
                    break;
                case "6":
                    System.out.print("Enter index: ");
                    try { int idx = Integer.parseInt(scanner.nextLine().trim()); togglePin(idx); }
                    catch (NumberFormatException e) { System.out.println("Invalid index."); }
                    break;
                case "7":
                    System.out.print("Enter index: ");
                    try {
                        int idx = Integer.parseInt(scanner.nextLine().trim());
                        System.out.print("Enter category (code/link/note/quote/other): ");
                        String cat = scanner.nextLine().trim();
                        if (cat.isEmpty()) cat = DEFAULT_CATEGORY;
                        setCategory(idx, cat);
                    } catch (NumberFormatException e) { System.out.println("Invalid index."); }
                    break;
                case "8": showStats(); break;
                case "9":
                    System.out.print("Remove entries older than N days: ");
                    try { int days = Integer.parseInt(scanner.nextLine().trim()); cleanup(days); }
                    catch (NumberFormatException e) { System.out.println("Invalid number."); }
                    break;
                case "10":
                    System.out.print("Export format (json/csv): ");
                    String fmt = scanner.nextLine().trim().toLowerCase();
                    System.out.print("Filename (default: export." + fmt + "): ");
                    String fname = scanner.nextLine().trim();
                    if (fname.isEmpty()) fname = "export." + fmt;
                    if (fmt.equals("json")) exportJSON(fname);
                    else if (fmt.equals("csv")) exportCSV(fname);
                    else System.out.println("Unknown format.");
                    break;
                case "11":
                    System.out.print("Import format (json/csv): ");
                    fmt = scanner.nextLine().trim().toLowerCase();
                    System.out.print("Filename: ");
                    fname = scanner.nextLine().trim();
                    if (fname.isEmpty()) { System.out.println("Filename required."); break; }
                    if (fmt.equals("json")) importJSON(fname);
                    else if (fmt.equals("csv")) importCSV(fname);
                    else System.out.println("Unknown format.");
                    break;
                case "12":
                    System.out.println("Goodbye!");
                    running = false;
                    return;
                default:
                    System.out.println("Invalid command.");
            }
        }
        scanner.close();
    }

    static void loadHistory() {
        try {
            String json = new String(Files.readAllBytes(Paths.get(HISTORY_FILE)));
            Gson gson = new Gson();
            Entry[] arr = gson.fromJson(json, Entry[].class);
            if (arr != null) history = new ArrayList<>(Arrays.asList(arr));
        } catch (Exception e) { history = new ArrayList<>(); }
    }

    static void saveHistory() {
        Gson gson = new GsonBuilder().setPrettyPrinting().create();
        String json = gson.toJson(history);
        try { Files.write(Paths.get(HISTORY_FILE), json.getBytes()); } catch (Exception e) {}
    }

    static void addEntry(String text) {
        if (text == null || text.trim().isEmpty()) return;
        if (!history.isEmpty() && history.get(0).text.equals(text)) return;
        Entry e = new Entry();
        e.id = System.currentTimeMillis();
        e.text = text;
        e.timestamp = new java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new java.util.Date());
        e.category = DEFAULT_CATEGORY;
        e.pinned = false;
        e.source_app = "unknown";
        e.usage_count = 0;
        history.add(0, e);
        if (history.size() > MAX_HISTORY) {
            for (int i = history.size()-1; i >= 0; i--) {
                if (!history.get(i).pinned) {
                    history.remove(i);
                    break;
                }
            }
            if (history.size() > MAX_HISTORY) history.remove(history.size()-1);
        }
        saveHistory();
    }

    static String getClipboardText() {
        try {
            Clipboard clipboard = Toolkit.getDefaultToolkit().getSystemClipboard();
            Transferable contents = clipboard.getContents(null);
            if (contents != null && contents.isDataFlavorSupported(DataFlavor.stringFlavor)) {
                return (String) contents.getTransferData(DataFlavor.stringFlavor);
            }
        } catch (Exception e) {}
        return null;
    }

    static String truncate(String s, int n) {
        return s.length() > n ? s.substring(0, n) + "..." : s;
    }

    static void showHistory() {
        if (history.isEmpty()) { System.out.println("History is empty."); return; }
        for (int i = 0; i < history.size(); i++) {
            Entry e = history.get(i);
            String pin = e.pinned ? "★ " : "";
            System.out.printf("[%d] %s%s: %s  (%s)  [used: %d]%n", i+1, pin, e.category, truncate(e.text, 50), e.timestamp, e.usage_count);
        }
    }

    static void searchHistory(String query) {
        boolean isRegex = false, caseSensitive = true;
        String pattern = query;
        if (query.startsWith("/") && (query.endsWith("/") || query.endsWith("/i"))) {
            isRegex = true;
            if (query.endsWith("/i")) {
                pattern = query.substring(1, query.length()-2);
                caseSensitive = false;
            } else {
                pattern = query.substring(1, query.length()-1);
                caseSensitive = true;
            }
        }
        List<Entry> results = new ArrayList<>();
        for (Entry e : history) {
            if (isRegex) {
                try {
                    int flags = caseSensitive ? 0 : Pattern.CASE_INSENSITIVE;
                    if (Pattern.compile(pattern, flags).matcher(e.text).find())
                        results.add(e);
                } catch (PatternSyntaxException ex) {
                    System.out.println("Invalid regex.");
                    return;
                }
            } else {
                if (e.text.toLowerCase().contains(query.toLowerCase()))
                    results.add(e);
            }
        }
        if (results.isEmpty()) { System.out.println("No matches found."); return; }
        for (int i = 0; i < results.size(); i++) {
            Entry e = results.get(i);
            String pin = e.pinned ? "★ " : "";
            System.out.printf("[%d] %s%s: %s  (%s)  [used: %d]%n", i+1, pin, e.category, truncate(e.text, 50), e.timestamp, e.usage_count);
        }
    }

    static void pasteEntry(int index) {
        if (index < 1 || index > history.size()) { System.out.println("Invalid index."); return; }
        Entry e = history.get(index-1);
        StringSelection sel = new StringSelection(e.text);
        Toolkit.getDefaultToolkit().getSystemClipboard().setContents(sel, null);
        e.usage_count++;
        saveHistory();
        System.out.println("Copied to clipboard: " + truncate(e.text, 50));
    }

    static void deleteEntry(int index) {
        if (index < 1 || index > history.size()) { System.out.println("Invalid index."); return; }
        Entry removed = history.remove(index-1);
        saveHistory();
        System.out.println("Deleted: " + truncate(removed.text, 50));
    }

    static void togglePin(int index) {
        if (index < 1 || index > history.size()) { System.out.println("Invalid index."); return; }
        Entry e = history.get(index-1);
        e.pinned = !e.pinned;
        saveHistory();
        System.out.println("Entry " + (e.pinned ? "pinned" : "unpinned") + ": " + truncate(e.text, 50));
    }

    static void setCategory(int index, String category) {
        if (index < 1 || index > history.size()) { System.out.println("Invalid index."); return; }
        Entry e = history.get(index-1);
        e.category = category;
        saveHistory();
        System.out.println("Category updated: " + truncate(e.text, 50) + " -> " + category);
    }

    static void showStats() {
        int total = history.size();
        if (total == 0) { System.out.println("No entries."); return; }
        Map<String, Integer> categories = new HashMap<>();
        int pinnedCount = 0, totalUsage = 0, mostUsed = 0;
        java.util.Date now = new java.util.Date();
        List<Double> ages = new ArrayList<>();
        for (Entry e : history) {
            categories.put(e.category, categories.getOrDefault(e.category, 0) + 1);
            if (e.pinned) pinnedCount++;
            totalUsage += e.usage_count;
            if (e.usage_count > mostUsed) mostUsed = e.usage_count;
            try {
                java.util.Date ts = new java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss").parse(e.timestamp);
                double days = (now.getTime() - ts.getTime()) / (1000.0 * 60 * 60 * 24);
                ages.add(days);
            } catch (java.text.ParseException ex) {}
        }
        double avgAge = ages.stream().mapToDouble(Double::doubleValue).average().orElse(0);
        System.out.println("Statistics:");
        System.out.println("  Total entries: " + total);
        System.out.println("  Pinned: " + pinnedCount);
        System.out.print("  Categories: ");
        categories.forEach((k,v) -> System.out.print(k + ":" + v + " "));
        System.out.println();
        System.out.println("  Most used count: " + mostUsed);
        System.out.println("  Total usage: " + totalUsage);
        System.out.println("  Average age: " + String.format("%.1f", avgAge) + " days");
    }

    static void cleanup(int days) {
        if (days <= 0) { System.out.println("Days must be positive."); return; }
        java.util.Date now = new java.util.Date();
        int removed = 0;
        List<Entry> kept = new ArrayList<>();
        for (Entry e : history) {
            if (e.pinned) { kept.add(e); continue; }
            try {
                java.util.Date ts = new java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss").parse(e.timestamp);
                if ((now.getTime() - ts.getTime()) / (1000.0 * 60 * 60 * 24) > days) removed++;
                else kept.add(e);
            } catch (java.text.ParseException ex) { kept.add(e); }
        }
        history = kept;
        saveHistory();
        System.out.println("Removed " + removed + " entries older than " + days + " days.");
    }

    static void exportJSON(String filename) {
        Gson gson = new GsonBuilder().setPrettyPrinting().create();
        String json = gson.toJson(history);
        try { Files.write(Paths.get(filename), json.getBytes()); System.out.println("Exported to " + filename); }
        catch (Exception e) { System.out.println("Export failed."); }
    }

    static void exportCSV(String filename) {
        try (PrintWriter pw = new PrintWriter(filename)) {
            pw.println("Text,Category,Timestamp,Pinned,UsageCount");
            for (Entry e : history) {
                pw.printf("\"%s\",\"%s\",\"%s\",%b,%d%n", e.text, e.category, e.timestamp, e.pinned, e.usage_count);
            }
            System.out.println("Exported to " + filename);
        } catch (Exception e) { System.out.println("Export failed."); }
    }

    static void importJSON(String filename) {
        try {
            String json = new String(Files.readAllBytes(Paths.get(filename)));
            Gson gson = new Gson();
            Entry[] arr = gson.fromJson(json, Entry[].class);
            if (arr != null) { history = new ArrayList<>(Arrays.asList(arr)); saveHistory(); System.out.println("Imported " + history.size() + " entries from " + filename); }
        } catch (Exception e) { System.out.println("File not found or invalid JSON."); }
    }

    static void importCSV(String filename) {
        try (BufferedReader br = new BufferedReader(new FileReader(filename))) {
            String line = br.readLine(); // header
            if (line == null) { System.out.println("Empty CSV."); return; }
            List<Entry> imported = new ArrayList<>();
            int idx = 0;
            while ((line = br.readLine()) != null) {
                String[] parts = line.split(",");
                if (parts.length < 5) continue;
                Entry e = new Entry();
                e.text = parts[0].replaceAll("^\"|\"$", "");
                e.category = parts[1].replaceAll("^\"|\"$", "");
                e.timestamp = parts[2].replaceAll("^\"|\"$", "");
                e.pinned = Boolean.parseBoolean(parts[3]);
                e.usage_count = Integer.parseInt(parts[4]);
                e.id = System.currentTimeMillis() + idx++;
                e.source_app = "imported";
                imported.add(e);
            }
            history = imported;
            saveHistory();
            System.out.println("Imported " + history.size() + " entries from " + filename);
        } catch (Exception e) { System.out.println("Error: " + e.getMessage()); }
    }
}
