require "set"
require "time"

module Pinion
  class DirectoryWatcher
    # Assume a static filesystem if options[:static] = true. Used in production mode.
    def initialize(root = ".", options = {})
      @root = root
      @watch_directories = Set.new
      if @static = options[:static]
        @find_cache = {}
      end
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
      return @find_cache[path] if (@static && @find_cache.include?(path))
      result = nil
      @watch_directories.each do |directory|
        filename = File.join(directory, path)
        if File.file? filename
          result = filename
          break
        end
      end
      @find_cache[path] = result if @static
      result
    end

    def latest_mtime
      glob("**/*").reduce(Time.at(0)) { |latest, path| [latest, File.stat(path).mtime].max }
    end
  end
end
