# frozen_string_literal: true
require "railroad_diagrams"
require "nokogiri"
require_relative "../slug"

module Rdc
  module Render
    class SVG
      RR = RailroadDiagrams

      def initialize(ir, raw: false)
        @terminals = ir.fetch("terminals").to_h { |term| [term["name"], term] }
        @raw = raw
      end

      def render(expr, heading_id:, alt_classes: nil)
        @term_names = []
        item = build(expr, alt_classes)
        output = +""
        RR::Diagram.new(item).write_svg(->(part) { output << part })
        doc = Nokogiri::XML(output) { |config| config.strict }
        root = doc.root
        root["class"] = "rr railroad-diagram"
        root["xmlns"] = "http://www.w3.org/2000/svg"
        root["role"] = "group"
        root["aria-labelledby"] = heading_id
        decorate_symbols(doc)
        doc.css("path").each { |path| clean_path(path) }
        doc.css("*").each do |node|
          %w[x y width height rx ry textLength viewBox transform].each do |attr|
            node[attr] = rounded(node[attr]) if node[attr]
          end
        end
        root.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
      end

      private

      def build(expr, classes = nil)
        item = case expr.fetch("t")
               when "seq"
                 children = expr.fetch("items").map { |e| build(e) }
                 children.empty? ? RR::Skip.new : RR::Sequence.new(*children)
               when "choice"
                 children = expr.fetch("items").each_with_index.map { |e, i| label_alt(build(e), classes && classes[i], i) }
                 children.empty? ? RR::Skip.new : RR::Choice.new(0, *children)
               when "opt" then RR::Optional.new(build(expr.fetch("item")))
               when "star" then RR::ZeroOrMore.new(build(expr.fetch("item")), expr["sep"] && build(expr["sep"]))
               when "plus" then RR::OneOrMore.new(build(expr.fetch("item")), expr["sep"] && build(expr["sep"]))
               when "nt" then RR::NonTerminal.new(expr.fetch("name"))
               when "term" then terminal(expr.fetch("name"))
               when "eps" then RR::Skip.new
               when "note" then RR::Comment.new(expr.fetch("text"))
               when "lookahead" then RR::Comment.new("#{expr['negative'] ? '!' : '&'} lookahead: #{predicate_text(expr.fetch('item'))}")
               else raise ArgumentError, "Unsupported diagram expression: #{expr['t']}"
               end
        expr["t"] == "choice" || !classes ? item : label_alt(item, classes.first)
      end

      def label_alt(item, cls, index = 0)
        item.attrs["class"] = [item.attrs["class"], "alt", cls].compact.join(" ")
        item.attrs["data-alt"] = index.to_s
        item
      end

      def terminal(name)
        term = @terminals.fetch(name) { raise ArgumentError, "Unknown terminal: #{name}" }
        item = RR::Terminal.new(@raw ? name : term.fetch("display"), nil, name)
        item.attrs["data-rdc-term"] = @term_names.size.to_s
        @term_names << name
        item
      end

      def decorate_symbols(doc)
        doc.css("g.non-terminal").each do |group|
          text = group.at_css("text")
          name = text.text
          link = Nokogiri::XML::Node.new("a", doc)
          link["href"] = "##{Slug.rule(name)}"
          link["class"] = "rr-nt"
          link["data-rule"] = name
          link["aria-label"] = "Go to rule #{name}"
          group.add_previous_sibling(link)
          link.add_child(group)
        end
        doc.css("g.terminal").each do |group|
          group["data-term"] = @term_names.fetch(group["data-rdc-term"].to_i)
          group.remove_attribute("data-rdc-term")
        end
        doc.css("text").each do |text|
          next if text.text.empty?
          text["textLength"] = (text.text.length * RR::CHAR_WIDTH).to_s
          text["lengthAdjust"] = "spacingAndGlyphs"
        end
      end

      def predicate_text(expr)
        return expr["name"] if expr["name"]
        [expr["item"], *expr.fetch("items", [])].compact.map { |e| predicate_text(e) }.join(" ")
      end

      def clean_path(path)
        data = rounded(path["d"]).gsub(/[hv]-?0(?=[A-Za-z\s]|$)/, "")
        # A move-only path has no stroke; remove it instead of emitting thousands of h0 paths.
        data.match?(/[hlvaqcszt]/i) ? path["d"] = data : path.remove
      end

      def rounded(value)
        value.gsub(/-?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?/) do |number|
          rounded = (number.to_f * 2).round / 2.0
          rounded == rounded.to_i ? rounded.to_i.to_s : rounded.to_s
        end
      end
    end
  end
end
