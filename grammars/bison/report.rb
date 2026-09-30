# frozen_string_literal: true
require 'fileutils'
require 'json'
require 'open3'

path = ARGV.fetch(0)
# macOS ships Bison 2.3. Prefer a installed GNU Bison when the system tool is too old.
candidates = [ENV['BISON'], 'bison', '/opt/homebrew/opt/bison/bin/bison', '/usr/local/opt/bison/bin/bison'].compact
bison = candidates.find do |candidate|
  version, status = Open3.capture2(candidate, '--version')
  status.success? && version.match?(/GNU Bison\) (?:[3-9]|[1-9]\d)\./)
rescue Errno::ENOENT
  false
end
abort 'GNU Bison >= 3 is required (set BISON to its executable)' unless bison
version = Open3.capture2(bison, '--version').first.lines.first.strip
FileUtils.mkdir_p('.rdc')
out, error, status = Open3.capture3(bison, '-v', '-o', '.rdc/report.c', path)
abort "Bison failed: #{error}" unless status.success?
source = File.read(path, encoding: 'UTF-8')
aliases = {}
source.scan(/^%token\b(.*?)(?=^%|\z)/m).each do |block|
  declaration = block.first.gsub(/"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\/\*.*?\*\/|\/\/[^\n]*/m) { |part| part.start_with?('/') ? '' : part }
  current = nil
  declaration.scan(/"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|<[^>]*>|[A-Za-z_][A-Za-z0-9_]*/).each do |token|
    if token.start_with?('"')
      aliases[token] = current if current
    elsif token.match?(/\A[A-Za-z_]/)
      current = token
    end
  end
end
puts "RDC_METADATA #{JSON.generate({'bison' => version, 'aliases' => aliases})}"
# States are not needed for diagrams; retain the complete Grammar and terminal tables.
print File.read('.rdc/report.output', encoding: 'UTF-8').split(/^State \d+\s*$/, 2).first
