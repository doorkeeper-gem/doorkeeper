# frozen_string_literal: true

# Collects pending changelog entries from changelogs/*.md into the "## main"
# section of CHANGELOG.md and deletes the collected files.
#
# Entries are inserted, in file name order, directly above the
# "- Please add here" marker line — the same spot a hand-written entry
# would go. Prints the number of collected files to stdout so the calling
# workflow can tell whether anything changed, and aborts rather than
# quietly dropping an entry it cannot place.

CHANGELOG = "CHANGELOG.md"
ENTRIES_DIR = "changelogs"
MARKER = "- Please add here"

entry_files = Dir[File.join(ENTRIES_DIR, "*.md")]
  .reject { |path| File.basename(path) == "README.md" }
  .sort

if entry_files.empty?
  puts 0
  exit
end

entries = entry_files.map do |path|
  entry = File.read(path).strip
  abort "#{path}: entry file is empty" if entry.empty?

  entry
end

lines = File.readlines(CHANGELOG)

main_index = lines.index { |line| line.chomp == "## main" }
abort "#{CHANGELOG}: '## main' section not found" unless main_index

section = lines[main_index..]
marker_offset = section.index { |line| line.chomp == MARKER }
abort "#{CHANGELOG}: '#{MARKER}' marker not found" unless marker_offset
if (next_section = section.index { |line| line.start_with?("## ") && line.chomp != "## main" }) && next_section < marker_offset
  abort "#{CHANGELOG}: '#{MARKER}' marker not found in the '## main' section"
end

lines.insert(main_index + marker_offset, *entries.map { |entry| "#{entry}\n" })
File.write(CHANGELOG, lines.join)

entry_files.each { |path| File.delete(path) }

puts entry_files.size
