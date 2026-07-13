// clipboard_adv.swift
import Foundation
import AppKit

let HISTORY_FILE = "clipboard_adv_history.json"
let MAX_HISTORY = 200
let DEFAULT_CATEGORY = "other"
var history: [[String: Any]] = []
var lastClipboard = ""
var running = true

func loadHistory() {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: HISTORY_FILE)),
          let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
        history = []
        return
    }
    history = json
}

func saveHistory() {
    guard let data = try? JSONSerialization.data(withJSONObject: history, options: .prettyPrinted) else { return }
    try? data.write(to: URL(fileURLWithPath: HISTORY_FILE))
}

func addEntry(_ text: String) {
    if text.isEmpty { return }
    if let first = history.first, let firstText = first["text"] as? String, firstText == text { return }
    var entry: [String: Any] = [
        "id": Date().timeIntervalSince1970,
        "text": text,
        "timestamp": Date().ISO8601Format(),
        "category": DEFAULT_CATEGORY,
        "pinned": false,
        "source_app": "unknown",
        "usage_count": 0
    ]
    history.insert(entry, at: 0)
    if history.count > MAX_HISTORY {
        for i in (1..<history.count).reversed() {
            if let pinned = history[i]["pinned"] as? Bool, !pinned {
                history.remove(at: i)
                break
            }
        }
        if history.count > MAX_HISTORY { history.removeLast() }
    }
    saveHistory()
}

func getClipboardText() -> String? {
    return NSPasteboard.general.string
}

func truncate(_ s: String, _ n: Int) -> String {
    return s.count > n ? String(s.prefix(n)) + "..." : s
}

func showHistory() {
    if history.isEmpty {
        print("History is empty.")
        return
    }
    for (i, entry) in history.enumerated() {
        let text = entry["text"] as? String ?? ""
        let timestamp = entry["timestamp"] as? String ?? ""
        let category = entry["category"] as? String ?? DEFAULT_CATEGORY
        let pinned = entry["pinned"] as? Bool ?? false
        let usage = entry["usage_count"] as? Int ?? 0
        let pin = pinned ? "★ " : ""
        print("[\(i+1)] \(pin)\(category): \(truncate(text, 50))  (\(timestamp))  [used: \(usage)]")
    }
}

func searchHistory(_ query: String) {
    var isRegex = false
    var caseSensitive = true
    var pattern = query
    if query.hasPrefix("/") && (query.hasSuffix("/") || query.hasSuffix("/i")) {
        isRegex = true
        if query.hasSuffix("/i") {
            pattern = String(query.dropFirst().dropLast(2))
            caseSensitive = false
        } else {
            pattern = String(query.dropFirst().dropLast())
            caseSensitive = true
        }
    }
    var results: [[String: Any]] = []
    for entry in history {
        let text = entry["text"] as? String ?? ""
        if isRegex {
            do {
                let options = caseSensitive ? NSRegularExpression.Options() : .caseInsensitive
                let regex = try NSRegularExpression(pattern: pattern, options: options)
                if regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                    results.append(entry)
                }
            } catch {
                print("Invalid regex.")
                return
            }
        } else {
            if text.lowercased().contains(query.lowercased()) {
                results.append(entry)
            }
        }
    }
    if results.isEmpty {
        print("No matches found.")
        return
    }
    for (i, entry) in results.enumerated() {
        let text = entry["text"] as? String ?? ""
        let timestamp = entry["timestamp"] as? String ?? ""
        let category = entry["category"] as? String ?? DEFAULT_CATEGORY
        let pinned = entry["pinned"] as? Bool ?? false
        let usage = entry["usage_count"] as? Int ?? 0
        let pin = pinned ? "★ " : ""
        print("[\(i+1)] \(pin)\(category): \(truncate(text, 50))  (\(timestamp))  [used: \(usage)]")
    }
}

func pasteEntry(_ index: Int) {
    if index < 1 || index > history.count {
        print("Invalid index.")
        return
    }
    var entry = history[index-1]
    let text = entry["text"] as? String ?? ""
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    var usage = entry["usage_count"] as? Int ?? 0
    usage += 1
    entry["usage_count"] = usage
    history[index-1] = entry
    saveHistory()
    print("Copied to clipboard: \(truncate(text, 50))")
}

