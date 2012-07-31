module Pinion
  def self.environment() (defined?(RACK_ENV) && RACK_ENV) || ENV["RACK_ENV"] || "development" end
end
