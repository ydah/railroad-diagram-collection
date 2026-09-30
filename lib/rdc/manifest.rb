# frozen_string_literal: true
require_relative "../rdc"
require "pathname"

module Rdc
  Version = Struct.new(:id, :ref, :default, keyword_init: true)
  Language = Struct.new(:id, :name, :frontend, :repo, :grammar, :sparse, :preprocess, :start,
                        :tag_pattern, :notes, :license, :versions, :options, keyword_init: true)

  class Manifest
    PATH = File.join(ROOT, "grammars/manifest.yml")
    FRONTENDS = %w[lrama bison_report antlr4 ebnf peg].freeze
    attr_reader :languages, :path

    def self.load(path = PATH)
      data = YAML.safe_load_file(path, permitted_classes: [], aliases: false)
      raise ArgumentError, "unsupported manifest schema" unless data.is_a?(Hash) && data["schema"] == 1
      entries = data.fetch("languages")
      raise ArgumentError, "languages must be a nonempty mapping" unless entries.is_a?(Hash) && !entries.empty?
      languages = entries.map do |id, entry|
        raise ArgumentError, "invalid language id: #{id}" unless /\A[a-z][a-z0-9_-]*\z/.match?(id.to_s)
        %w[name frontend repo grammar license versions].each { |key| entry.fetch(key) }
        raise ArgumentError, "unknown frontend: #{entry['frontend']}" unless FRONTENDS.include?(entry["frontend"])
        grammar = Pathname.new(entry.fetch("grammar"))
        raise ArgumentError, "grammar must be a relative source path" if grammar.absolute? || grammar.each_filename.include?("..")
        license = entry.fetch("license")
        %w[name url path].each { |key| license.fetch(key) }
        versions = entry.fetch("versions").map do |v|
          version = v.fetch("id")
          ref = v.fetch("ref")
          unless version.is_a?(String) && /\A[A-Za-z0-9][A-Za-z0-9_.-]*\z/.match?(version) && !version.include?("..")
            raise ArgumentError, "invalid version id: #{version.inspect}"
          end
          raise ArgumentError, "invalid ref" unless ref.is_a?(String) && !ref.empty? && !ref.start_with?("-")
          Version.new(id: version, ref: ref, default: v["default"] == true)
        end
        raise ArgumentError, "duplicate version in #{id}" unless versions.map(&:id).uniq.size == versions.size
        raise ArgumentError, "#{id} needs exactly one default version" unless versions.count(&:default) == 1
        Language.new(id: id, **entry.except("versions").transform_keys(&:to_sym), versions: versions)
      end
      new(languages, path)
    end

    def initialize(languages, path = PATH)
      @languages, @path = languages, path
    end

    def each_version(filter = nil)
      return enum_for(__method__, filter) unless block_given?
      language_id, version_id = filter&.split("@", 2)
      selected = languages.select { |language| !language_id || language.id == language_id }
      raise ArgumentError, "unknown language: #{language_id}" if selected.empty?
      count = 0
      selected.each do |language|
        language.versions.each do |version|
          next if version_id && version.id != version_id
          count += 1
          yield language, version
        end
      end
      raise ArgumentError, "unknown version: #{filter}" if count.zero?
    end

    def meta(language)
      file = File.join(ROOT, "grammars", language.id, "meta.yml")
      File.exist?(file) ? YAML.safe_load_file(file, aliases: false) : {}
    end
  end
end