func deleteEntry(_ index: Int) {
    if index < 1 || index > history.count {
        print("Invalid index.")
        return
    }
    let removed = history.remove(at: index-1)
    let text = removed["text"] as? String ?? ""
    saveHistory()
    print("Deleted: \(truncate(text, 50))")
}

func togglePin(_ index: Int) {
    if index < 1 || index > history.count {
        print("Invalid index.")
        return
    }
    var entry = history[index-1]
    let pinned = entry["pinned"] as? Bool ?? false
    entry["pinned"] = !pinned
    history[index-1] = entry
    saveHistory()
    let status = entry["pinned"] as? Bool ?? false ? "pinned" : "unpinned"
    let text = entry["text"] as? String ?? ""
    print("Entry \(status): \(truncate(text, 50))")
}

func setCategory(_ index: Int, category: String) {
    if index < 1 || index > history.count {
        print("Invalid index.")
        return
    }
    var entry = history[index-1]
    entry["category"] = category
    history[index-1] = entry
    saveHistory()
    let text = entry["text"] as? String ?? ""
    print("Category updated: \(truncate(text, 50)) -> \(category)")
}

func showStats() {
    let total = history.count
    if total == 0 {
        print("No entries.")
        return
    }
    var categories: [String: Int] = [:]
    var pinnedCount = 0
    var totalUsage = 0
    var mostUsed = 0
    var ages: [Double] = []
    let now = Date()
    for entry in history {
        let cat = entry["category"] as? String ?? DEFAULT_CATEGORY
        categories[cat] = (categories[cat] ?? 0) + 1
        if entry["pinned"] as? Bool == true { pinnedCount += 1 }
        let usage = entry["usage_count"] as? Int ?? 0
        totalUsage += usage
        if usage > mostUsed { mostUsed = usage }
        if let tsStr = entry["timestamp"] as? String {
            let formatter = ISO8601DateFormatter()
            if let ts = formatter.date(from: tsStr) {
                let days = now.timeIntervalSince(ts) / (60 * 60 * 24)
                ages.append(days)
            }
        }
    }
    let avgAge = ages.isEmpty ? 0 : ages.reduce(0, +) / Double(ages.count)
    print("Statistics:")
    print("  Total entries: \(total)")
    print("  Pinned: \(pinnedCount)")
    print("  Categories: \(categories.map { "\($0.key):\($0.value)" }.joined(separator: ", "))")
    print("  Most used count: \(mostUsed)")
    print("  Total usage: \(totalUsage)")
    print("  Average age: \(String(format: "%.1f", avgAge)) days")
}

func cleanup(_ days: Int) {
    if days <= 0 {
        print("Days must be positive.")
        return
    }
    let now = Date()
    var removed = 0
    var kept: [[String: Any]] = []
    let formatter = ISO8601DateFormatter()
    for entry in history {
        if entry["pinned"] as? Bool == true {
            kept.append(entry)
            continue
        }
        if let tsStr = entry["timestamp"] as? String,
           let ts = formatter.date(from: tsStr) {
            if now.timeIntervalSince(ts) / (60 * 60 * 24) > Double(days) {
                removed += 1
            } else {
                kept.append(entry)
            }
        } else {
            kept.append(entry)
        }
    }
    history = kept
    saveHistory()
    print("Removed \(removed) entries older than \(days) days.")
}

func exportJSON(_ filename: String) {
    guard let data = try? JSONSerialization.data(withJSONObject: history, options: .prettyPrinted) else { return }
    try? data.write(to: URL(fileURLWithPath: filename))
    print("Exported to \(filename)")
}

func exportCSV(_ filename: String) {
    var lines = ["Text,Category,Timestamp,Pinned,UsageCount"]
    for entry in history {
        let text = entry["text"] as? String ?? ""
        let cat = entry["category"] as? String ?? DEFAULT_CATEGORY
        let ts = entry["timestamp"] as? String ?? ""
        let pinned = entry["pinned"] as? Bool ?? false
        let usage = entry["usage_count"] as? Int ?? 0
        lines.append("\"\(text)\",\"\(cat)\",\"\(ts)\",\(pinned),\(usage)")
    }
    try? lines.joined(separator: "\n").write(toFile: filename, atomically: true, encoding: .utf8)
    print("Exported to \(filename)")
}

