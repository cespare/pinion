require File.join(File.dirname(__FILE__), "../integration_test_helper.rb")

require "fileutils"
require "dedent"
require "digest/md5"

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
          expected_body = %Q{console.log("hi!");\n}
          assert_equal expected_body, last_response.body
          assert_equal expected_body.length, last_response.header["Content-Length"].to_i
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

        #should "set a cache control policy to not cache" do
          #get "/assets/app.js"
          #assert_equal "public, must-revalidate", last_response.headers["Cache-Control"]
        #end
      end

      context "compiled files" do
        should "be compiled correctly and served with the correct content length" do
          get "/assets/util.js"
          assert_equal 200, last_response.status
          expected_body = <<-EOS.dedent
            (function() {
              console.log("util");
            }).call(this);
          EOS
          expected_body << "\n"
          assert_equal expected_body, last_response.body
          assert_equal expected_body.length, last_response.header["Content-Length"].to_i
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
    end

    context "in production mode" do
      setup do
        ENV["RACK_ENV"] = "production"
        @server = server
        @@app = server_app(@server)
      end

      context "static files" do
        setup do
          @file_body = %Q{console.log("hi!");\n}
          @md5 = Digest::MD5.hexdigest(@file_body)
          @url = "/assets/app-#{@md5}.js"
        end

        should "be served unchanged and with the correct content length" do
          get @url
          assert_equal 200, last_response.status
          assert_equal @file_body, last_response.body
          assert_equal @file_body.length, last_response.header["Content-Length"].to_i
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

        #should "set a cache control policy to not cache" do
          #get @url
          #assert_equal "public, must-revalidate", last_response.headers["Cache-Control"]
        #end
      end

      context "compiled files" do
        setup do
          @file_body = <<-EOS.dedent
            (function() {
              console.log("util");
            }).call(this);
          EOS
          @file_body << "\n"
          @md5 = Digest::MD5.hexdigest(@file_body)
          @url = "/assets/util-#{@md5}.js"
        end

        should "be compiled correctly and served with the correct content length" do
          get @url
          assert_equal 200, last_response.status
          assert_equal @file_body, last_response.body
          assert_equal @file_body.length, last_response.header["Content-Length"].to_i
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
    end
  end
end
