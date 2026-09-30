# frozen_string_literal: true
require "json"
require "yaml"
require "fileutils"

module Rdc
  ROOT = File.expand_path("..", __dir__)
  VERSION = "1.0.0"
  LRAMA_REVISION = "c8317b55850bc6cd9033ddfbf816377b73f6c7bc"
  SITE_URL = "https://ydah.github.io/railroad-diagram-collection"

  def self.write(path, text)
    FileUtils.mkdir_p(File.dirname(path))
    temporary = "#{path}.tmp"
    File.write(temporary, text, encoding: "UTF-8")
    File.rename(temporary, path)
  end
end
