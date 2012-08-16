require "pinion/asset"
require "pinion/bundle"
require "pinion/compiled_asset"
require "pinion/conversion"
require "pinion/environment"
require "pinion/error"
require "pinion/static_asset"

module Pinion
  class Server
    attr_reader :mount_point

    def initialize(mount_point)
      @mount_point = mount_point
      # This is a cache of bundle_name => <List of Paths in the bundle>. The purpose of this is just to help
      # prevent people make the mistake of giving different bundles the same name. This could give confusing
      # behavior; by keeping track of it and checking each time we try to make a bundle, we'll be able to
      # throw a meaningful error message. Even in development, where bundles aren't actually created, we'll
      # keep track of this in order to prevent such mistakes.
      @created_bundles = {}
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
      Asset.watch_path(path)
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
      checksum_tag = bundle_name = nil
      matches = path.match /([^\/]+)-([\da-f]{32})\..+$/
      if matches && matches.size == 3
        bundle_name = matches[1]
        checksum_tag = matches[2]
        path.sub!("-#{checksum_tag}", "")
      end

      # First see if there is a bundle with this name
      asset = Bundle[bundle_name]
      if asset
        # If the checksum doesn't match the bundle, we want to return a 404.
        asset = nil unless asset.checksum == checksum_tag
      else
        # If there is no bundle with this name, find another type of Asset with the name instead.
        asset = Asset[path]
      end

      if asset
        # If the ETag matches, give a 304
        return [304, {}, []] if env["HTTP_IF_NONE_MATCH"] == %Q["#{asset.checksum}"]

        if Pinion.environment == "production"
          # In production, if there is a checksum, cache for a year (because if the asset
          # changes with a redeploy, the checksum will change). If there is no checksum, cache for 10 minutes
          # (this way at worst we only serve 10 minute stale assets, and caches in front of Pinion will be able
          # to help out).
          cache_policy = checksum_tag ? "max-age=31536000" : "max-age=600"
        else
          # Don't cache in dev.
          cache_policy = "must-revalidate"
        end
        headers = {
          "Content-Type" => asset.content_type,
          "Content-Length" => asset.length.to_s,
          "ETag" => %Q["#{asset.checksum}"],
          "Cache-Control" => "public, #{cache_policy}",
          "Last-Modified" => asset.mtime.httpdate,
        }
        body = env["REQUEST_METHOD"] == "HEAD" ? [] : asset
        [200, headers, body]
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

      return mounted_path unless Pinion.environment == "production"

      # Add on a checksum tag in production
      asset = Asset[path]
      raise "Error: no such asset available: #{path}" unless asset
      mounted_path, dot, extension = mounted_path.rpartition(".")
      return mounted_path if dot.empty?
      "#{mounted_path}-#{asset.checksum}.#{extension}"
    end
    def css_url(path) css_wrapper(asset_url(path)) end
    def js_url(path) js_wrapper(asset_url(path)) end

    def asset_inline(path) Asset[path].contents end
    def css_inline(path) %Q{<style type="text/css">#{asset_inline(path)}</style>} end
    def js_inline(path) %Q{<script>#{asset_inline(path)}</script>} end

    # Bundle several assets together. In production, the single bundled result is produced; otherwise, each
    # individual asset_url is returned.
    def bundle_url(bundle_name, name, *paths)
      # Remember each bundle we create. If we've previously created a bundle with the same type and name but
      # different files, then this is an unrecoverable error. This is performed even in development mode for
      # error-detection purposes.
      if @created_bundles[name]
        if @created_bundles[name] != paths
          raise "Error: there is already a bundle called #{name} with different component files. Each " <<
                "bundle must have a unique name."
        end
      else
        @created_bundles[name] = paths
      end

      # When we're not in production, emit each individual url.
      return paths.map { |p| asset_url(p) } unless Pinion.environment == "production"
      # First check to see if we've already made this bundle. We know from the @created_bundles check that if
      # the bundle exists, it was created with the same list of assets.
      bundle = Bundle[name]
      unless bundle
        assets = paths.map do |path|
          normalized_path = path.sub(%r[^(#{@mount_point})?/?], "")
          asset = Asset[normalized_path]
          raise "Error: no such asset available: #{path}" unless asset
          asset
        end
        bundle = Bundle.create(bundle_name, name, assets)
      end
      ["#{@mount_point}/#{bundle.name}-#{bundle.checksum}.#{bundle.extension}"]
    end
    def js_bundle(bundle_name, name, *paths)
      bundle_url(bundle_name, name, *paths).map { |path| js_wrapper(path) }.join
    end
    def css_bundle(bundle_name, name, *paths)
      bundle_url(bundle_name, name, *paths).map { |path| css_wrapper(path) }.join
    end

    private

    # Need type="text/javascript" for IE compatibility. The content-type will be set correctly as
    # "application/javascript" in the response.
    def js_wrapper(inner) %Q{<script type="text/javascript" src="#{inner}"></script>} end
    def css_wrapper(inner) %Q{<link type="text/css" rel="stylesheet" href="#{inner}" />} end

    def with_content_length(response)
      status, headers, body = response
      [status, headers.merge({ "Content-Length" => Rack::Utils.bytesize(body).to_s }), body]
    end
  end
end