func importJSON(_ filename: String) {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: filename)),
          let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
        print("File not found or invalid JSON.")
        return
    }
    history = json
    saveHistory()
    print("Imported \(history.count) entries from \(filename)")
}

func importCSV(_ filename: String) {
    guard let content = try? String(contentsOfFile: filename, encoding: .utf8) else {
        print("File not found.")
        return
    }
    let lines = content.split(separator: "\n")
    guard lines.count > 1 else {
        print("Empty CSV.")
        return
    }
    var imported: [[String: Any]] = []
    for (idx, line) in lines.enumerated() {
        if idx == 0 { continue }
        let parts = line.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count >= 5 else { continue }
        let text = parts[0].replacingOccurrences(of: "^\"|\"$", with: "", options: .regularExpression)
        let category = parts[1].replacingOccurrences(of: "^\"|\"$", with: "", options: .regularExpression)
        let timestamp = parts[2].replacingOccurrences(of: "^\"|\"$", with: "", options: .regularExpression)
        let pinned = parts[3] == "true"
        let usage = Int(parts[4]) ?? 0
        var entry: [String: Any] = [
            "text": text,
            "category": category,
            "timestamp": timestamp,
            "pinned": pinned,
            "usage_count": usage,
            "id": Date().timeIntervalSince1970 + Double(idx),
            "source_app": "imported"
        ]
        imported.append(entry)
    }
    history = imported
    saveHistory()
    print("Imported \(history.count) entries from \(filename)")
}

func main() {
    loadHistory()
    lastClipboard = getClipboardText() ?? ""

    DispatchQueue.global().async {
        while running {
            let current = getClipboardText() ?? ""
            if current != lastClipboard && !current.isEmpty {
                lastClipboard = current
                addEntry(current)
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    print("=== Advanced Clipboard Manager ===")
    print("Monitoring clipboard...")
    print("Commands: 1=history, 2=add, 3=search, 4=paste, 5=delete, 6=pin, 7=category, 8=stats, 9=cleanup, 10=export, 11=import, 12=exit")

    while true {
        print("\n> ", terminator: "")
        guard let cmd = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else { break }
        switch cmd {
        case "1": showHistory()
        case "2":
            let text = getClipboardText() ?? ""
            addEntry(text)
            print("Added: \(truncate(text, 50))")
        case "3":
            print("Search query (regex supported: /pattern/i): ", terminator: "")
            if let query = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !query.isEmpty {
                searchHistory(query)
            }
        case "4":
            print("Enter index: ", terminator: "")
            if let idxStr = readLine(), let idx = Int(idxStr) {
                pasteEntry(idx)
            }
        case "5":
            print("Enter index: ", terminator: "")
            if let idxStr = readLine(), let idx = Int(idxStr) {
                deleteEntry(idx)
            }
        case "6":
            print("Enter index: ", terminator: "")
            if let idxStr = readLine(), let idx = Int(idxStr) {
                togglePin(idx)
            }
        case "7":
            print("Enter index: ", terminator: "")
            if let idxStr = readLine(), let idx = Int(idxStr) {
                print("Enter category (code/link/note/quote/other): ", terminator: "")
                let cat = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? DEFAULT_CATEGORY
                setCategory(idx, category: cat)
            }
        case "8": showStats()
        case "9":
            print("Remove entries older than N days: ", terminator: "")
            if let daysStr = readLine(), let days = Int(daysStr) {
                cleanup(days)
            }
        case "10":
            print("Export format (json/csv): ", terminator: "")
            let fmt = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "json"
            print("Filename (default: export.\(fmt)): ", terminator: "")
            var fname = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "export.\(fmt)"
            if fname.isEmpty { fname = "export.\(fmt)" }
            if fmt == "json" { exportJSON(fname) }
            else if fmt == "csv" { exportCSV(fname) }
            else { print("Unknown format.") }
        case "11":
            print("Import format (json/csv): ", terminator: "")
            let fmt = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "json"
            print("Filename: ", terminator: "")
            guard let fname = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !fname.isEmpty else {
                print("Filename required.")
                continue
            }
            if fmt == "json" { importJSON(fname) }
            else if fmt == "csv" { importCSV(fname) }
            else { print("Unknown format.") }
        case "12":
            print("Goodbye!")
            running = false
            return
        default:
            print("Invalid command.")
        }
    }
}

main()
