# clipboard_adv.py
import json
import time
import os
import re
from datetime import datetime, timedelta
import threading
import sys

try:
    import pyperclip
    import keyboard
except ImportError:
    print("Please install: pip install pyperclip keyboard")
    sys.exit(1)

HISTORY_FILE = "clipboard_adv_history.json"
MAX_HISTORY = 200
DEFAULT_CATEGORY = "other"
history = []
last_clipboard = ""
running = True

def load_history():
    global history
    try:
        with open(HISTORY_FILE, 'r', encoding='utf-8') as f:
            history = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        history = []

def save_history():
    with open(HISTORY_FILE, 'w', encoding='utf-8') as f:
        json.dump(history, f, indent=2, ensure_ascii=False)

def add_entry(text, source_app=""):
    if not text or text.strip() == "":
        return
    # Avoid duplicates (last entry)
    if history and history[0]["text"] == text:
        return
    entry = {
        "id": int(time.time()),
        "text": text,
        "timestamp": datetime.now().isoformat(),
        "category": DEFAULT_CATEGORY,
        "pinned": False,
        "source_app": source_app,
        "usage_count": 0
    }
    history.insert(0, entry)
    if len(history) > MAX_HISTORY:
        # Remove oldest non-pinned entries
        non_pinned = [i for i, e in enumerate(history) if not e["pinned"]]
        if non_pinned:
            del history[non_pinned[-1]]
        else:
            history.pop()
    save_history()

def monitor_clipboard():
    global last_clipboard
    while running:
        try:
            current = pyperclip.paste()
            if current and current != last_clipboard:
                last_clipboard = current
                # Try to get source app (not easily cross-platform; placeholder)
                add_entry(current, "unknown")
        except:
            pass
        time.sleep(0.5)

def show_history():
    if not history:
        print("History is empty.")
        return
    for i, entry in enumerate(history, 1):
        pin = "★ " if entry.get("pinned", False) else ""
        cat = entry.get("category", DEFAULT_CATEGORY)
        used = entry.get("usage_count", 0)
        print(f"[{i}] {pin}{cat}: {entry['text'][:50]}  ({entry['timestamp']})  [used: {used}]")

def search_history(query):
    # Check if query is a regex pattern
    is_regex = False
    case_sensitive = True
    pattern = query
    if query.startswith('/') and (query.endswith('/') or query.endswith('/i')):
        is_regex = True
        if query.endswith('/i'):
            pattern = query[1:-2]
            case_sensitive = False
        else:
            pattern = query[1:-1]
            case_sensitive = True
    results = []
    for entry in history:
        text = entry["text"]
        if is_regex:
            try:
                flags = 0 if case_sensitive else re.IGNORECASE
                if re.search(pattern, text, flags):
                    results.append(entry)
            except re.error:
                print("Invalid regex.")
                return
        else:
            if query.lower() in text.lower():
                results.append(entry)
    if not results:
        print("No matches found.")
        return
    for i, entry in enumerate(results, 1):
        pin = "★ " if entry.get("pinned", False) else ""
        cat = entry.get("category", DEFAULT_CATEGORY)
        used = entry.get("usage_count", 0)
        print(f"[{i}] {pin}{cat}: {entry['text'][:50]}  ({entry['timestamp']})  [used: {used}]")

def paste_entry(index):
    if not history:
        print("History is empty.")
        return
    if 1 <= index <= len(history):
        entry = history[index-1]
        pyperclip.copy(entry["text"])
        # Increment usage count
        entry["usage_count"] = entry.get("usage_count", 0) + 1
        save_history()
        print(f"Copied to clipboard: {entry['text'][:50]}")
    else:
        print("Invalid index.")

def delete_entry(index):
    if 1 <= index <= len(history):
        removed = history.pop(index-1)
        save_history()
        print(f"Deleted: {removed['text'][:50]}")
    else:
        print("Invalid index.")

def toggle_pin(index):
    if 1 <= index <= len(history):
        entry = history[index-1]
        entry["pinned"] = not entry.get("pinned", False)
        save_history()
        status = "pinned" if entry["pinned"] else "unpinned"
        print(f"Entry {status}: {entry['text'][:50]}")
    else:
        print("Invalid index.")

def set_category(index, category):
    if 1 <= index <= len(history):
        entry = history[index-1]
        entry["category"] = category
        save_history()
        print(f"Category updated: {entry['text'][:50]} -> {category}")
    else:
        print("Invalid index.")

def show_stats():
    total = len(history)
    if total == 0:
        print("No entries.")
        return
    categories = {}
    pinned_count = 0
    usage_counts = [e.get("usage_count", 0) for e in history]
    most_used = max(usage_counts) if usage_counts else 0
    total_usage = sum(usage_counts)
    for e in history:
        cat = e.get("category", DEFAULT_CATEGORY)
        categories[cat] = categories.get(cat, 0) + 1
        if e.get("pinned", False):
            pinned_count += 1
    # Average age
    now = datetime.now()
    ages = []
    for e in history:
        try:
            ts = datetime.fromisoformat(e["timestamp"])
            ages.append((now - ts).days)
        except:
            pass
    avg_age = sum(ages)/len(ages) if ages else 0
    print(f"Statistics:")
    print(f"  Total entries: {total}")
    print(f"  Pinned: {pinned_count}")
    print(f"  Categories: {', '.join(f'{k}:{v}' for k,v in categories.items())}")
    print(f"  Most used count: {most_used}")
    print(f"  Total usage: {total_usage}")
    print(f"  Average age: {avg_age:.1f} days")

