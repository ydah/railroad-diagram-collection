# frozen_string_literal: true
require "nokogiri"
require "uri"
require "set"

module Rdc
  module Site
    module Validator
      module_function

      def check!(root)
        documents = Dir.glob(File.join(root, "**/*.html")).to_h do |file|
          document = Nokogiri::HTML5(File.read(file, encoding: "UTF-8"), max_tree_depth: 10_000)
          ids = document.css("[id]").map { |element| element["id"] }
          duplicate = ids.tally.select { |_, count| count > 1 }.keys
          raise "#{file}: duplicate ids #{duplicate.take(5).join(', ')}" unless duplicate.empty?
          [file, [document, ids.to_set]]
        end
        documents.each do |file, (document, _ids)|
          document.css("a[href], link[href], script[src], img[src]").each do |element|
            reference = element["href"] || element["src"]
            next if reference.empty? || reference.match?(/\A(?:https?:|mailto:|data:|blob:|\/\/)/)
            path, anchor = reference.split("#", 2)
            target = path.empty? ? file : File.expand_path(URI::RFC2396_PARSER.unescape(path.split("?", 2).first), File.dirname(file))
            target = File.join(target, "index.html") if File.directory?(target)
            raise "#{file}: link escapes site: #{reference}" unless target.start_with?(root + "/")
            raise "#{file}: missing link #{reference}" unless File.file?(target)
            next unless anchor && !anchor.empty? && documents.key?(target)
            anchor = URI::RFC2396_PARSER.unescape(anchor)
            raise "#{file}: missing anchor #{reference}" unless documents.fetch(target).last.include?(anchor)
          end
        end
        true
      end
    end
  end
end
