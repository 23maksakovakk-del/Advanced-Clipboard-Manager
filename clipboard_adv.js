// clipboard_adv.js
const clipboardy = require('clipboardy');
const fs = require('fs');
const readline = require('readline');

const HISTORY_FILE = 'clipboard_adv_history.json';
const MAX_HISTORY = 200;
const DEFAULT_CATEGORY = 'other';

let history = [];
let lastClipboard = '';
let running = true;

function loadHistory() {
    try {
        const data = fs.readFileSync(HISTORY_FILE, 'utf8');
        history = JSON.parse(data);
    } catch (e) {
        history = [];
    }
}

function saveHistory() {
    fs.writeFileSync(HISTORY_FILE, JSON.stringify(history, null, 2));
}

function addEntry(text) {
    if (!text || text.trim() === '') return;
    if (history.length > 0 && history[0].text === text) return;
    const entry = {
        id: Date.now(),
        text: text,
        timestamp: new Date().toISOString(),
        category: DEFAULT_CATEGORY,
        pinned: false,
        source_app: 'unknown',
        usage_count: 0
    };
    history.unshift(entry);
    if (history.length > MAX_HISTORY) {
        // Remove oldest non-pinned
        for (let i = history.length - 1; i >= 0; i--) {
            if (!history[i].pinned) {
                history.splice(i, 1);
                break;
            }
        }
        if (history.length > MAX_HISTORY) history.pop();
    }
    saveHistory();
}

function truncate(s, n) {
    return s.length > n ? s.slice(0, n) + '...' : s;
}

function showHistory() {
    if (history.length === 0) {
        console.log('History is empty.');
        return;
    }
    history.forEach((e, i) => {
        const pin = e.pinned ? '★ ' : '';
        console.log(`[${i+1}] ${pin}${e.category}: ${truncate(e.text, 50)}  (${e.timestamp})  [used: ${e.usage_count}]`);
    });
}

function searchHistory(query) {
    let isRegex = false, caseSensitive = true, pattern = query;
    if (query.startsWith('/') && (query.endsWith('/') || query.endsWith('/i'))) {
        isRegex = true;
        if (query.endsWith('/i')) {
            pattern = query.slice(1, -2);
            caseSensitive = false;
        } else {
            pattern = query.slice(1, -1);
            caseSensitive = true;
        }
    }
    let results = [];
    for (const e of history) {
        if (isRegex) {
            try {
                const flags = caseSensitive ? '' : 'i';
                const re = new RegExp(pattern, flags);
                if (re.test(e.text)) results.push(e);
            } catch (err) {
                console.log('Invalid regex.');
                return;
            }
        } else {
            if (e.text.toLowerCase().includes(query.toLowerCase())) results.push(e);
        }
    }
    if (results.length === 0) {
        console.log('No matches found.');
        return;
    }
    results.forEach((e, i) => {
        const pin = e.pinned ? '★ ' : '';
        console.log(`[${i+1}] ${pin}${e.category}: ${truncate(e.text, 50)}  (${e.timestamp})  [used: ${e.usage_count}]`);
    });
}

function pasteEntry(index) {
    if (index < 1 || index > history.length) {
        console.log('Invalid index.');
        return;
    }
    const e = history[index-1];
    clipboardy.writeSync(e.text);
    e.usage_count = (e.usage_count || 0) + 1;
    saveHistory();
    console.log(`Copied to clipboard: ${truncate(e.text, 50)}`);
}

function deleteEntry(index) {
    if (index < 1 || index > history.length) {
        console.log('Invalid index.');
        return;
    }
    const removed = history.splice(index-1, 1)[0];
    saveHistory();
    console.log(`Deleted: ${truncate(removed.text, 50)}`);
}

function togglePin(index) {
    if (index < 1 || index > history.length) {
        console.log('Invalid index.');
        return;
    }
    const e = history[index-1];
    e.pinned = !e.pinned;
    saveHistory();
    console.log(`Entry ${e.pinned ? 'pinned' : 'unpinned'}: ${truncate(e.text, 50)}`);
}

function setCategory(index, category) {
    if (index < 1 || index > history.length) {
        console.log('Invalid index.');
        return;
    }
    const e = history[index-1];
    e.category = category;
    saveHistory();
    console.log(`Category updated: ${truncate(e.text, 50)} -> ${category}`);
}

function showStats() {
    const total = history.length;
    if (total === 0) {
        console.log('No entries.');
        return;
    }
    const categories = {};
    let pinnedCount = 0, totalUsage = 0, mostUsed = 0;
    const ages = [];
    const now = new Date();
    for (const e of history) {
        categories[e.category] = (categories[e.category] || 0) + 1;
        if (e.pinned) pinnedCount++;
        totalUsage += (e.usage_count || 0);
        if ((e.usage_count || 0) > mostUsed) mostUsed = e.usage_count || 0;
        try {
            const ts = new Date(e.timestamp);
            const days = (now - ts) / (1000 * 60 * 60 * 24);
            ages.push(days);
        } catch (e) {}
    }
    const avgAge = ages.reduce((a,b) => a+b, 0) / ages.length || 0;
    console.log('Statistics:');
    console.log(`  Total entries: ${total}`);
    console.log(`  Pinned: ${pinnedCount}`);
    console.log(`  Categories: ${Object.entries(categories).map(([k,v]) => `${k}:${v}`).join(', ')}`);
    console.log(`  Most used count: ${mostUsed}`);
    console.log(`  Total usage: ${totalUsage}`);
    console.log(`  Average age: ${avgAge.toFixed(1)} days`);
}

