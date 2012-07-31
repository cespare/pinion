require "digest/md5"

require "pinion/asset"
require "pinion/error"

module Pinion
  class StaticAsset < Asset
    def initialize(virtual_path, real_path)
      raise Error, "Bad path for static file: '#{real_path}'." unless File.file? real_path
      @real_path = real_path
      @virtual_path = virtual_path
      temp_contents = contents
      @length = Rack::Utils.bytesize(temp_contents)
      @mtime = latest_mtime
      base, dot, @extension = virtual_path.rpartition(".")
      @checksum = Digest::MD5.hexdigest(temp_contents)
    end

    # Don't cache (possibly large) static files in memory
    def contents() File.read(@real_path) end

    def latest_mtime() File.stat(@real_path).mtime end

    def invalidate
      Asset.cached_assets.delete(@virtual_path)
    end
  end
end
