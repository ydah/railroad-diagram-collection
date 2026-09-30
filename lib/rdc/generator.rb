# frozen_string_literal: true
require_relative "fetcher"

module Rdc
  module Generator
    module_function

    def path(language, version) = File.join(ROOT, "data", language.id, "#{version.id}.json")
    def metadata_hash(language, meta)
      require "digest"
      Digest::SHA256.hexdigest(JSON.generate([language.start, language.options, language.preprocess, language.license, meta]))
    end

    def generate(language, version, meta = {})
      require "lrama"
      require_relative "ir/schema"
      fetched = Fetcher.new.fetch(language, version)
      file = language.frontend
      require_relative "frontends/#{file}"
      frontend = { "lrama" => :Lrama, "bison_report" => :BisonReport, "antlr4" => :Antlr4,
                   "ebnf" => :Ebnf, "peg" => :Peg }.fetch(file)
      adapter = Frontends.const_get(frontend).new
      parsed = adapter.parse(File.read(fetched.grammar_path, encoding: "UTF-8"),
                             path: language.grammar, meta: meta.merge(language.options || {}))
      ir = {
        "schema" => 1, "language" => language.id, "version" => version.id,
        "source" => { "repo" => language.repo, "ref" => version.ref, "commit" => fetched.commit,
                      "path" => language.grammar, "sha256" => fetched.sha256, "prepared_sha256" => fetched.prepared_sha256,
                      "committed_at" => fetched.committed_at, "license" => language.license },
        "generator" => { "frontend" => file, "tool_version" => adapter.tool_version,
                         "lrama_revision" => LRAMA_REVISION, "rdc" => VERSION, "metadata_sha256" => metadata_hash(language, meta) },
        "start" => language.start || parsed.fetch("start"), "terminals" => parsed.fetch("terminals"),
        "rules" => parsed.fetch("rules")
      }
      IR::Schema.validate!(ir)
      Rdc.write(path(language, version), JSON.pretty_generate(ir) + "\n")
      puts "IR #{language.id}@#{version.id}: #{ir['rules'].size} rules, #{ir['terminals'].size} terminals"
      ir
    end

    def load(language, version, meta = {})
      file = path(language, version)
      return generate(language, version, meta) unless File.file?(file)
      require_relative "ir/schema"
      ir = JSON.parse(File.read(file, encoding: "UTF-8"))
      unless ir.dig("source", "repo") == language.repo && ir.dig("source", "ref") == version.ref &&
             ir.dig("source", "path") == language.grammar && ir.dig("generator", "frontend") == language.frontend &&
             ir.dig("generator", "lrama_revision") == LRAMA_REVISION && ir.dig("generator", "rdc") == VERSION &&
             ir.dig("generator", "metadata_sha256") == metadata_hash(language, meta)
        return generate(language, version, meta)
      end
      lock = YAML.safe_load_file(Fetcher::LOCK, aliases: false).dig(language.id, version.id)
      unless lock && lock["commit"] == ir.dig("source", "commit") && lock["sha256"] == ir.dig("source", "sha256") &&
             lock["prepared_sha256"] == ir.dig("source", "prepared_sha256")
        raise "#{file}: IR differs from grammars/lock.yml; run rdc ir #{language.id}@#{version.id}"
      end
      IR::Schema.validate!(ir)
      ir
    end
  end
end
