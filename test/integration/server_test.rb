require File.join(File.dirname(__FILE__), "../integration_test_helper.rb")

require "fileutils"
require "dedent"
require "digest/md5"
require "coffee-script"

require "pinion/server"

module Pinion
  class ServerTest < Scope::TestCase
    include Rack::Test::Methods

    def server
      Server.new("/assets").tap do |s|
        s.watch "test/fixtures/js"
      end
    end

    def server_app(s)
      Rack::Builder.new do
        map("/assets") { run s }
      end
    end

    def app() @@app end

    setup do
      @static_file_body = %Q{console.log("hi!");\n}
      @static_file_length = @static_file_body.length
      @static_file_md5 = Digest::MD5.hexdigest(@static_file_body)

      uncompiled_contents = %Q{console.log "util"\n}
      @compiled_file_body = CoffeeScript.compile(uncompiled_contents)
      @compiled_file_md5 = Digest::MD5.hexdigest(@compiled_file_body)
      @compiled_file_length = @compiled_file_body.length

      # Create a very simple bundler that just concatenates
      BundleType.create(:js_concatenate) { |assets| assets.map(&:contents).join("\n") }
      @bundle_file_body = "#{@static_file_body}\n#{@compiled_file_body}"
      @bundle_file_length = @bundle_file_body.length
      @bundle_file_md5 = Digest::MD5.hexdigest(@bundle_file_body)
    end

    context "in development mode" do
      setup do
        ENV["RACK_ENV"] = "development"
        @server = server
        @@app = server_app(@server)
      end

      context "static files" do
        should "be served unchanged and with the correct content length" do
          get "/assets/app.js"
          assert_equal 200, last_response.status
          assert_equal @static_file_body, last_response.body
          assert_equal @static_file_length, last_response.header["Content-Length"].to_i
        end

        should "have the expected content-type" do
          get "/assets/app.js"
          assert_equal "application/javascript", last_response.headers["Content-Type"]
        end

        should "have the correct last-modified time set" do
          js_file = "test/fixtures/js/app.js"
          assert File.file?(js_file) # Make sure it exists before we go touching it
          FileUtils.touch(js_file)
          get "/assets/app.js"
          assert_in_delta Time.parse(last_response.headers["Last-Modified"]).to_i, Time.now.to_i, 3
        end

        should "set a cache control policy to not cache" do
          get "/assets/app.js"
          assert_equal "public, must-revalidate", last_response.headers["Cache-Control"]
        end
      end

      context "compiled files" do
        should "be compiled correctly and served with the correct content length" do
          get "/assets/util.js"
          assert_equal 200, last_response.status
          assert_equal @compiled_file_body, last_response.body
          assert_equal last_response.body.length, last_response.header["Content-Length"].to_i
        end

        should "have the expected content-type" do
          get "/assets/util.js"
          assert_equal "application/javascript", last_response.headers["Content-Type"]
        end

        should "have the correct last-modified time set" do
          coffee_file = "test/fixtures/js/util.coffee"
          assert File.file?(coffee_file) # Make sure it exists before we go touching it
          FileUtils.touch(coffee_file)
          get "/assets/util.js"
          assert_in_delta Time.parse(last_response.headers["Last-Modified"]).to_i, Time.now.to_i, 3
        end

        should "set a cache control policy to not cache" do
          get "/assets/util.js"
          assert_equal "public, must-revalidate", last_response.headers["Cache-Control"]
        end
      end

      context "bundles" do
        should "return the tags for individual files from the bundle helper" do
          js_bundle_tags = @server.js_bundle(:js_concatenate, "my-js-bundle", "/app.js", "/util.js")
          expected_html = '<script src="/assets/app.js"></script><script src="/assets/util.js"></script>'
          assert_equal expected_html, js_bundle_tags
        end
      end

      context "app helpers" do
        should "return the correct asset_url for a static asset" do
          assert_equal "/assets/app.js", @server.asset_url("/app.js")
        end

        should "return the correct asset_url for a compiled asset" do
          assert_equal "/assets/util.js", @server.asset_url("/util.js")
        end
      end
    end

    context "in production mode" do
      setup do
        ENV["RACK_ENV"] = "production"
        @server = server
        @@app = server_app(@server)
      end

      context "static files" do
        setup do
          @url = "/assets/app-#{@static_file_md5}.js"
        end

        should "be served unchanged and with the correct content length" do
          get @url
          assert_equal 200, last_response.status
          assert_equal @static_file_body, last_response.body
          assert_equal @static_file_length, last_response.header["Content-Length"].to_i
        end

        should "have the expected content-type" do
          get @url
          assert_equal "application/javascript", last_response.headers["Content-Type"]
        end

        # TODO: This test isn't going to work except in isolation (because the other tests that touch the file
        # will run before the Server instance we're using is created, so the mtimes will be right now). Figure
        # out a way to fix this while keeping the test fairly realistic.
        #should "not change the last-modified time if the file changes" do
          #js_file = "test/fixtures/js/app.js"
          #assert File.file?(js_file) # Make sure it exists before we go touching it
          #FileUtils.touch(js_file)
          #get @url
          #refute_in_delta Time.parse(last_response.headers["Last-Modified"]).to_i, Time.now.to_i, 3
        #end

        should "set a cache control policy to cache for a year" do
          get @url
          assert_equal "public, max-age=#{365 * 24 * 60 * 60}", last_response.headers["Cache-Control"]
        end
      end

      context "compiled files" do
        setup do
          @url = "/assets/util-#{@compiled_file_md5}.js"
        end

        should "be compiled correctly and served with the correct content length" do
          get @url
          assert_equal 200, last_response.status
          assert_equal @compiled_file_body, last_response.body
          assert_equal last_response.body.length, last_response.header["Content-Length"].to_i
        end

        should "have the expected content-type" do
          get @url
          assert_equal "application/javascript", last_response.headers["Content-Type"]
        end

        # TODO: This test isn't going to work except in isolation (because the other tests that touch the file
        # will run before the Server instance we're using is created, so the mtimes will be right now). Figure
        # out a way to fix this while keeping the test fairly realistic.
        #should "not change the last-modified time if the file changes" do
          #coffee_file = "test/fixtures/js/util.coffee"
          #assert File.file?(coffee_file) # Make sure it exists before we go touching it
          #FileUtils.touch(coffee_file)
          #get @url
          #refute_in_delta Time.parse(last_response.headers["Last-Modified"]).to_i, Time.now.to_i, 3
        #end

        should "set a cache control policy to cache for a year" do
          get @url
          assert_equal "public, max-age=#{365 * 24 * 60 * 60}", last_response.headers["Cache-Control"]
        end
      end

      context "bundles" do
        setup do
          @url = "/assets/my-js-bundle-#{@bundle_file_md5}.js"
        end

        should "return the bundled filename from the bundle helper" do
          js_bundle_tags = @server.js_bundle(:js_concatenate, "my-js-bundle", "/app.js", "/util.js")
          assert js_bundle_tags["my-js-bundle-#{@bundle_file_md5}.js"]
        end

        should "produce the expected bundled contents" do
          @server.js_bundle(:js_concatenate, "my-js-bundle", "/app.js", "/util.js")
          get @url
          assert_equal 200, last_response.status
          assert_equal @bundle_file_body, last_response.body
          assert_equal last_response.body.length, last_response.headers["Content-Length"].to_i
          assert_equal "application/javascript", last_response.headers["Content-Type"]
        end
      end

      context "app helpers" do
        should "return the correct asset_url for a static asset" do
          assert_equal "/assets/app-#{@static_file_md5}.js", @server.asset_url("/app.js")
        end

        should "return the correct asset_url for a compiled asset" do
          assert_equal "/assets/util-#{@compiled_file_md5}.js", @server.asset_url("/util.js")
        end
      end
    end
  end
end
