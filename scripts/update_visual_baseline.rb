# frozen_string_literal: true
require "nokogiri"
require "fileutils"

home = Nokogiri::HTML5(File.read("dist/index.html"))
ruby = Nokogiri::HTML5(File.read("dist/ruby/4.0/index.html"))
css = File.read(File.join("dist", home.at_css('link[rel="stylesheet"]')["href"]))
diagrams = home.css(".legend svg").to_a + %w[program defn_head].map { |name| ruby.at_css("#r-#{name} svg:not([data-placeholder])") }
raise "Build the complete site first" if diagrams.any?(&:nil?)
FileUtils.mkdir_p("test/fixtures/visual")
File.write("test/fixtures/visual/diagrams.html", "<!DOCTYPE html><html><head><style>#{css}</style></head><body>#{diagrams.map(&:to_html).join}</body></html>\n")
puts "Updated six diagram baselines; review the browser comparisons before committing."
