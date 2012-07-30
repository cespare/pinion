require "digest/md5"
require "mime/types"

module Pinion
  class Asset
    attr_reader :uncompiled_path, :compiled_path, :from_type, :to_type, :compiled_contents, :length, :mtime,
                :content_type, :checksum

    def initialize(uncompiled_path, compiled_path, conversions)
      @uncompiled_path = uncompiled_path
      @compiled_path = compiled_path
      @from_type = conversions.length > 0 ? conversions.first.from_type : nil
      @to_type = conversions.length > 0 ? conversions.last.to_type : nil
      @compiled_contents = File.read(uncompiled_path)
      conversions.each do |conversion|
        @compiled_contents = conversion.convert(@compiled_contents)
      end
      @length = Rack::Utils.bytesize(@compiled_contents)
      @mtime = File.stat(uncompiled_path).mtime
      found_types = MIME::Types.type_for(compiled_path)
      @content_type = found_types.length > 0 ? found_types.first.content_type : nil
      @checksum = Digest::MD5.hexdigest(@compiled_contents)
    end

    # Allow the Asset to be served as a rack response body
    def each() yield @compiled_contents end
  end
end
