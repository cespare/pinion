$:.unshift File.join(File.dirname(__FILE__), "../lib")

require "pinion"
require "./app.rb"

map "/assets" do
  server = Pinion::Server.new
  server.convert :scss => :css
  server.watch "scss"
  run server
end

map "/" do
  run HelloApp.new
end