function cleanup(days) {
    if (days <= 0) {
        console.log('Days must be positive.');
        return;
    }
    const now = new Date();
    let removed = 0;
    const kept = [];
    for (const e of history) {
        if (e.pinned) {
            kept.push(e);
            continue;
        }
        try {
            const ts = new Date(e.timestamp);
            if ((now - ts) / (1000 * 60 * 60 * 24) > days) {
                removed++;
            } else {
                kept.push(e);
            }
        } catch (e) {
            kept.push(e);
        }
    }
    history = kept;
    saveHistory();
    console.log(`Removed ${removed} entries older than ${days} days.`);
}

function exportJSON(filename) {
    fs.writeFileSync(filename, JSON.stringify(history, null, 2));
    console.log(`Exported to ${filename}`);
}

function exportCSV(filename) {
    const lines = ['Text,Category,Timestamp,Pinned,UsageCount'];
    for (const e of history) {
        lines.push(`"${e.text}","${e.category}","${e.timestamp}",${e.pinned},${e.usage_count || 0}`);
    }
    fs.writeFileSync(filename, lines.join('\n'));
    console.log(`Exported to ${filename}`);
}

function importJSON(filename) {
    try {
        const data = fs.readFileSync(filename, 'utf8');
        const imported = JSON.parse(data);
        if (Array.isArray(imported)) {
            history = imported;
            saveHistory();
            console.log(`Imported ${history.length} entries from ${filename}`);
        } else {
            console.log('Invalid format.');
        }
    } catch (e) {
        console.log('File not found or invalid JSON.');
    }
}

function importCSV(filename) {
    try {
        const data = fs.readFileSync(filename, 'utf8');
        const lines = data.split('\n').filter(l => l.trim());
        if (lines.length < 2) {
            console.log('Empty or invalid CSV.');
            return;
        }
        const header = lines[0].split(',').map(h => h.trim());
        const imported = [];
        for (let i = 1; i < lines.length; i++) {
            const parts = lines[i].match(/(".*?"|[^,]+)(?=\s*,|\s*$)/g).map(p => p.trim().replace(/^"|"$/g, ''));
            if (parts.length < 5) continue;
            const entry = {
                text: parts[0],
                category: parts[1] || DEFAULT_CATEGORY,
                timestamp: parts[2] || new Date().toISOString(),
                pinned: parts[3] === 'true',
                usage_count: parseInt(parts[4]) || 0,
                id: Date.now() + i,
                source_app: 'imported'
            };
            imported.push(entry);
        }
        history = imported;
        saveHistory();
        console.log(`Imported ${history.length} entries from ${filename}`);
    } catch (e) {
        console.log('Error importing CSV:', e.message);
    }
}

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

function ask(question) {
    return new Promise(resolve => rl.question(question, resolve));
}

async function main() {
    loadHistory();
    lastClipboard = await clipboardy.read();

    // Monitor clipboard
    setInterval(async () => {
        try {
            const current = await clipboardy.read();
            if (current && current !== lastClipboard) {
                lastClipboard = current;
                addEntry(current);
            }
        } catch (e) {}
    }, 500);

    console.log('=== Advanced Clipboard Manager ===');
    console.log('Monitoring clipboard...');
    console.log('Commands: 1=history, 2=add, 3=search, 4=paste, 5=delete, 6=pin, 7=category, 8=stats, 9=cleanup, 10=export, 11=import, 12=exit');

    while (true) {
        const cmd = await ask('\n> ');
        switch (cmd.trim()) {
            case '1': showHistory(); break;
            case '2':
                const text = await clipboardy.read();
                addEntry(text);
                console.log(`Added: ${truncate(text, 50)}`);
                break;
            case '3': {
                const query = await ask('Search query (regex supported: /pattern/i): ');
                if (query) searchHistory(query);
                break;
            }
            case '4': {
                const idxStr = await ask('Enter index: ');
                const idx = parseInt(idxStr);
                if (!isNaN(idx)) pasteEntry(idx);
                break;
            }
            case '5': {
                const idxStr = await ask('Enter index: ');
                const idx = parseInt(idxStr);
                if (!isNaN(idx)) deleteEntry(idx);
                break;
            }
            case '6': {
                const idxStr = await ask('Enter index: ');
                const idx = parseInt(idxStr);
                if (!isNaN(idx)) togglePin(idx);
                break;
            }
            case '7': {
                const idxStr = await ask('Enter index: ');
                const idx = parseInt(idxStr);
                if (!isNaN(idx)) {
                    const cat = await ask('Enter category (code/link/note/quote/other): ');
                    setCategory(idx, cat || DEFAULT_CATEGORY);
                }
                break;
            }
            case '8': showStats(); break;
            case '9': {
                const daysStr = await ask('Remove entries older than N days: ');
                const days = parseInt(daysStr);
                if (!isNaN(days)) cleanup(days);
                break;
            }
            case '10': {
                const fmt = await ask('Export format (json/csv): ');
                let fname = await ask('Filename (default: export.' + fmt + '): ');
                if (!fname.trim()) fname = 'export.' + fmt;
                if (fmt === 'json') exportJSON(fname);
                else if (fmt === 'csv') exportCSV(fname);
                else console.log('Unknown format.');
                break;
            }
            case '11': {
                const fmt = await ask('Import format (json/csv): ');
                const fname = await ask('Filename: ');
                if (!fname.trim()) { console.log('Filename required.'); break; }
                if (fmt === 'json') importJSON(fname);
                else if (fmt === 'csv') importCSV(fname);
                else console.log('Unknown format.');
                break;
            }
            case '12':
                console.log('Goodbye!');
                rl.close();
                return;
            default:
                console.log('Invalid command.');
        }
    }
}

main().catch(console.error);
