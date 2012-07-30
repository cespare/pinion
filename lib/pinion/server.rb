require "pinion/asset"
require "pinion/conversion"
require "pinion/directory_watcher"
require "pinion/error"

module Pinion
  class Server
    # TODO: is there a way to figure out the mount point ourselves? The only way I can find would be to wait
    # for a request and compare REQUEST_PATH to PATH_INFO, but that's super hacky and won't work anyway
    # because we need that information before requests are handled due to #asset_url
    def initialize(mount_point)
      @mount_point = mount_point
      @environment = (defined?(RACK_ENV) && RACK_ENV) || ENV["RACK_ENV"] || "development"
      @watcher = DirectoryWatcher.new ".", :static => (@environment == "production")
      @cached_assets = {}
    end

    def convert(from_and_to, &block)
      unless from_and_to.is_a?(Hash) && from_and_to.size == 1
        raise Error, "Unexpected argument to convert: #{from_and_to.inspect}"
      end
      from, to = from_and_to.to_a[0]
      unless [from, to].all? { |s| s.is_a? String }
        raise Error, "Expecting strings in this hash #{from_and_to.inspect}"
      end
      if block_given?
        # Save new conversion type (this might overwrite an implicit or previously defined conversion)
        Conversion.create(from_and_to) do
          render { |file_contents| block.call(file_contents) }
        end
      else
        unless Conversion[from_and_to]
          raise Error, "No implicit conversion for #{from_and_to.inspect}. Must provide a conversion block."
        end
      end
    end

    def watch(path)
      raise Error, "#{path} is not a directory." unless File.directory? path
      @watcher << path
      Conversion.add_watch_directory path
    end

    # Boilerplate mostly stolen from sprockets
    # https://github.com/sstephenson/sprockets/blob/master/lib/sprockets/server.rb
    def call(env)
      # Avoid modifying the session state, don't set cookies, etc
      env["rack.session.options"] ||= {}
      env["rack.session.options"].merge! :defer => true, :skip => true

      root = env["SCRIPT_NAME"]
      path = Rack::Utils.unescape(env["PATH_INFO"].to_s).sub(%r[^/], "")

      if path.include? ".."
        return [403, { "Content-Type" => "text/plain", "Content-Length" => "9" }, ["Forbidden"]]
      end

      # Pull out the md5sum if it's part of the given path
      # e.g. foo/bar-a95c53a7a0f5f492a74499e70578d150.js -> a95c53a7a0f5f492a74499e70578d150
      checksum_tag = path[/-([\da-f]{32})\..+$/, 1]
      path.sub!("-#{checksum_tag}", "") if checksum_tag

      asset = find_asset(path)

      if asset
        # If the ETag matches, give a 304
        return [304, {}, []] if env["HTTP_IF_NONE_MATCH"] == %Q["#{asset.checksum}"]

        # Cache for a year in production; don't cache in dev
        cache_policy = checksum_tag ? "max-age=31536000" : "must-revalidate"
        headers = {
          "Content-Type" => asset.content_type || "",
          "Content-Length" => asset.length.to_s,
          "ETag" => %Q["#{asset.checksum}"],
          "Cache-Control" => "public, #{cache_policy}",
          "Last-Modified" => asset.mtime.httpdate,
        }
        return [200, headers, []] if env["REQUEST_METHOD"] == "HEAD"
        [200, headers, asset]
      else
        [404, { "Content-Type" => "text/plain", "Content-Length" => "9" }, ["Not found"]]
      end
    rescue Exception => e
      # TODO: logging
      STDERR.puts "Error compiling #{path}:"
      STDERR.puts "#{e.class.name}: #{e.message}"
      # TODO: render nice custom errors in the browser
      raise
    end

    # Helper methods for an application to generate urls (with fingerprints in production)
    def asset_url(path)
      path.sub!(%r[^(#{@mount_point})?/?], "")
      mounted_path = "#{@mount_point}/#{path}"

      # TODO: Change the real file behavior if I replace the use of Rack::File above
      return mounted_path if @watcher.find(path)

      return mounted_path unless @environment == "production"

      # Add on a checksum tag in production
      asset = find_asset(path)
      raise "Error: no such asset available: #{path}" unless asset
      mounted_path, dot, extension = mounted_path.rpartition(".")
      return mounted_path if dot.empty?
      "#{mounted_path}-#{asset.checksum}.#{extension}"
    end
    def css_url(path) %Q{<link type="text/css" rel="stylesheet" href="#{asset_url(path)}" />} end
    def js_url(path) %Q{<script src="#{asset_url(path)}"></script>} end

    private

    def find_asset(to_path)
      asset = @cached_assets[to_path]
      if asset
        return asset if @environment == "production"
        if @watcher.latest_mtime > asset.mtime
          @cached_assets.clear
          return find_asset(to_path)
        end
      else
        asset = find_uncached_asset(to_path)
        @cached_assets[to_path] = asset
      end
      asset
    end

    def find_uncached_asset(to_path)
      from_path, conversions = find_source_file_and_conversions(to_path)
      # If we reach this point we've found the asset we're going to compile
      # TODO: log at info: compiling asset ...
      Asset.new from_path, to_path, conversions
    end

    def find_source_file_and_conversions(to_path)
      from_path = @watcher.find to_path
      return [from_path, []] if from_path
      conversions = Conversion.conversions_for(to_path)
      raise Error, "No conversion for #{to_path}" if conversions.empty?
      conversions.each do |conversion|
        filename = "#{to_path[0..to_path.rindex("."+conversion.to_type)-1]}.#{conversion.from_type}"
        from_path, prev_conversions = find_source_file_and_conversions(filename) rescue next
        return [from_path, prev_conversions+[conversion]]
      end
      raise Error, "No source file found for #{to_path}"
    end

    def with_content_length(response)
      status, headers, body = response
      [status, headers.merge({ "Content-Length" => Rack::Utils.bytesize(body).to_s }), body]
    end
  end
end
