require "digest/md5"

module Pinion
  class Asset
    attr_reader :uncompiled_path, :compiled_path, :from_type, :to_type, :compiled_contents, :length, :mtime,
                :content_type, :checksum

    def initialize(uncompiled_path, compiled_path, conversion, mtime)
      @uncompiled_path = uncompiled_path
      @compiled_path = compiled_path
      @from_type = conversion.from_type
      @to_type = conversion.to_type
      @compiled_contents = conversion.convert(File.read(uncompiled_path))
      @length = Rack::Utils.bytesize(@compiled_contents)
      @mtime = mtime
      @content_type = conversion.content_type
      @checksum = Digest::MD5.hexdigest(@compiled_contents)
    end

    # Allow the Asset to be served as a rack response body
    def each() yield @compiled_contents end
  end
end
