require "rack/mime"
require "set"
require "time"

require "pinion/conversion"
require "pinion/environment"

module Pinion
  class Asset
    class << self
      attr_reader :watch_directories, :cached_assets
    end

    # Paths to consider for requested assets
    @watch_directories = Set.new
    # Cache of raw files with locations -- used in production mode
    @cached_files = {}
    # Asset cache for quick lookup
    @cached_assets = {}

    #
    # Asset methods
    #

    attr_reader :extension, :length, :mtime, :checksum

    def initialize() raise "subclass me" end
    def contents() raise "Implement me" end

    # The latest mtime of this asset. For compiled assets, this the latest mtime of all files of this type.
    def latest_mtime() raise "Implement me" end

    # Invalidate this asset (and possibly others it depends on)
    def invalidate() raise "Implement me" end

    # Allow the Asset to be served as a rack response body
    def each() yield contents end

    def content_type() Rack::Mime::MIME_TYPES[".#{@extension}"] || "application/octet-stream" end

    # In production mode, assume that the files won't change on the filesystem. This means we can always serve
    # them from cache (if cached).
    def self.static() Pinion.environment == "production" end

    #
    # File watcher class methods
    #

    # Add a path to the set of asset paths.
    def self.watch_path(path) @watch_directories << File.join(".", path) end

    # Find a particular file in the watched directories.
    def self.find_file(path)
      return @cached_files[path] if (static && @cached_files.include?(path))
      result = nil
      @watch_directories.each do |directory|
        filename = File.join(directory, path)
        if File.file? filename
          result = filename
          break
        end
      end
      @cached_files[path] = result if static
      result
    end

    #
    # Asset search methods
    #

    # Look up an asset by its path. It may be returned from cache.
    def self.[](to_path)
      asset = @cached_assets[to_path]
      if asset
        return asset if static
        mtime = asset.mtime
        latest = asset.latest_mtime
        if latest > mtime
          asset.invalidate
          return self[to_path]
        end
      else
        begin
          asset = find_uncached_asset(to_path)
        rescue Error => error
          STDERR.puts "Warning: #{error.message}"
          return nil
        end
        @cached_assets[to_path] = asset
      end
      asset
    end

    def self.find_uncached_asset(to_path)
      real_file = find_file(to_path)
      return StaticAsset.new(to_path, real_file) if real_file
      from_path, conversion = find_source_file_and_conversion(to_path)
      # If we reach this point we've found the asset we're going to compile
      # TODO: log at info: compiling asset ...
      CompiledAsset.new from_path, conversion
    end

    def self.find_source_file_and_conversion(to_path)
      path, dot, suffix = to_path.rpartition(".")
      conversions = Conversion.conversions_for(suffix.to_sym)
      raise Error, "No conversion for for #{to_path}" if conversions.empty?
      conversions.each do |conversion|
        filename = "#{path}.#{conversion.from_type}"
        from_path = find_file(filename)
        return [from_path, conversion] if from_path
      end
      raise Error, "No source file found for #{to_path}"
    end
  end
end
