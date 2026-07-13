📋 Advanced Clipboard Manager

A powerful **clipboard manager** with advanced features: categories, pinning, regex search, usage statistics, auto‑cleanup, and multiple export formats.  
Never lose a copied snippet again – organise, search, and analyse your clipboard history like a pro!  
Built in **7 programming languages** – perfect for power users, developers, and productivity enthusiasts.

## ✨ Features (Extended)
- **Multi‑slot history** – stores up to 200 entries with full metadata.
- **Categories** – assign labels (e.g., `code`, `link`, `note`, `quote`) for better organisation.
- **Pinning** – keep important entries at the top and protect them from auto‑deletion.
- **Regex search** – search using regular expressions (case‑sensitive/insensitive).
- **Source tracking** – remembers which app the text was copied from (where supported).
- **Usage counter** – tracks how many times an entry has been pasted.
- **Statistics** – shows total entries, by category, most used, average age.
- **Auto‑cleanup** – automatically remove entries older than N days (configurable).
- **Export/Import** – JSON and CSV formats.
- **Hotkey support** – optional global hotkey to open the manager (where supported).
- **Interactive CLI** – intuitive menu with numbered commands.

## 🗂 Languages & Libraries
| Language          | Library / Dependency            | File                 |
|-------------------|---------------------------------|----------------------|
| Python            | `pyperclip`, `keyboard`         | `clipboard_adv.py`   |
| Go                | `atotto/clipboard`, `robotgo`   | `clipboard_adv.go`   |
| JavaScript (Node) | `clipboardy`, `keypress`        | `clipboard_adv.js`   |
| C#                | `System.Windows.Forms` (built‑in) | `ClipboardAdv.cs`    |
| Java              | `java.awt.Toolkit` (built‑in)   | `ClipboardAdv.java`  |
| Ruby              | `clipboard` gem                 | `clipboard_adv.rb`   |
| Swift             | `NSPasteboard` (built‑in)       | `clipboard_adv.swift`|

## 🚀 How to Run
Each file is standalone – install the required library, then run with the appropriate interpreter/compiler.

| Language | Install | Run Command |
|----------|---------|-------------|
| Python   | `pip install pyperclip keyboard` | `python clipboard_adv.py` |
| Go       | `go get github.com/atotto/clipboard` | `go run clipboard_adv.go` |
| JavaScript | `npm install clipboardy keypress` | `node clipboard_adv.js` |
| C#       | (built‑in) | `dotnet run` (or `csc ClipboardAdv.cs && ClipboardAdv.exe`) |
| Java     | (built‑in) | `javac ClipboardAdv.java && java ClipboardAdv` |
| Ruby     | `gem install clipboard` | `ruby clipboard_adv.rb` |
| Swift    | (built‑in) | `swift clipboard_adv.swift` |

## 📊 Example Session
=== Advanced Clipboard Manager ===
Monitoring clipboard...
Commands:
1=history 2=add 3=search 4=paste 5=delete 6=pin 7=category
8=stats 9=cleanup 10=export 11=import 12=exit

1
[1] ★ code: print("Hello") (2026-07-13 14:32:45) [used: 3]
[2] link: https://github.com (2026-07-13 14:33:12) [used: 1]
[3] note: Meeting at 3pm (2026-07-13 14:34:01) [used: 0]

7
Enter index: 2
Enter category (code/link/note/quote/other): link
Category updated.

6
Enter index: 1
Pinned: code: print("Hello")

8
Statistics:
Total entries: 3
Categories: code:1, link:1, note:1
Most used: code (3 times)
Average age: 2.3 days

9
Auto-cleanup (remove older than N days): 30
Removed 0 entries.

text

## 🔧 Commands
| Command | Description |
|---------|-------------|
| `1` | Show all history entries |
| `2` | Save current clipboard to history |
| `3` | Search entries (regex optional) |
| `4` | Paste an entry back to clipboard |
| `5` | Delete an entry by index |
| `6` | Pin/unpin an entry |
| `7` | Set/change category |
| `8` | Show statistics |
| `9` | Auto‑cleanup entries older than N days |
| `10` | Export to JSON or CSV |
| `11` | Import from JSON or CSV |
| `12` | Exit |

## 📁 Export Formats
- **JSON** – full metadata (id, text, timestamp, category, pinned, source, usage_count).
- **CSV** – simplified table with text, category, timestamp.

## 🔧 Advanced Search
- Use `/regex/` for case‑sensitive regular expression.
- Use `/regex/i` for case‑insensitive regular expression.
- Example: `/Hello.*world/` or `/^Error/i`

## 🤝 Contributing
Add support for images, cloud sync, or a GUI – PRs welcome!

## 📜 License
MIT – use freely.
