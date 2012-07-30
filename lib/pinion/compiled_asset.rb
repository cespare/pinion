require "digest/md5"

require "pinion/asset"

module Pinion
  class CompiledAsset < Asset
    def initialize(uncompiled_path, conversion, mtime)
      @from_type = conversion.from_type
      @to_type = conversion.to_type
      @compiled_contents = conversion.convert(File.read(uncompiled_path))
      @length = Rack::Utils.bytesize(@compiled_contents)
      @mtime = mtime
      @extension = @to_type.to_s
      @checksum = Digest::MD5.hexdigest(@compiled_contents)
    end

    def contents() @compiled_contents end
  end
end
