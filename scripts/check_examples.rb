#!/usr/bin/env ruby
# frozen_string_literal: true
require 'open3'
require 'yaml'

ROOT = File.expand_path('..', __dir__)
RUNTIMES = {
  'ruby' => [['4.0', 'ruby:4.0'], ['3.4', 'ruby:3.4']],
  'php' => [['8.5', 'php:8.5-cli'], ['8.4', 'php:8.4-cli']],
  'perl' => [['5.44', 'perl:5.44'], ['5.42', 'perl:5.42']]
}.freeze
COMMANDS = {'ruby' => ['ruby', '--parser=parse.y', '-c', '-'],
            'php' => ['php', '-l'], 'perl' => ['perl', '-c', '-']}.freeze

RUNTIMES.each do |language, versions|
  examples = YAML.safe_load_file(File.join(ROOT, 'grammars', language, 'examples.yml'))
  versions.each do |version, image|
    # Pull outside the timed container run. Compilation receives no host mounts, credentials or network.
    _, error, status = Open3.capture3('docker', 'pull', image)
    abort "#{image}: pull failed: #{error}" unless status.success?
    examples.each_with_index do |(rule, code), index|
      name = "rdc-examples-#{Process.pid}-#{language}-#{version.tr('.', '-')}-#{index}"
      args = ['docker', 'run', '--rm', '--name', name, '-i', '--network', 'none', '--cap-drop', 'ALL',
              '--security-opt', 'no-new-privileges', '--read-only', '--user', '65534:65534',
              '--memory', '64m', '--cpus', '0.5', '--pids-limit', '64',
              '--tmpfs', '/tmp:rw,noexec,nosuid,size=4m', image, *COMMANDS.fetch(language)]
      expired = false
      watchdog = Thread.new do
        sleep 20
        expired = true
        Open3.capture3('docker', 'rm', '-f', name)
      end
      begin
        output, error, status = Open3.capture3(*args, stdin_data: code)
        abort "#{language}@#{version} #{rule}: syntax check exceeded 20 seconds" if expired
        abort "#{language}@#{version} #{rule}: #{output}#{error}" unless status.success?
        puts "#{language}@#{version} #{rule}: syntax OK"
      ensure
        watchdog.kill
        watchdog.join
        # A timed-out client must not leave a BEGIN block running in a container.
        Open3.capture3('docker', 'rm', '-f', name)
      end
    end
  end
end
