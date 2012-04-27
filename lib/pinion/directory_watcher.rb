require "set"
require "time"

module Pinion
  class DirectoryWatcher
    def initialize(root = ".")
      @root = root
      @watch_directories = Set.new
    end

    def <<(directory) @watch_directories << File.join(@root, directory) end

    def glob(pattern, &block)
      enumerator = Enumerator.new do |yielder|
        @watch_directories.each do |directory|
          Dir.glob(File.join(directory, pattern)) { |filename| yielder.yield filename }
        end
      end
      enumerator.each(&block)
    end

    def find(path)
      @watch_directories.each do |directory|
        result = File.join(directory, path)
        return result if File.file? result
      end
      nil
    end

    def latest_mtime_with_suffix(suffix)
      pattern = "**/*#{DirectoryWatcher.sanitize_for_glob(suffix)}"
      glob(pattern).reduce(Time.at(0)) { |latest, path| [latest, File.stat(path).mtime].max }
    end

    def self.sanitize_for_glob(pattern) pattern.gsub(/[\*\?\[\]\{\}]/) { |match| "\\#{match}" } end
  end
end
