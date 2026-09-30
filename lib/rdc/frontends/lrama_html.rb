# frozen_string_literal: true
require 'nokogiri'

module Rdc
  module Frontends
    # Migration reader for the original IR-lite pages; current builds use the library frontend.
    class LramaHtml
      Rule = Struct.new(:name, :svg, :refs, :terminals, keyword_init: true)

      def parse(html)
        Nokogiri::HTML5(html).css('h2.diagram-header').map do |heading|
          svg = heading.next_element
          raise ArgumentError, "SVG missing after #{heading.text.inspect}" unless svg&.name == 'svg'
          Rule.new(name: heading.text, svg: svg,
                   refs: svg.css('g.non-terminal text').map(&:text).uniq,
                   terminals: svg.css('g.terminal text').map(&:text).uniq)
        end
      end
    end
  end
end
