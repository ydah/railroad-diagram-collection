# frozen_string_literal: true
require_relative "../generator"
require_relative "../ir/analysis"
require_relative "../ir/simplify"
require_relative "../ir/diff"
require_relative "../render/svg"
require_relative "view"
require_relative "validator"

module Rdc
  module Site
    class Builder
      Page = Struct.new(:language, :version, :ir, :meta, :analysis, :simplified, :raw, :examples, :changes, keyword_init: true)
      attr_reader :pages, :translations, :assets

      def initialize(manifest, out: "dist", filter: nil)
        @manifest, @destination, @filter = manifest, File.expand_path(out), filter
        @pages, @assets = [], {}
        @translations = %w[en ja].to_h { |locale| [locale, YAML.safe_load_file(File.join(ROOT, "site/i18n", "#{locale}.yml"), aliases: false)] }
      end

      def build
        validate_destination!
        @out = File.join(ROOT, ".cache", "build-#{Process.pid}")
        FileUtils.mkdir_p(@out)
        prepare_assets
        @manifest.each_version(@filter) { |language, version| @pages << load_page(language, version) }
        prepare_changes
        write_api
        %w[en ja].each { |locale| build_locale(locale) }
        write_legacy_redirects
        write_sitemap
        Rdc.write(File.join(@out, "robots.txt"), "User-agent: *\nAllow: /\nSitemap: #{SITE_URL}/sitemap.xml\n")
        Rdc.write(File.join(@out, ".nojekyll"), "")
        Rdc.write(File.join(@out, ".rdc-site"), VERSION + "\n")
        Validator.check!(@out)
        FileUtils.rm_rf(@destination) if File.exist?(@destination)
        FileUtils.mkdir_p(File.dirname(@destination))
        FileUtils.mv(@out, @destination)
        puts "Built #{@pages.size} grammars in #{@destination} (English and Japanese); links verified"
      ensure
        FileUtils.rm_rf(@out) if @out && File.directory?(@out)
      end

      private

      def validate_destination!
        if @destination == ROOT || @destination == "/" || ROOT.start_with?(@destination + "/") || @destination.start_with?(File.join(ROOT, ".git") + "/")
          raise ArgumentError, "unsafe output directory"
        end
        if File.exist?(@destination) && !File.file?(File.join(@destination, ".rdc-site"))
          raise ArgumentError, "output exists without .rdc-site marker: #{@destination}; choose an empty output path"
        end
      end

      def prepare_assets
        directory = File.join(ROOT, "site/assets")
        files = Dir.glob(File.join(directory, "**/*")).select { |file| File.file?(file) }.sort
        digest = Digest::SHA256.hexdigest(files.map { |file| file.delete_prefix(directory) + File.binread(file) }.join)[0, 12]
        files.each do |file|
          relative = file.delete_prefix(directory + "/")
          target = relative.sub(/\.(css|js)\z/, ".#{digest}.\\1")
          @assets[relative] = "assets/#{target}"
          content = File.binread(file)
          if relative.end_with?(".js")
            content = content.force_encoding("UTF-8").gsub(/(["'])\.\/([a-z_-]+)\.js\1/, '\1./\2.' + digest + '.js\1')
          end
          Rdc.write(File.join(@out, "assets", target), content)
        end
      end

      def load_page(language, version)
        meta = @manifest.meta(language)
        ir = Generator.load(language, version, meta)
        analysis = IR::Analysis.new(ir)
        ir.fetch("rules").each do |rule|
          next unless rule["kind"] == "normal"
          warn "#{language.id}@#{version.id}: unreachable #{rule['name']}" unless analysis.paths.key?(rule["name"])
          warn "#{language.id}@#{version.id}: nonproductive #{rule['name']}" unless analysis.shortest.key?(rule["name"])
        end
        simplify = IR::Simplify.new(ir, meta)
        examples_file = File.join(ROOT, "grammars", language.id, "examples.yml")
        examples = File.file?(examples_file) ? YAML.safe_load_file(examples_file, aliases: false) : {}
        Page.new(language: language, version: version, ir: ir, meta: meta, analysis: analysis,
                 simplified: simplify.rules, raw: simplify.rules(raw: true), examples: examples, changes: {})
      end

      def prepare_changes
        @pages.group_by { |page| page.language.id }.each_value do |group|
          group.sort_by { |page| Gem::Version.new(page.version.id) }.each_cons(2) do |before, after|
            diff = IR::Diff.compare(before.ir, after.ir, epsilon_rules: Array(after.meta["epsilon_rules"]))
            after.changes.merge!(diff)
          end
        end
      end

      def search_entries(page)
        page.ir.fetch("rules").map do |rule|
          uses = IR::Expression.symbols(IR::Expression.from_rule(rule, page.raw.keys)).uniq
          names = uses.filter_map { |name| page.ir.fetch("terminals").find { |terminal| terminal["name"] == name }&.fetch("display", name) }
          { "n" => rule["name"], "s" => Slug.rule(rule["name"]), "k" => rule["kind"], "a" => "", "t" => names,
            "u" => "#{page.language.id}/#{page.version.id}/##{Slug.rule(rule['name'])}", "l" => "#{page.language.name} #{page.version.id}" }
        end + page.ir.fetch("terminals").map do |terminal|
          { "n" => terminal["name"], "s" => Slug.terminal(terminal["name"]), "k" => "terminal", "a" => terminal["display"],
            "u" => "#{page.language.id}/#{page.version.id}/terminals/##{Slug.terminal(terminal['name'])}", "l" => "#{page.language.name} #{page.version.id}" }
        end
      end

      def write_api
        index = { "schema" => 1, "languages" => @pages.group_by { |page| page.language.id }.map do |id, group|
          { "id" => id, "name" => group.first.language.name, "versions" => group.map do |page|
            { "id" => page.version.id, "default" => page.version.default, "ir" => "#{id}/#{page.version.id}.json", "source" => page.ir["source"] }
          end }
        end }
        write_json("api/v1/index.json", index)
        entries = []
        @pages.each do |page|
          write_json("api/v1/#{page.language.id}/#{page.version.id}.json", page.ir)
          page_entries = search_entries(page)
          entries.concat(page_entries)
          write_json("api/v1/search/#{page.language.id}-#{page.version.id}.json", page_entries)
          write_json("api/v1/metrics/#{page.language.id}-#{page.version.id}.json", page.analysis.metrics)
          source_file = File.join(Fetcher::CACHE, page.language.id, page.version.id, page.language.license.fetch("path"))
          license_copy = File.join(ROOT, "grammars", page.language.id, "LICENSE.upstream")
          if File.file?(license_copy)
            Rdc.write(File.join(@out, "licenses", "#{page.language.id}.txt"), File.read(license_copy, encoding: "UTF-8"))
          elsif File.file?(source_file)
            Rdc.write(File.join(@out, "licenses", "#{page.language.id}.txt"), File.read(source_file, encoding: "UTF-8"))
          else
            raise "missing upstream license copy: #{page.language.id}; run rdc fetch and retain LICENSE.upstream"
          end
        end
        write_json("api/v1/search/index.json", entries)
      end

      def build_locale(locale)
        prefix = locale == "ja" ? "ja/" : ""
        write_page(prefix + "index.html", "index", locale)
        write_page(prefix + "licenses/index.html", "licenses", locale, title: translations[locale]["licenses"])
        write_page(prefix + "404.html", "not_found", locale, title: "404")
        @pages.each do |page|
          base = "#{page.language.id}/#{page.version.id}/"
          options = { page: page, title: "#{page.language.name} #{page.version.id}", description: "#{page.language.name} #{page.version.id} #{translations[locale]['diagrams']}" }
          write_page(prefix + base + "index.html", "language", locale, **options, raw: false)
          write_page(prefix + base + "raw/index.html", "language", locale, **options, raw: true)
          write_page(prefix + base + "terminals/index.html", "terminals", locale, **options)
          if page.version.default
            write_page(prefix + "#{page.language.id}/index.html", "language", locale, **options, raw: false, canonical_path: prefix + base)
          end
        end
        @pages.group_by { |page| page.language.id }.each do |id, group|
          comparisons = group.sort_by { |page| Gem::Version.new(page.version.id) }.each_cons(2).to_a
          write_page(prefix + "#{id}/changelog/index.html", "changelog", locale,
                     group: group, comparisons: comparisons, title: "#{group.first.language.name} #{translations[locale]['changelog']}")
          comparisons.each do |before, after|
            diff = after.changes
            base = "#{id}/diff/#{before.version.id}...#{after.version.id}/"
            write_page(prefix + base + "index.html", "diff", locale, before: before, after: after, diff: diff,
                       title: "#{after.language.name} #{before.version.id} → #{after.version.id}")
            write_json(prefix + base + "diff.json", diff)
          end
        end
      end

      def write_page(path, template, locale, **locals)
        content = View.new(self, path, locale, locals).render(template)
        Rdc.write(File.join(@out, path), content)
      end

      def write_json(path, value) = Rdc.write(File.join(@out, path), JSON.pretty_generate(value) + "\n")

      def write_legacy_redirects
        @pages.select { |page| page.version.default }.each do |page|
          script = "location.replace(#{(page.language.id + '/').to_json}+location.hash);"
          title = "#{page.language.name} diagrams"
          html = <<~HTML
            <!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
            <title>#{title}</title><meta name="description" content="#{title}"><link rel="canonical" href="#{SITE_URL}/#{page.language.id}/">
            <meta http-equiv="refresh" content="0; url=#{page.language.id}/"><script>#{script}</script></head>
            <body><main><h1>#{title}</h1><p><a href="#{page.language.id}/">#{title}</a></p></main></body></html>
          HTML
          Rdc.write(File.join(@out, "#{page.language.id}.html"), html)
        end
      end

      def write_sitemap
        paths = Dir.glob(File.join(@out, "**/index.html")).map { |file| file.delete_prefix(@out + "/").delete_suffix("index.html") }.sort
        xml = +"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n"
        paths.each { |path| xml << "<url><loc>#{ERB::Util.html_escape(SITE_URL + '/' + path)}</loc></url>\n" }
        Rdc.write(File.join(@out, "sitemap.xml"), xml + "</urlset>\n")
      end
    end
  end
end
