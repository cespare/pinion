require "sinatra"
require "slim"

class HelloApp < Sinatra::Base
  enable :inline_templates

  def initialize(pinion)
    @pinion = pinion
    super()
  end

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
    == @pinion.css_url("style.css")
    == @pinion.js_bundle(:concatenate_and_uglify_js, "test-bundle", "uncompiled.js", "compiled.js")
  body
    h3 Hello there! This text should be dark green.
