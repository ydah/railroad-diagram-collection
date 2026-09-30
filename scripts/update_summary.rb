#!/usr/bin/env ruby
# frozen_string_literal: true
require_relative "../lib/rdc/cli"
require_relative "../lib/rdc/ir/diff"
manifest = Rdc::Manifest.load
path = ARGV.fetch(0)
summary = File.read(path, encoding: "UTF-8")
updates = summary.lines.grep(/\A- /)
manifest.languages.each do |language|
  next unless updates.any? { |line| line.start_with?("- #{language.name} ") }
  versions = language.versions.sort_by { |version| Gem::Version.new(version.id) }
  next unless versions.size > 1
  irs = versions.last(2).map { |version| Rdc::Generator.load(language, version, manifest.meta(language)) }
  diff = Rdc::IR::Diff.compare(*irs, epsilon_rules: Array(manifest.meta(language)["epsilon_rules"]))
  summary << "\n" << Rdc::CLI.diff_summary(diff)
end
Rdc.write(path, summary)
