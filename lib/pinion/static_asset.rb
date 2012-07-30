require "digest/md5"

require "pinion/asset"
require "pinion/error"

module Pinion
  class StaticAsset < Asset
    def initialize(path)
      raise Error, "Bad path #{path}." unless File.file? path
      @path = path
      temp_contents = contents
      @length = Rack::Utils.bytesize(temp_contents)
      @mtime = File.stat(@path).mtime
      base, dot, @extension = @path.rpartition(".")
      @checksum = Digest::MD5.hexdigest(temp_contents)
    end

    # Don't cache (possibly large) static files in memory
    def contents() File.read(@path) end
  end
end
