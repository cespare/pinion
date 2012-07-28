require "minitest/autorun"
require "scope"
require "rack/test"

# Add the lib directory and root dir to the load path
$:.unshift(".")
$:.unshift("lib/")
