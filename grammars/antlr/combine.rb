# frozen_string_literal: true
# Read both complete upstream files so token spellings and their license notices survive preprocessing.
abort 'usage: combine.rb parser.g4 lexer.g4' unless ARGV.length == 2
ARGV.each { |path| puts File.read(path, encoding: 'UTF-8') }