def cleanup(days):
    if days <= 0:
        print("Days must be positive.")
        return
    now = datetime.now()
    removed = 0
    to_keep = []
    for e in history:
        if e.get("pinned", False):
            to_keep.append(e)
            continue
        try:
            ts = datetime.fromisoformat(e["timestamp"])
            if (now - ts).days > days:
                removed += 1
            else:
                to_keep.append(e)
        except:
            to_keep.append(e)
    global history
    history = to_keep
    save_history()
    print(f"Removed {removed} entries older than {days} days.")

def export_json(filename):
    with open(filename, 'w', encoding='utf-8') as f:
        json.dump(history, f, indent=2, ensure_ascii=False)
    print(f"Exported to {filename}")

def export_csv(filename):
    import csv
    with open(filename, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(["Text", "Category", "Timestamp", "Pinned", "UsageCount"])
        for e in history:
            writer.writerow([e["text"], e.get("category", DEFAULT_CATEGORY),
                             e["timestamp"], e.get("pinned", False), e.get("usage_count", 0)])
    print(f"Exported to {filename}")

def import_json(filename):
    global history
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            imported = json.load(f)
        if isinstance(imported, list):
            history = imported
            save_history()
            print(f"Imported {len(history)} entries from {filename}")
        else:
            print("Invalid format: expected list.")
    except Exception as e:
        print(f"Error: {e}")

def import_csv(filename):
    global history
    import csv
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            new_history = []
            for row in reader:
                entry = {
                    "text": row["Text"],
                    "category": row.get("Category", DEFAULT_CATEGORY),
                    "timestamp": row.get("Timestamp", datetime.now().isoformat()),
                    "pinned": row.get("Pinned", "False").lower() == "true",
                    "usage_count": int(row.get("UsageCount", 0)),
                    "id": int(time.time() + len(new_history))
                }
                new_history.append(entry)
            history = new_history
            save_history()
            print(f"Imported {len(history)} entries from {filename}")
    except Exception as e:
        print(f"Error: {e}")

def main():
    global running
    load_history()
    global last_clipboard
    last_clipboard = pyperclip.paste()

    monitor_thread = threading.Thread(target=monitor_clipboard, daemon=True)
    monitor_thread.start()

    print("=== Advanced Clipboard Manager ===")
    print("Monitoring clipboard... (Ctrl+C to stop)")
    print("Commands: 1=history, 2=add, 3=search, 4=paste, 5=delete, 6=pin, 7=category, 8=stats, 9=cleanup, 10=export, 11=import, 12=exit")

    try:
        while True:
            cmd = input("\n> ").strip()
            if cmd == "1":
                show_history()
            elif cmd == "2":
                text = pyperclip.paste()
                add_entry(text)
                print(f"Added: {text[:50]}")
            elif cmd == "3":
                query = input("Search query (regex supported: /pattern/i): ").strip()
                if query:
                    search_history(query)
            elif cmd == "4":
                idx = input("Enter index: ").strip()
                if idx.isdigit():
                    paste_entry(int(idx))
            elif cmd == "5":
                idx = input("Enter index: ").strip()
                if idx.isdigit():
                    delete_entry(int(idx))
            elif cmd == "6":
                idx = input("Enter index: ").strip()
                if idx.isdigit():
                    toggle_pin(int(idx))
            elif cmd == "7":
                idx = input("Enter index: ").strip()
                if not idx.isdigit():
                    print("Invalid index.")
                    continue
                cat = input("Enter category (code/link/note/quote/other): ").strip() or DEFAULT_CATEGORY
                set_category(int(idx), cat)
            elif cmd == "8":
                show_stats()
            elif cmd == "9":
                days = input("Remove entries older than N days: ").strip()
                if days.isdigit():
                    cleanup(int(days))
                else:
                    print("Invalid number.")
            elif cmd == "10":
                fmt = input("Export format (json/csv): ").strip().lower()
                fname = input("Filename (default: export.{}): ".format(fmt)).strip()
                if not fname:
                    fname = f"export.{fmt}"
                if fmt == "json":
                    export_json(fname)
                elif fmt == "csv":
                    export_csv(fname)
                else:
                    print("Unknown format.")
            elif cmd == "11":
                fmt = input("Import format (json/csv): ").strip().lower()
                fname = input("Filename: ").strip()
                if not fname:
                    print("Filename required.")
                    continue
                if fmt == "json":
                    import_json(fname)
                elif fmt == "csv":
                    import_csv(fname)
                else:
                    print("Unknown format.")
            elif cmd == "12":
                print("Goodbye!")
                running = False
                break
            else:
                print("Invalid command.")
    except KeyboardInterrupt:
        print("\nGoodbye!")
        running = False

if __name__ == "__main__":
    main()
