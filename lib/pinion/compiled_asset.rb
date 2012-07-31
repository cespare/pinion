require "digest/md5"

require "pinion/asset"

module Pinion
  class CompiledAsset < Asset
    attr_reader :from_type

    def initialize(uncompiled_path, conversion)
      @from_type = conversion.from_type
      @to_type = conversion.to_type
      @compiled_contents = conversion.convert(File.read(uncompiled_path))
      @length = Rack::Utils.bytesize(@compiled_contents)
      @mtime = latest_mtime
      @extension = @to_type.to_s
      @checksum = Digest::MD5.hexdigest(@compiled_contents)
    end

    def contents() @compiled_contents end

    def latest_mtime
      pattern = "**/*#{self.class.sanitize_for_glob(".#{@from_type}")}"
      self.class.glob(pattern).reduce(Time.at(0)) { |latest, path| [latest, File.stat(path).mtime].max }
    end

    def invalidate
      Asset.cached_assets.delete_if { |_, asset| asset.is_a?(CompiledAsset) && asset.from_type == @from_type }
    end

    def self.sanitize_for_glob(pattern) pattern.gsub(/[\*\?\[\]\{\}]/) { |match| "\\#{match}" } end

    def self.glob(pattern, &block)
      enumerator = Enumerator.new do |yielder|
        Asset.watch_directories.each do |directory|
          Dir.glob(File.join(directory, pattern)) { |filename| yielder.yield filename }
        end
      end
      enumerator.each(&block)
    end
  end
end
