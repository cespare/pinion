# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "pinion/version"

Gem::Specification.new do |s|
  s.name        = "pinion"
  s.version     = Pinion::VERSION
  s.authors     = ["Caleb Spare"]
  s.email       = ["cespare@gmail.com"]
  s.homepage    = "https://github.com/ooyala/pinion"
  s.summary     = %q{Pinion compiles and serves your assets}
  s.description =<<-EOS
Pinion is a Rack application that you can use to compile and serve assets (such as Javascript and CSS).
EOS

  s.rubyforge_project = "pinion"

  s.files         = Dir["README.md", "lib/**/*.rb"]
  s.require_paths = ["lib"]

  s.add_dependency "rack", "~> 1.0"

  s.add_development_dependency "rake"
  s.add_development_dependency "yard"

  # For tests
  s.add_development_dependency "scope"
  s.add_development_dependency "rack-test"
  s.add_development_dependency "coffee-script"
  s.add_development_dependency "dedent"
end
