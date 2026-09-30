#!/usr/bin/env ruby
# frozen_string_literal: true
require_relative "../lib/rdc/site/validator"
Rdc::Site::Validator.check!(File.expand_path(ARGV.fetch(0, "dist")))
puts "All local files and fragments resolve; no duplicate ids."
