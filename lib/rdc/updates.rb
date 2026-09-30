# frozen_string_literal: true
require_relative "fetcher"
require "rubygems/version"

module Rdc
  module Updates
    module_function

    def latest(tags, language)
      pattern = Regexp.new(language.tag_pattern)
      tags.filter_map do |tag|
        match = pattern.match(tag)
        next unless match && !match.captures.empty?
        [match.captures.map(&:to_i), tag]
      end.max_by(&:first)
    end

    def detect(manifest)
      manifest.languages.filter_map do |language|
        next unless language.tag_pattern
        output = Fetcher.capture!("git", "ls-remote", "--tags", "--refs", language.repo)
        tags = output.lines.map { |line| line.split.last.delete_prefix("refs/tags/") }
        candidate = latest(tags, language)
        next unless candidate
        known = latest(language.versions.map(&:ref), language)
        next if known && (candidate.first <=> known.first) <= 0
        [language, candidate.first.join("."), candidate.last]
      end
    end

    def write(manifest, updates)
      data = YAML.safe_load_file(manifest.path, aliases: false)
      updates.each do |language, id, ref|
        versions = data.fetch("languages").fetch(language.id).fetch("versions")
        versions.each { |version| version.delete("default") }
        versions.unshift({ "id" => id, "ref" => ref, "default" => true })
      end
      Rdc.write(manifest.path, YAML.dump(data)) unless updates.empty?
    end
  end
end
