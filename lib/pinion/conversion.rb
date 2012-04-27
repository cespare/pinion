require "pinion/error"
require "set"

module Pinion
  # A conversion describes how to convert certain types of files and create asset links for them.
  # Conversions.create() provides a tiny DSL for defining new conversions
  class Conversion
    @@conversions = {}
    def self.[](from_and_to) @@conversions[from_and_to] end
    def self.conversions_for(to) @@conversions.values.select { |c| c.to_type == to } end
    def self.add_watch_directory(path) @@conversions.values.each { |c| c.add_watch_directory(path) } end
    def self.create(from_and_to, &block)
      unless from_and_to.is_a?(Hash) && from_and_to.size == 1
        raise Error, "Unexpected argument to Conversion.create: #{from_and_to.inspect}"
      end
      conversion = Conversion.new *from_and_to.to_a[0]
      conversion.instance_eval &block
      conversion.verify
      @@conversions[conversion.signature] = conversion
    end

    attr_reader :from_type, :to_type, :gem_required

    def initialize(from_type, to_type)
      @loaded = false
      @from_type = from_type
      @to_type = to_type
      @gem_required = nil
      @conversion_fn = nil
      @watch_fn = Proc.new {} # Don't do anything by default
      @environment = {}
    end

    # DSL methods
    def require_gem(gem_name) @gem_required = gem_name end
    def render(&block) @conversion_fn = block end
    def watch(&block) @watch_fn = block end

    # Instance methods
    def signature() { @from_type => @to_type } end
    def content_type
      case @to_type
      when :css then "text/css"
      when :js then "application/javascript"
      else
        raise Error, "No known content-type for #{@to_type}."
      end
    end
    def convert(file_contents)
      require_dependency
      @conversion_fn.call(file_contents, @environment)
    end
    def add_watch_directory(path) @watch_fn.call(path, @environment) end

    def verify
      unless [@from_type, @to_type].all? { |s| s.is_a? Symbol }
        raise Error, "Expecting symbol key/value but got #{from_and_to.inspect}"
      end
      unless @conversion_fn
        raise Error, "Must provide a conversion function with convert { |file_contents| ... }."
      end
    end

    private

    def require_dependency
      return if @loaded
      @loaded = true
      return unless @gem_required
      begin
        require @gem_required
      rescue LoadError => e
        raise "Tried to load conversion for #{signature.inspect}, but failed to load the #{@gem_required} gem"
      end
    end
  end

  # Define built-in conversions
  Conversion.create :scss => :css do
    require_gem "sass"
    render do |file_contents, environment|
      load_paths = environment[:load_paths].to_a || []
      Sass::Engine.new(file_contents, :syntax => :scss, :load_paths => load_paths).render
    end
    watch do |path, environment|
      environment[:load_paths] ||= Set.new
      environment[:load_paths] << path
    end
  end

  Conversion.create :sass => :css do
    require_gem "sass"
    render do |file_contents, environment|
      load_paths = environment[:load_paths].to_a || []
      Sass::Engine.new(file_contents, :syntax => :sass, :load_paths => load_paths).render
    end
    watch do |path, environment|
      environment[:load_paths] ||= Set.new
      environment[:load_paths] << path
    end
  end

  Conversion.create :coffee => :js do
    require_gem "coffee-script"
    render { |file_contents| CoffeeScript.compile(file_contents) }
  end
end
