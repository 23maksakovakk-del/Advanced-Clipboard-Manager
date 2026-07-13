// clipboard_adv.go
package main

import (
	"bufio"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"
	"github.com/atotto/clipboard"
)

type Entry struct {
	ID         int64  `json:"id"`
	Text       string `json:"text"`
	Timestamp  string `json:"timestamp"`
	Category   string `json:"category"`
	Pinned     bool   `json:"pinned"`
	SourceApp  string `json:"source_app"`
	UsageCount int    `json:"usage_count"`
}

var history []Entry
const maxHistory = 200
const defaultCategory = "other"
var historyFile = "clipboard_adv_history.json"
var lastClipboard = ""
var running = true

func loadHistory() {
	data, err := os.ReadFile(historyFile)
	if err != nil {
		return
	}
	json.Unmarshal(data, &history)
}

func saveHistory() {
	data, _ := json.MarshalIndent(history, "", "  ")
	os.WriteFile(historyFile, data, 0644)
}

func addEntry(text string) {
	if text == "" {
		return
	}
	if len(history) > 0 && history[0].Text == text {
		return
	}
	entry := Entry{
		ID:         time.Now().Unix(),
		Text:       text,
		Timestamp:  time.Now().Format("2006-01-02 15:04:05"),
		Category:   defaultCategory,
		Pinned:     false,
		SourceApp:  "unknown",
		UsageCount: 0,
	}
	history = append([]Entry{entry}, history...)
	// Remove oldest non-pinned if over limit
	if len(history) > maxHistory {
		for i := len(history) - 1; i >= 0; i-- {
			if !history[i].Pinned {
				history = append(history[:i], history[i+1:]...)
				break
			}
		}
		if len(history) > maxHistory {
			history = history[:maxHistory]
		}
	}
	saveHistory()
}

func truncate(s string, n int) string {
	if len(s) > n {
		return s[:n] + "..."
	}
	return s
}

func showHistory() {
	if len(history) == 0 {
		fmt.Println("History is empty.")
		return
	}
	for i, e := range history {
		pin := ""
		if e.Pinned {
			pin = "★ "
		}
		fmt.Printf("[%d] %s%s: %s  (%s)  [used: %d]\n", i+1, pin, e.Category, truncate(e.Text, 50), e.Timestamp, e.UsageCount)
	}
}

func searchHistory(query string) {
	isRegex := false
	caseSensitive := true
	pattern := query
	if strings.HasPrefix(query, "/") && (strings.HasSuffix(query, "/") || strings.HasSuffix(query, "/i")) {
		isRegex = true
		if strings.HasSuffix(query, "/i") {
			pattern = query[1 : len(query)-2]
			caseSensitive = false
		} else {
			pattern = query[1 : len(query)-1]
			caseSensitive = true
		}
	}
	var results []Entry
	for _, e := range history {
		if isRegex {
			flags := 0
			if !caseSensitive {
				flags = regexp.IGNORECASE
			}
			re, err := regexp.Compile(pattern)
			if err != nil {
				fmt.Println("Invalid regex.")
				return
			}
			if re.MatchString(e.Text) {
				results = append(results, e)
			}
		} else {
			if strings.Contains(strings.ToLower(e.Text), strings.ToLower(query)) {
				results = append(results, e)
			}
		}
	}
	if len(results) == 0 {
		fmt.Println("No matches found.")
		return
	}
	for i, e := range results {
		pin := ""
		if e.Pinned {
			pin = "★ "
		}
		fmt.Printf("[%d] %s%s: %s  (%s)  [used: %d]\n", i+1, pin, e.Category, truncate(e.Text, 50), e.Timestamp, e.UsageCount)
	}
}

func pasteEntry(index int) {
	if index < 1 || index > len(history) {
		fmt.Println("Invalid index.")
		return
	}
	e := history[index-1]
	clipboard.WriteAll(e.Text)
	e.UsageCount++
	saveHistory()
	fmt.Printf("Copied to clipboard: %s\n", truncate(e.Text, 50))
}

func deleteEntry(index int) {
	if index < 1 || index > len(history) {
		fmt.Println("Invalid index.")
		return
	}
	removed := history[index-1]
	history = append(history[:index-1], history[index:]...)
	saveHistory()
	fmt.Printf("Deleted: %s\n", truncate(removed.Text, 50))
}

