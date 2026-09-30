# frozen_string_literal: true
require "rake/testtask"
Rake::TestTask.new(:test) do |task|
  task.libs << "test"
  task.pattern = "test/**/*_test.rb"
end
task default: :test
desc "Generate the complete site"
task :build do
  ruby "exe/rdc", "build"
end
