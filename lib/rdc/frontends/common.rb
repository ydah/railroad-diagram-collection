# frozen_string_literal: true

module Rdc
  module Frontends
    module Common
      module_function

      def terminal(name, alias_name = nil, meta = {}, internal: false)
        display = alias_name || name
        while display.match?(/\A(?:'.*'|".*"|`.*')\z/m)
          display = display[1...-1]
        end
        display = name if display.strip.empty?
        kind = if internal
          'internal'
        elsif name.start_with?('[', '#x')
          'class'
        elsif alias_name || name.start_with?("'", '"', '#x', '[')
          display.match?(/\A[A-Za-z][A-Za-z0-9_-]*\z/) ? 'keyword' : 'punct'
        else
          'class'
        end
        result = {'name' => name, 'display' => display, 'kind' => kind}
        result['alias'] = alias_name if alias_name
        override = meta.fetch('token_display', {}).fetch(name, {})
        override = {'display' => override} if override.is_a?(String)
        result.merge(override)
      end

      def kind(name)
        return 'accept' if name == '$accept'
        return 'midrule' if name.match?(/\A\$?@\d+\z/)
        'normal'
      end
    end
  end
end
