require "sinatra"
require "slim"
require "pinion"
require "pinion/sinatra_helpers"

class HelloApp < Sinatra::Base
  set :pinion, Pinion::Server.new("/assets")

  configure do
    pinion.convert :scss => :css
    pinion.convert :coffee => :js
    pinion.watch "scss"
    pinion.watch "javascripts"

    pinion.create_bundle(:test_bundle, :concatenate_and_uglify_js, ["uncompiled.js", "compiled.js"])
  end

  enable :inline_templates

  helpers Pinion::SinatraHelpers

  get "/" do
    slim :index
  end
end

__END__

@@ index
doctype html
html
  head
    title Sample App
    == css_url("style.css")
    == js_bundle(:test_bundle)
  body
    h3 Hello there! This text should be dark green.
