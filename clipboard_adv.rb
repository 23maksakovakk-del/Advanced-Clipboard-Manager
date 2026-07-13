# clipboard_adv.rb
require 'json'
require 'time'
require 'thread'

begin
  require 'clipboard'
rescue LoadError
  puts "Please install: gem install clipboard"
  exit(1)
end

HISTORY_FILE = 'clipboard_adv_history.json'
MAX_HISTORY = 200
DEFAULT_CATEGORY = 'other'
$history = []
$last_clipboard = ''
$running = true

def load_history
  $history = JSON.parse(File.read(HISTORY_FILE)) rescue []
end

def save_history
  File.write(HISTORY_FILE, JSON.pretty_generate($history))
end

def add_entry(text)
  return if text.nil? || text.strip.empty?
  return if $history.first && $history.first['text'] == text
  entry = {
    'id' => Time.now.to_i,
    'text' => text,
    'timestamp' => Time.now.iso8601,
    'category' => DEFAULT_CATEGORY,
    'pinned' => false,
    'source_app' => 'unknown',
    'usage_count' => 0
  }
  $history.unshift(entry)
  if $history.size > MAX_HISTORY
    # remove oldest non-pinned
    $history.each_with_index do |e, i|
      next if i == 0
      unless e['pinned']
        $history.delete_at(i)
        break
      end
    end
    $history.pop if $history.size > MAX_HISTORY
  end
  save_history
end

def truncate(s, n)
  s.length > n ? s[0...n] + '...' : s
end

def show_history
  if $history.empty?
    puts 'History is empty.'
    return
  end
  $history.each_with_index do |e, i|
    pin = e['pinned'] ? '★ ' : ''
    puts "[#{i+1}] #{pin}#{e['category']}: #{truncate(e['text'], 50)}  (#{e['timestamp']})  [used: #{e['usage_count']}]"
  end
end

def search_history(query)
  is_regex = false
  case_sensitive = true
  pattern = query
  if query.start_with?('/') && (query.end_with?('/') || query.end_with?('/i'))
    is_regex = true
    if query.end_with?('/i')
      pattern = query[1...-2]
      case_sensitive = false
    else
      pattern = query[1...-1]
      case_sensitive = true
    end
  end
  results = []
  $history.each do |e|
    if is_regex
      begin
        flags = case_sensitive ? 0 : Regexp::IGNORECASE
        if Regexp.new(pattern, flags) =~ e['text']
          results << e
        end
      rescue => ex
        puts "Invalid regex."
        return
      end
    else
      if e['text'].downcase.include?(query.downcase)
        results << e
      end
    end
  end
  if results.empty?
    puts 'No matches found.'
    return
  end
  results.each_with_index do |e, i|
    pin = e['pinned'] ? '★ ' : ''
    puts "[#{i+1}] #{pin}#{e['category']}: #{truncate(e['text'], 50)}  (#{e['timestamp']})  [used: #{e['usage_count']}]"
  end
end

def paste_entry(index)
  if index < 1 || index > $history.size
    puts 'Invalid index.'
    return
  end
  e = $history[index-1]
  Clipboard.copy(e['text'])
  e['usage_count'] += 1
  save_history
  puts "Copied to clipboard: #{truncate(e['text'], 50)}"
end

def delete_entry(index)
  if index < 1 || index > $history.size
    puts 'Invalid index.'
    return
  end
  removed = $history.delete_at(index-1)
  save_history
  puts "Deleted: #{truncate(removed['text'], 50)}"
end

def toggle_pin(index)
  if index < 1 || index > $history.size
    puts 'Invalid index.'
    return
  end
  e = $history[index-1]
  e['pinned'] = !e['pinned']
  save_history
  status = e['pinned'] ? 'pinned' : 'unpinned'
  puts "Entry #{status}: #{truncate(e['text'], 50)}"
end

def set_category(index, category)
  if index < 1 || index > $history.size
    puts 'Invalid index.'
    return
  end
  e = $history[index-1]
  e['category'] = category
  save_history
  puts "Category updated: #{truncate(e['text'], 50)} -> #{category}"
end

def show_stats
  total = $history.size
  if total == 0
    puts 'No entries.'
    return
  end
  categories = {}
  pinned_count = 0
  total_usage = 0
  most_used = 0
  ages = []
  now = Time.now
  $history.each do |e|
    categories[e['category']] = categories.fetch(e['category'], 0) + 1
    pinned_count += 1 if e['pinned']
    total_usage += e['usage_count']
    most_used = e['usage_count'] if e['usage_count'] > most_used
    begin
      ts = Time.parse(e['timestamp'])
      ages << (now - ts) / (60 * 60 * 24)
    rescue
    end
  end
  avg_age = ages.empty? ? 0 : ages.sum / ages.size
  puts 'Statistics:'
  puts "  Total entries: #{total}"
  puts "  Pinned: #{pinned_count}"
  puts "  Categories: #{categories.map { |k,v| "#{k}:#{v}" }.join(', ')}"
  puts "  Most used count: #{most_used}"
  puts "  Total usage: #{total_usage}"
  puts "  Average age: #{'%.1f' % avg_age} days"
