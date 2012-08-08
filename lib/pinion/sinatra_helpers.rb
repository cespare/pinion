module Pinion
  # Set up Pinion in your sinatra app:
  #
  #     set :pinion, Pinion::Server.new("/assets")
  #     configure do
  #       pinion.convert :scss => :css
  #       pinion.watch "public/css"
  #     end
  #
  # then mix in in this module in your sinatra app:
  #
  #     helpers Pinion::SinatraHelpers
  #
  # Now you can access the Pinion::Server helper methods in your view:
  #
  #     <head>
  #       <%= css_url "style.css" %>
  #     </head>
  module SinatraHelpers
    [:asset_url, :css_url, :js_url, :asset_inline, :css_inline, :js_inline, :bundle_url, :js_bundle,
     :css_bundle].each do |helper|
      define_method helper do |*args|
        settings.pinion.send(helper, *args)
      end
    end
  end
end
