$:.unshift File.join(File.dirname(__FILE__), "../lib")

require "./app.rb"

map HelloApp.pinion.mount_point do
  run HelloApp.pinion
end

map "/" do
  run HelloApp
end
