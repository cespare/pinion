module Pinion
  # A `BundleType` is a description of how to bundle together multiple assets of the same type. New types of
  # `Bundle`s may be created with `BundleType.create`. A particular bundle type is simply a Proc that knows
  # how to bundle together a set of assets. For convenience, there is a built-in `BundleType` type already
  # defined, `:concatenate_and_uglify_js`.
  class BundleType
    @@bundle_types = {}

    def initialize(definition_proc)
      @definition_proc = definition_proc
    end

    # Process an array of `Asset`s to produce the bundled result.
    def process(assets)
      @definition_proc.call(assets)
    end

    # Create a new bundle definition. The block will be called with argument `assets`, the array of `Asset`s.
    # - assets: an array of `Asset`s
    def self.create(name, &block)
      @@bundle_types[name] = BundleType.new(block)
    end

    # Retrieve a `BundleType` by name.
    def self.[](name) @@bundle_types[name] end
  end

  BundleType.create(:concatenate_and_uglify_js) do |assets|
    begin
      require "uglifier"
    rescue LoadError => e
      raise "The uglifier gem is required to use the :concatenate_and_uglify_js bundle."
    end
    # Concatenate the contents of the assets (possibly compiling along the way)
    concatenated_contents = assets.reduce("") do |concatenated_text, asset|
      contents = asset.contents
      # Taken from Sprockets's SafetyColons -- if the JS file is not blank and does not end in a semicolon,
      # append a semicolon and newline for safety.
      unless contents =~ /\A\s*\Z/m || contents =~ /;\s*\Z/m
        contents << ";\n"
      end
      concatenated_text << contents
    end
    concatenated_contents
    Uglifier.compile(concatenated_contents)
  end
end
