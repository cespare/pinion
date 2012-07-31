$:.unshift File.join(File.dirname(__FILE__), "../lib")

require "pinion"
require "./app.rb"

ASSET_MOUNT_POINT = "/assets"

pinion = Pinion::Server.new(ASSET_MOUNT_POINT)
pinion.convert :scss => :css
pinion.convert :coffee => :js
pinion.watch "scss"
pinion.watch "javascripts"

map ASSET_MOUNT_POINT do
  run pinion
end

map "/" do
  run HelloApp.new(pinion)
end
