# frozen_string_literal: true
require_relative "manifest"
require "digest"
require "open3"
require "shellwords"
require "time"

module Rdc
  class Fetcher
    CACHE = File.join(ROOT, ".cache/src")
    LOCK = File.join(ROOT, "grammars/lock.yml")
    Result = Struct.new(:dir, :grammar_path, :commit, :sha256, :prepared_sha256, :committed_at, keyword_init: true)

    def self.capture!(*command, **options)
      stdout, stderr, status = Open3.capture3(*command, **options)
      raise "#{command.first(3).join(' ')} failed: #{stderr.strip}" unless status.success?
      stdout
    end

    def fetch(language, version)
      lock = File.exist?(LOCK) ? YAML.safe_load_file(LOCK, aliases: false) : {}
      previous = lock.dig(language.id, version.id)
      pinned = previous && previous["ref"] == version.ref ? previous["commit"] : nil
      directory = File.join(CACHE, language.id, version.id)
      checkout(language, version, directory, pinned)
      original = File.join(directory, language.grammar)
      checksum = Digest::SHA256.file(original).hexdigest
      if pinned && checksum != previous.fetch("sha256")
        raise "source hash mismatch: #{language.id}@#{version.id}; restore the cached checkout"
      end
      grammar = preprocess(language, directory, original)
      result = Result.new(dir: directory, grammar_path: grammar,
                          commit: self.class.capture!("git", "-C", directory, "rev-parse", "HEAD").strip,
                          sha256: checksum, prepared_sha256: Digest::SHA256.file(grammar).hexdigest,
                          committed_at: self.class.capture!("git", "-C", directory, "show", "-s", "--format=%cI", "HEAD").strip)
      record = { "ref" => version.ref, "commit" => result.commit, "sha256" => checksum,
                 "prepared_sha256" => result.prepared_sha256, "committed_at" => result.committed_at,
                 "fetched_at" => previous&.fetch("fetched_at", nil) || Time.now.utc.iso8601 }
      lock[language.id] ||= {}
      lock[language.id][version.id] = record
      Rdc.write(LOCK, YAML.dump(lock))
      result
    end

    private

    def checkout(language, version, directory, pinned)
      unless File.directory?(File.join(directory, ".git"))
        FileUtils.mkdir_p(directory)
        self.class.capture!("git", "init", "--quiet", directory)
        self.class.capture!("git", "-C", directory, "remote", "add", "origin", language.repo)
      end
      current = self.class.capture!("git", "-C", directory, "rev-parse", "--verify", "HEAD") rescue nil
      return if pinned && current&.strip == pinned
      target = pinned || version.ref
      self.class.capture!("git", "-C", directory, "fetch", "--quiet", "--depth", "1", "origin", target)
      paths = Array(language.sparse) + ["/#{language.grammar}", "/#{language.license.fetch('path')}"]
      self.class.capture!("git", "-C", directory, "sparse-checkout", "set", "--no-cone", *paths.uniq)
      self.class.capture!("git", "-c", "advice.detachedHead=false", "-C", directory, "checkout", "--quiet", "--detach", "FETCH_HEAD")
      commit = self.class.capture!("git", "-C", directory, "rev-parse", "HEAD").strip
      raise "locked commit not fetched: #{target}" if pinned && pinned != commit
    end

    def preprocess(language, directory, original)
      return original unless language.preprocess
      arguments = language.preprocess.is_a?(Array) ? language.preprocess : Shellwords.split(language.preprocess)
      arguments = arguments.map { |argument| argument.gsub("%{rdc_root}", ROOT) }
      output = File.join(directory, ".rdc/grammar.y")
      Rdc.write(output, self.class.capture!(*arguments, chdir: directory))
      output
    end
  end
end
