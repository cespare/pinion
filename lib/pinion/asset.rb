require "rack/mime"

module Pinion
  class Asset
    attr_reader :length, :mtime, :checksum

    def initialize() raise "subclass me" end
    def contents() raise "Implement me" end

    # Allow the Asset to be served as a rack response body
    def each() yield contents end

    def content_type() Rack::Mime::MIME_TYPES[".#{@extension}"] || "application/octet-stream" end
  end
end
