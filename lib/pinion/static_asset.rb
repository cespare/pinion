require "rack/mime"
require "digest/md5"

require "pinion/error"

module Pinion
  class StaticAsset
    attr_reader :path, :length, :mtime, :content_type, :checksum

    def initialize(path)
      raise Error, "Bad path #{path}." unless File.file? path
      @path = path
      temp_contents = contents
      @length = Rack::Utils.bytesize(temp_contents)
      @mtime = File.stat(@path).mtime
      base, dot, extension = @path.rpartition(".")
      @content_type = Rack::Mime::MIME_TYPES[".#{extension}"] unless dot.empty?
      @content_type ||= "application/octet-stream"
      @checksum = Digest::MD5.hexdigest(temp_contents)
    end

    # Don't cache (possibly large) static files in memory
    def contents() File.read(@path) end

    def each() yield contents end
  end
end
