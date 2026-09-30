# frozen_string_literal: true
require "optparse"
require_relative "generator"
require_relative "updates"

module Rdc
  module CLI
    USAGE = "rdc {fetch|ir|build|serve|diff|check-updates|new-lang|doctor} [language[@version]] [options]"
    module_function

    def start(arguments)
      arguments = arguments.dup
      command = arguments.shift
      options = { out: "dist", port: 8000, format: "md" }
      parser = OptionParser.new do |o|
        o.banner = USAGE
        o.on("--out DIR") { |v| options[:out] = v }
        o.on("--port N", Integer) { |v| options[:port] = v }
        o.on("--only LANG") { |v| options[:only] = v }
        o.on("--format FORMAT", %w[md json]) { |v| options[:format] = v }
        o.on("--write-manifest") { options[:write] = true }
        o.on("--summary FILE") { |v| options[:summary] = v }
        o.on("--help") { puts o; return }
      end
      parser.parse!(arguments)
      return puts(parser) if !command || %w[help --help -h].include?(command)
      return doctor if command == "doctor"
      return new_language(arguments.fetch(0)) if command == "new-lang"
      return serve(options) if command == "serve"
      manifest = Manifest.load
      case command
      when "fetch", "ir"
        manifest.each_version(arguments.first) do |language, version|
          if command == "ir"
            Generator.generate(language, version, manifest.meta(language))
          else
            result = Fetcher.new.fetch(language, version)
            puts "#{language.id}@#{version.id}: #{version.ref} #{result.commit[0, 7]}"
          end
        end
      when "build"
        require_relative "site/builder"
        Site::Builder.new(manifest, out: options[:out], filter: options[:only] || arguments.first).build
      when "diff"
        require_relative "ir/diff"
        language = manifest.languages.find { |entry| entry.id == arguments.fetch(0) }
        raise ArgumentError, "unknown language" unless language
        versions = arguments[1, 2].map { |id| language.versions.find { |version| version.id == id } }
        raise ArgumentError, "diff needs known FROM and TO versions" unless versions.size == 2 && versions.all?
        irs = versions.map { |version| Generator.load(language, version, manifest.meta(language)) }
        result = IR::Diff.compare(*irs, epsilon_rules: Array(manifest.meta(language)["epsilon_rules"]))
        puts options[:format] == "json" ? JSON.pretty_generate(result) : diff_summary(result)
      when "check-updates"
        updates = Updates.detect(manifest)
        Updates.write(manifest, updates) if options[:write]
        summary = updates.map { |language, id, ref| "- #{language.name} #{id} (`#{ref}`)" }.join("\n")
        summary = "No new stable grammar versions." if updates.empty?
        puts summary
        Rdc.write(options[:summary], "# Grammar updates\n\n#{summary}\n") if options[:summary]
        File.open(ENV["GITHUB_OUTPUT"], "a") { |file| file.puts "updated=#{!updates.empty?}" } if ENV["GITHUB_OUTPUT"]
      else
        raise ArgumentError, USAGE
      end
    rescue OptionParser::ParseError, ArgumentError, KeyError, RuntimeError => error
      warn error.message
      exit 1
    end

    def diff_summary(result)
      "## #{result['language']} #{result['from']} → #{result['to']}\n\n" \
        "Rules: +#{result['added'].size} / −#{result['removed'].size} / #{result['changed'].size} changed.\n\n" \
        "Added terminals: #{result.dig('terminals', 'added').join(', ')}\n" \
        "Removed terminals: #{result.dig('terminals', 'removed').join(', ')}\n"
    end

    def doctor
      require "lrama"
      puts "Ruby #{RUBY_VERSION}\n#{Fetcher.capture!('git', '--version').strip}\nLrama #{::Lrama::VERSION} (#{LRAMA_REVISION[0, 7]})\nrdc #{VERSION}"
    end

    def serve(options)
      raise ArgumentError, "port must be 1–65535" unless (1..65_535).cover?(options[:port])
      require "webrick"
      root = File.expand_path(options[:out])
      raise ArgumentError, "build #{root} first" unless File.file?(File.join(root, "index.html"))
      server = WEBrick::HTTPServer.new(Port: options[:port], BindAddress: "127.0.0.1", DocumentRoot: root)
      trap("INT") { server.shutdown }
      trap("TERM") { server.shutdown }
      server.start
    end

    def new_language(id)
      raise ArgumentError, "invalid language id" unless /\A[a-z][a-z0-9_-]*\z/.match?(id)
      manifest = YAML.safe_load_file(Manifest::PATH, aliases: false)
      raise ArgumentError, "language already exists: #{id}" if manifest.fetch("languages").key?(id)
      manifest["languages"][id] = { "name" => id.capitalize, "frontend" => "lrama", "repo" => "REPLACE_WITH_UPSTREAM_REPOSITORY",
                                   "grammar" => "parse.y", "sparse" => ["/parse.y"], "notes" => ["parser_grammar"],
                                   "license" => { "name" => "VERIFY_LICENSE", "url" => "VERIFY_LICENSE_URL", "path" => "LICENSE" },
                                   "versions" => [{ "id" => "1.0", "ref" => "REPLACE_WITH_TAG", "default" => true }] }
      Rdc.write(Manifest::PATH, YAML.dump(manifest))
      Rdc.write(File.join(ROOT, "grammars", id, "meta.yml"), YAML.dump({ "description" => { "en" => "", "ja" => "" }, "token_display" => {}, "categories" => {} }))
      puts "Created #{id}; fill in the source, version and verified license before fetching."
    end
  end
end