end

def cleanup(days)
  if days <= 0
    puts 'Days must be positive.'
    return
  end
  now = Time.now
  removed = 0
  kept = []
  $history.each do |e|
    if e['pinned']
      kept << e
      next
    end
    begin
      ts = Time.parse(e['timestamp'])
      if (now - ts) / (60 * 60 * 24) > days
        removed += 1
      else
        kept << e
      end
    rescue
      kept << e
    end
  end
  $history = kept
  save_history
  puts "Removed #{removed} entries older than #{days} days."
end

def export_json(filename)
  File.write(filename, JSON.pretty_generate($history))
  puts "Exported to #{filename}"
end

def export_csv(filename)
  CSV.open(filename, 'w') do |csv|
    csv << ['Text', 'Category', 'Timestamp', 'Pinned', 'UsageCount']
    $history.each do |e|
      csv << [e['text'], e['category'], e['timestamp'], e['pinned'], e['usage_count']]
    end
  end
  puts "Exported to #{filename}"
end

def import_json(filename)
  data = JSON.parse(File.read(filename))
  if data.is_a?(Array)
    $history = data
    save_history
    puts "Imported #{$history.size} entries from #{filename}"
  else
    puts 'Invalid format.'
  end
rescue => e
  puts "Error: #{e.message}"
end

def import_csv(filename)
  require 'csv'
  imported = []
  CSV.foreach(filename, headers: true) do |row|
    entry = {
      'text' => row['Text'],
      'category' => row['Category'] || DEFAULT_CATEGORY,
      'timestamp' => row['Timestamp'] || Time.now.iso8601,
      'pinned' => row['Pinned'] == 'true',
      'usage_count' => row['UsageCount'].to_i,
      'id' => Time.now.to_i + imported.size,
      'source_app' => 'imported'
    }
    imported << entry
  end
  $history = imported
  save_history
  puts "Imported #{$history.size} entries from #{filename}"
rescue => e
  puts "Error: #{e.message}"
end

def main
  load_history
  $last_clipboard = Clipboard.paste

  Thread.new do
    while $running
      begin
        current = Clipboard.paste
        if current && current != $last_clipboard && !current.empty?
          $last_clipboard = current
          add_entry(current)
        end
        sleep 0.5
      rescue
      end
    end
  end

  puts "=== Advanced Clipboard Manager ==="
  puts "Monitoring clipboard..."
  puts "Commands: 1=history, 2=add, 3=search, 4=paste, 5=delete, 6=pin, 7=category, 8=stats, 9=cleanup, 10=export, 11=import, 12=exit"

  loop do
    print "\n> "
    cmd = gets.chomp.strip
    case cmd
    when '1'
      show_history
    when '2'
      text = Clipboard.paste
      add_entry(text)
      puts "Added: #{truncate(text, 50)}"
    when '3'
      print 'Search query (regex supported: /pattern/i): '
      query = gets.chomp.strip
      search_history(query) unless query.empty?
    when '4'
      print 'Enter index: '
      idx = gets.to_i
      paste_entry(idx)
    when '5'
      print 'Enter index: '
      idx = gets.to_i
      delete_entry(idx)
    when '6'
      print 'Enter index: '
      idx = gets.to_i
      toggle_pin(idx)
    when '7'
      print 'Enter index: '
      idx = gets.to_i
      print 'Enter category (code/link/note/quote/other): '
      cat = gets.chomp.strip
      cat = DEFAULT_CATEGORY if cat.empty?
      set_category(idx, cat)
    when '8'
      show_stats
    when '9'
      print 'Remove entries older than N days: '
      days = gets.to_i
      cleanup(days)
    when '10'
      print 'Export format (json/csv): '
      fmt = gets.chomp.strip.downcase
      print "Filename (default: export.#{fmt}): "
      fname = gets.chomp.strip
      fname = "export.#{fmt}" if fname.empty?
      if fmt == 'json'
        export_json(fname)
      elsif fmt == 'csv'
        export_csv(fname)
      else
        puts 'Unknown format.'
      end
    when '11'
      print 'Import format (json/csv): '
      fmt = gets.chomp.strip.downcase
      print 'Filename: '
      fname = gets.chomp.strip
      if fname.empty?
        puts 'Filename required.'
        next
      end
      if fmt == 'json'
        import_json(fname)
      elsif fmt == 'csv'
        import_csv(fname)
      else
        puts 'Unknown format.'
      end
    when '12'
      puts 'Goodbye!'
      $running = false
      break
    else
      puts 'Invalid command.'
    end
  end
end

main if __FILE__ == $0
