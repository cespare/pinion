require "pinion/error"
require "digest/md5"

require "pinion/asset"
require "pinion/bundle_type"

module Pinion
  # A `Bundle` is a set of assets of the same type that will be served as a single grouped asset in
  # production. A `Bundle` has a `BundleType` that defines how to process the bundle.
  class Bundle < Asset
    # Each bundle is cached by name.
    @@bundles = {}

    attr_reader :contents, :name, :paths

    # Create a new `Bundle`.
    def initialize(bundle_type, name, paths)
      @name = name
      @paths = paths
      raise Error, "No paths provided" if paths.empty?

      @assets = paths.map do |path|
        asset = Asset[path]
        raise Error, "No such asset available: #{path}" unless asset
        asset
      end
      @extension = @assets.first.extension
      unless @assets.all? { |asset| asset.extension == @extension }
        raise Error, "All assets in a bundle must have the same extension"
      end
      @contents = bundle_type.process(@assets)
      @checksum = Digest::MD5.hexdigest(@contents)
      @mtime = @assets.map(&:mtime).max
      @length = Rack::Utils.bytesize(@contents)
    end

    # Create a new bundle from a bundle_type name (e.g. `:concatenate_and_uglify_js`) and an array of paths.
    # The name is taken as the identifier in the resulting path.
    def self.create(name, bundle_type_name, paths)
      bundle_type = BundleType[bundle_type_name]
      raise Error, "No such bundle type #{bundle_type_name}" unless bundle_type
      if @@bundles[name.to_s]
        raise Error, "There is already a bundle called #{name}. Each bundle must have a different name."
      end
      bundle = Bundle.new(bundle_type, name, paths)
      @@bundles[name.to_s] = bundle
      bundle
    end

    # Find a `Bundle` by its name.
    def self.[](name) name && @@bundles[name.to_s] end
  end
end
