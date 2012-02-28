require "sinatra"
require "slim"

class HelloApp < Sinatra::Base
  enable :inline_templates

  get "/" do
    slim :index
  end
end

__END__

@@ index
doctype html
html
  head
    link type="text/css" rel="stylesheet" href="/assets/style.css"
    script src="/assets/uncompiled.js"
    title Sample App
  body
    h3 Hello there! This text should be dark green.
