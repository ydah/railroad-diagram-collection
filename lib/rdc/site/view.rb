# frozen_string_literal: true
require "erb"
require "digest"
require "open3"
require "tempfile"
require_relative "../slug"

module Rdc
  module Site
    class View
      THEME_INIT = 'document.documentElement.dataset.js="true";try{for(const k of ["theme","width","internal"]){const v=localStorage.getItem("rdc:"+k);if(v)document.documentElement.dataset[k]=v}}catch(e){}if(/^#r-(~24accept|(?:~24)?~40[0-9]+)$/.test(location.hash))document.documentElement.dataset.internal="show";'.freeze
      def initialize(builder, path, locale, locals)
        @builder, @path, @locale = builder, path, locale
        @root = "../" * path.count("/")
        @prefix = locale == "ja" ? "ja/" : ""
        @logical_path = path.delete_prefix(@prefix).delete_suffix("index.html")
        locals.each { |key, value| instance_variable_set("@#{key}", value) }
        @title ||= "Railroad Diagram Collection"
        @description ||= t("description")
      end

      def h(value) = ERB::Util.html_escape(value.to_s)
      def t(key) = @builder.translations.fetch(@locale).fetch(key)
      def url(path = "") = @root + @prefix + path
      def asset(path) = @root + @builder.assets.fetch(path)
      def api(path) = @root + "api/v1/" + path
      def slug(name) = Slug.rule(name)
      def term_slug(name) = Slug.terminal(name)
      def canonical = SITE_URL + "/" + (@canonical_path || @path.delete_suffix("index.html"))
      def source_url(page) = page.language.repo.delete_suffix(".git") + "/blob/" + page.ir.fetch("source").fetch("commit") + "/" + page.language.grammar
      def rule_link(name, prefix = "") = %(<a href="#{h(prefix)}##{slug(name)}">#{h(name)}</a>)
      def links(names, prefix = "") = names.map { |name| rule_link(name, prefix) }.join(" › ")
      def bnf(rule)
        alternatives = rule.fetch("alternatives").map { |alternative| alternative.fetch("symbols").empty? ? "ε" : alternative.fetch("symbols").join(" ") }
        "#{rule.fetch('name')} ::= " + alternatives.join("\n    | ")
      end

      def unified_diff(name)
        rules = [@before, @after].map { |page| page.ir.fetch("rules").find { |rule| rule["name"] == name } }
        Tempfile.create("rdc-before") do |before|
          Tempfile.create("rdc-after") do |after|
            [before, after].zip(rules).each { |file, rule| file.write(bnf(rule) + "\n"); file.flush }
            output, status = Open3.capture2("diff", "-u", "-L", "#{@before.version.id}/#{name}", "-L", "#{@after.version.id}/#{name}", before.path, after.path)
            raise "BNF diff failed" unless [0, 1].include?(status.exitstatus)
            output
          end
        end
      end

      def svg(page, name, raw: @raw || false, heading: "h-#{slug(name)}", alt_classes: nil, link_base: nil)
        expressions = raw ? page.raw : page.simplified
        output = Render::SVG.new(page.ir, raw: raw).render(expressions.fetch(name), heading_id: heading, alt_classes: alt_classes)
        return output unless link_base
        output.gsub('href="#', 'href="' + h(link_base) + '#')
      end

      def svg_placeholder(output)
        root = Nokogiri::XML(output).root
        size = %w[width height viewBox].map { |attribute| %(#{attribute}="#{h(root[attribute])}") }.join(" ")
        %(<svg xmlns="http://www.w3.org/2000/svg" class="rr railroad-diagram" data-placeholder aria-hidden="true" #{size}></svg>)
      end

      def diff_classes(rule, symbols, kind, epsilon_rules)
        normalized = symbols.map { |values| IR::Normalize.symbols(values, epsilon_rules) }
        rule.fetch("alternatives").map do |alternative|
          normalized.include?(IR::Normalize.symbols(alternative.fetch("symbols"), epsilon_rules)) ? "alt-#{kind}" : nil
        end
      end

      def terminal_display(page, name)
        terminal = page.ir.fetch("terminals").find { |entry| entry["name"] == name }
        terminal ? terminal.fetch("display", name) : name
      end

      def token_aliases(page, rule)
        symbols = IR::Expression.symbols(IR::Expression.from_rule(rule, page.raw.keys))
        page.ir.fetch("terminals").filter_map { |terminal| terminal["display"] if symbols.include?(terminal["name"]) }.uniq.to_json
      end

      def structured_data
        data = { "@context" => "https://schema.org", "@type" => "WebPage", "name" => @title,
                 "description" => @description, "url" => canonical, "inLanguage" => @locale }
        if @page
          data["mainEntity"] = { "@type" => "Dataset", "name" => @title + " parser grammar", "license" => @page.language.license.fetch("url"), "isBasedOn" => source_url(@page) }
        end
        JSON.generate(data).gsub("<", "\\u003c")
      end

      def script_hash(script) = "'sha256-#{[Digest::SHA256.digest(script)].pack('m0')}'"
      def template(name)
        ERB.new(File.read(File.join(ROOT, "lib/rdc/templates", "#{name}.html.erb"), encoding: "UTF-8"), trim_mode: "-").result(binding)
      end

      def render(name)
        @content = template(name)
        template("layout")
      end
    end
  end
end
