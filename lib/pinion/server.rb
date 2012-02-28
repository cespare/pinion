#require "fssm"

require "pinion/error"
require "pinion/conversion"
require "time"
require "set"

module Pinion
  class Server
    Asset = Struct.new :from_path, :to_path, :from_type, :to_type, :compiled_contents, :length, :mtime,
                       :content_type
    Watch = Struct.new :path, :from_type, :to_type, :conversion

    def initialize
      @running = false
      @watch_directories = []
      @watches = []
      @cached_assets = {}
      @conversions_used = Set.new
      @file_server = Rack::File.new(Dir.pwd)
    end

    def convert(from_and_to, &block)
      unless from_and_to.is_a?(Hash) && from_and_to.size == 1
        raise Error, "Unexpected argument to convert: #{from_and_to.inspect}"
      end
      from, to = from_and_to.to_a[0]
      unless [from, to].all? { |s| s.is_a? Symbol }
        raise Error, "Expecting symbols in this hash #{from_and_to.inspect}"
      end
      if block_given?
        # Save new conversion type (this might overwrite an implicit or previously defined conversion)
        Conversion.create(from_and_to) do
          render { |file_contents| block.call(file_contents) }
        end
      else
        unless Conversion[from_and_to]
          raise Error, "No immplicit conversion for #{from_and_to.inspect}. Must provide a conversion block."
        end
      end
    end

    def watch(path)
      raise Error, "#{path} is not a directory." unless File.directory? path
      @watch_directories << path
      Conversion.add_watch_directory path
    end

    # Boilerplate mostly stolen from sprockets
    # https://github.com/sstephenson/sprockets/blob/master/lib/sprockets/server.rb
    def call(env)
      start unless @running

      # Avoid modifying the session state, don't set cookies, etc
      env["rack.session.options"] ||= {}
      env["rack.session.options"].merge! :defer => true, :skip => true

      root = env["SCRIPT_NAME"]
      path = Rack::Utils.unescape(env["PATH_INFO"].to_s).sub(%r[^/], "")

      if path.include? ".."
        return with_content_length([403, { "Content-Type" => "text/plain" }, ["Forbidden"]])
      end

      real_file = get_real_file(path)
      if real_file
        # Total hack; this is probably a big misuse of Rack::File but I don't want to have to reproduce a lot
        # of its logic
        # TODO: Fix this
        env["PATH_INFO"] = real_file
        return @file_server.call(env)
      end

      asset = get_asset(path)
      if asset
        headers = {
          "Content-Type" => asset.content_type,
          "Content-Length" => asset.length.to_s,
          # TODO: set a long cache in prod mode when implemented
          "Cache-Control" => "public, must-revalidate",
          "Last-Modified" => asset.mtime.httpdate,
        }
        return [200, headers, []] if env["REQUEST_METHOD"] == "HEAD"
        [200, headers, asset.compiled_contents]
      else
        with_content_length([404, { "Content-Type" => "text/plain" }, ["Not found"]])
      end
    rescue Exception => e
      # TODO: logging
      STDERR.puts "Error compiling #{path}:"
      STDERR.puts "#{e.class.name}: #{e.message}"
      # TODO: render nice custom errors in the browser
      raise
    end

    private

    def get_real_file(path)
      @watch_directories.each do |directory|
        file = File.join(directory, path)
        return file if File.file? file
      end
      nil
    end

    def get_asset(to_path)
      asset = @cached_assets[to_path]
      if asset
        mtime = asset.mtime
        latest = latest_mtime_of_type(asset.from_type)
        if latest > mtime
          invalidate_all_assets_of_type(asset.from_type)
          return get_asset(to_path)
        end
      else
        begin
          asset = get_uncached_asset(to_path)
        rescue Error
          return nil
        end
        @cached_assets[to_path] = asset
      end
      asset
    end

    def latest_mtime_of_type(type)
      latest = Time.at(0)
      @watch_directories.each do |directory|
        Dir[File.join(directory, "**/*.#{type}")].each do |file|
          mtime = File.stat(file).mtime
          latest = mtime if mtime > latest
        end
      end
      latest
    end

    def get_uncached_asset(to_path)
      from_path, conversion = find_source_file_and_conversion(to_path)
      # If we reach this point we've found the asset we're going to compile
      conversion.require_dependency unless @conversions_used.include? conversion
      @conversions_used << conversion
      # TODO: log at info: compiling asset ...
      contents = conversion.convert(File.read(from_path))
      length = File.stat(from_path).size
      mtime = latest_mtime_of_type(conversion.from_type)
      content_type = conversion.content_type
      return Asset.new from_path, to_path, conversion.from_type, conversion.to_type,
                       [contents], contents.length, mtime, content_type
    end

    def find_source_file_and_conversion(to_path)
      path, dot, suffix = to_path.rpartition(".")
      conversions = Conversion.conversions_for(suffix.to_sym)
      raise Error, "No conversion for for #{to_path}" if conversions.empty?
      @watch_directories.each do |directory|
        conversions.each do |conversion|
          Dir[File.join(directory, "#{path}.#{conversion.from_type}")].each do |from_path|
            return [from_path, conversion]
          end
        end
      end
      raise Error, "No source file found for #{to_path}"
    end

    def invalidate_all_assets_of_type(type)
      @cached_assets.delete_if { |to_path, asset| asset.from_type == type }
    end

    def with_content_length(response)
      status, headers, body = response
      [status, headers.merge({ "Content-Length" => Rack::Utils.bytesize(body).to_s }), body]
    end

    def update_asset(asset)
    end

    def start
      @running = true
      # TODO: mad threadz
      # Start a thread with an FSSM watch on each directory. Upon detecting a change to a compiled file that
      # is a dependency of any asset in @required_assets, call update_asset for each affected asset.
      #
      # There are some tricky threading issues here.
    end
  end
end