func togglePin(index int) {
	if index < 1 || index > len(history) {
		fmt.Println("Invalid index.")
		return
	}
	e := &history[index-1]
	e.Pinned = !e.Pinned
	saveHistory()
	status := "unpinned"
	if e.Pinned {
		status = "pinned"
	}
	fmt.Printf("Entry %s: %s\n", status, truncate(e.Text, 50))
}

func setCategory(index int, category string) {
	if index < 1 || index > len(history) {
		fmt.Println("Invalid index.")
		return
	}
	e := &history[index-1]
	e.Category = category
	saveHistory()
	fmt.Printf("Category updated: %s -> %s\n", truncate(e.Text, 50), category)
}

func showStats() {
	total := len(history)
	if total == 0 {
		fmt.Println("No entries.")
		return
	}
	categories := make(map[string]int)
	pinnedCount := 0
	usageCounts := []int{}
	for _, e := range history {
		categories[e.Category]++
		if e.Pinned {
			pinnedCount++
		}
		usageCounts = append(usageCounts, e.UsageCount)
	}
	mostUsed := 0
	totalUsage := 0
	for _, u := range usageCounts {
		if u > mostUsed {
			mostUsed = u
		}
		totalUsage += u
	}
	// avg age
	now := time.Now()
	var ages []float64
	for _, e := range history {
		t, err := time.Parse("2006-01-02 15:04:05", e.Timestamp)
		if err == nil {
			ages = append(ages, now.Sub(t).Hours()/24)
		}
	}
	avgAge := 0.0
	if len(ages) > 0 {
		sum := 0.0
		for _, a := range ages {
			sum += a
		}
		avgAge = sum / float64(len(ages))
	}
	fmt.Println("Statistics:")
	fmt.Printf("  Total entries: %d\n", total)
	fmt.Printf("  Pinned: %d\n", pinnedCount)
	fmt.Printf("  Categories: ")
	for cat, cnt := range categories {
		fmt.Printf("%s:%d ", cat, cnt)
	}
	fmt.Println()
	fmt.Printf("  Most used count: %d\n", mostUsed)
	fmt.Printf("  Total usage: %d\n", totalUsage)
	fmt.Printf("  Average age: %.1f days\n", avgAge)
}

func cleanup(days int) {
	if days <= 0 {
		fmt.Println("Days must be positive.")
		return
	}
	now := time.Now()
	kept := []Entry{}
	removed := 0
	for _, e := range history {
		if e.Pinned {
			kept = append(kept, e)
			continue
		}
		t, err := time.Parse("2006-01-02 15:04:05", e.Timestamp)
		if err != nil {
			kept = append(kept, e)
			continue
		}
		if now.Sub(t).Hours()/24 > float64(days) {
			removed++
		} else {
			kept = append(kept, e)
		}
	}
	history = kept
	saveHistory()
	fmt.Printf("Removed %d entries older than %d days.\n", removed, days)
}

func exportJSON(filename string) {
	data, _ := json.MarshalIndent(history, "", "  ")
	os.WriteFile(filename, data, 0644)
	fmt.Printf("Exported to %s\n", filename)
}

func exportCSV(filename string) {
	file, err := os.Create(filename)
	if err != nil {
		fmt.Println("Error creating file:", err)
		return
	}
	defer file.Close()
	writer := csv.NewWriter(file)
	defer writer.Flush()
	writer.Write([]string{"Text", "Category", "Timestamp", "Pinned", "UsageCount"})
	for _, e := range history {
		writer.Write([]string{e.Text, e.Category, e.Timestamp, strconv.FormatBool(e.Pinned), strconv.Itoa(e.UsageCount)})
	}
	fmt.Printf("Exported to %s\n", filename)
}

func importJSON(filename string) {
	data, err := os.ReadFile(filename)
	if err != nil {
		fmt.Println("File not found.")
		return
	}
	var imported []Entry
	if err := json.Unmarshal(data, &imported); err != nil {
		fmt.Println("Invalid JSON.")
		return
	}
	history = imported
	saveHistory()
	fmt.Printf("Imported %d entries from %s\n", len(history), filename)
}

