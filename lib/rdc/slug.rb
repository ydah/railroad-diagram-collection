# frozen_string_literal: true
module Rdc
  module Slug
    module_function
    def rule(name) = "r-" + encode(name)
    def terminal(name) = "t-" + encode(name)
    def encode(name) = name.b.gsub(/[^A-Za-z0-9_]/) { |c| format("~%02X", c.ord) }
  end
end