func importCSV(filename string) {
	file, err := os.Open(filename)
	if err != nil {
		fmt.Println("File not found.")
		return
	}
	defer file.Close()
	reader := csv.NewReader(file)
	records, err := reader.ReadAll()
	if err != nil {
		fmt.Println("Error reading CSV:", err)
		return
	}
	if len(records) == 0 {
		fmt.Println("Empty CSV.")
		return
	}
	// assume header
	var imported []Entry
	for i, record := range records {
		if i == 0 {
			continue
		}
		if len(record) < 5 {
			continue
		}
		pinned, _ := strconv.ParseBool(record[3])
		usage, _ := strconv.Atoi(record[4])
		entry := Entry{
			Text:       record[0],
			Category:   record[1],
			Timestamp:  record[2],
			Pinned:     pinned,
			UsageCount: usage,
			ID:         time.Now().Unix() + int64(i),
			SourceApp:  "imported",
		}
		imported = append(imported, entry)
	}
	history = imported
	saveHistory()
	fmt.Printf("Imported %d entries from %s\n", len(history), filename)
}

func main() {
	loadHistory()
	last, _ := clipboard.ReadAll()
	lastClipboard = last

	// Monitor clipboard
	go func() {
		for running {
			text, err := clipboard.ReadAll()
			if err == nil && text != "" && text != lastClipboard {
				lastClipboard = text
				addEntry(text)
			}
			time.Sleep(500 * time.Millisecond)
		}
	}()

	scanner := bufio.NewScanner(os.Stdin)
	fmt.Println("=== Advanced Clipboard Manager ===")
	fmt.Println("Monitoring clipboard...")
	fmt.Println("Commands: 1=history, 2=add, 3=search, 4=paste, 5=delete, 6=pin, 7=category, 8=stats, 9=cleanup, 10=export, 11=import, 12=exit")

	for {
		fmt.Print("\n> ")
		if !scanner.Scan() {
			break
		}
		cmd := scanner.Text()
		switch cmd {
		case "1":
			showHistory()
		case "2":
			text, _ := clipboard.ReadAll()
			addEntry(text)
			fmt.Printf("Added: %s\n", truncate(text, 50))
		case "3":
			fmt.Print("Search query (regex supported: /pattern/i): ")
			scanner.Scan()
			query := scanner.Text()
			if query != "" {
				searchHistory(query)
			}
		case "4":
			fmt.Print("Enter index: ")
			scanner.Scan()
			idx, _ := strconv.Atoi(scanner.Text())
			pasteEntry(idx)
		case "5":
			fmt.Print("Enter index: ")
			scanner.Scan()
			idx, _ := strconv.Atoi(scanner.Text())
			deleteEntry(idx)
		case "6":
			fmt.Print("Enter index: ")
			scanner.Scan()
			idx, _ := strconv.Atoi(scanner.Text())
			togglePin(idx)
		case "7":
			fmt.Print("Enter index: ")
			scanner.Scan()
			idx, _ := strconv.Atoi(scanner.Text())
			if idx < 1 || idx > len(history) {
				fmt.Println("Invalid index.")
				continue
			}
			fmt.Print("Enter category (code/link/note/quote/other): ")
			scanner.Scan()
			cat := scanner.Text()
			if cat == "" {
				cat = defaultCategory
			}
			setCategory(idx, cat)
		case "8":
			showStats()
		case "9":
			fmt.Print("Remove entries older than N days: ")
			scanner.Scan()
			days, _ := strconv.Atoi(scanner.Text())
			cleanup(days)
		case "10":
			fmt.Print("Export format (json/csv): ")
			scanner.Scan()
			fmtF := scanner.Text()
			fmt.Print("Filename (default: export." + fmtF + "): ")
			scanner.Scan()
			fname := scanner.Text()
			if fname == "" {
				fname = "export." + fmtF
			}
			if fmtF == "json" {
				exportJSON(fname)
			} else if fmtF == "csv" {
				exportCSV(fname)
			} else {
				fmt.Println("Unknown format.")
			}
		case "11":
			fmt.Print("Import format (json/csv): ")
			scanner.Scan()
			fmtF := scanner.Text()
			fmt.Print("Filename: ")
			scanner.Scan()
			fname := scanner.Text()
			if fname == "" {
				fmt.Println("Filename required.")
				continue
			}
			if fmtF == "json" {
				importJSON(fname)
			} else if fmtF == "csv" {
				importCSV(fname)
			} else {
				fmt.Println("Unknown format.")
			}
		case "12":
			fmt.Println("Goodbye!")
			running = false
			return
		default:
			fmt.Println("Invalid command.")
		}
	}
}
