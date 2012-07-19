Pinion
======

Pinion is a Rack application that serves assets, possibly transforming them in the process. It is generally
useful for serving Javascript and CSS, and things that compile to Javascript and CSS such as Coffeescript and
Sass.

Goals
=====

There are a lot of tools that accomplish very similar things in this space. Pinion is meant to be a very
simple and lightweight solution. It is driven by these core goals (bold goals are implemented):

* **Simple configuration and usage.**
* **No added syntax to your assets (e.g. no `//= require my_other_asset`)**
* **Recompile all compiled assets when they change (or dependencies change) in development and set mtimes**
* Recompile asynchronously from requests (no polling allowed)
* **Compile assets one time in production**

Installation
============

    $ gem install pinion

You should add pinion to your project's Gemfile.

Usage
=====

The easiest way to use Pinion is to map your desired asset mount point to a `Pinion::Server` instance in your
`config.ru`.

``` ruby
require "pinion"
require "your_app.rb"

MOUNT_POINT = "/assets"
pinion = Pinion::Server.new(MOUNT_POINT)
# Tell Pinion each type of conversion it should perform
pinion.convert :scss => :css # Sass and Coffeescript will just work if you have the gems installed
pinion.convert :coffee => :js # Conversion types correspond to file extensions. .coffee -> .js
pinion.convert :styl => :css do |file_contents|
  Stylus.compile file_contents # Requires the stylus gem
end
# Tell Pinion the paths to watch
pinion.watch "public/javascripts"
pinion.watch "public/scss"
pinion.watch "public/stylus"

map MOUNT_POINT do
  # Boom
  run pinion
end

map "/" do
  # You should pass pinion into your app in order to use its helper methods.
  run Your::App.new(pinion)
end
```

In your app, you will use pinion's helper methods to construct urls:

``` erb
<head>
  <title>My App</title>
  <link type="text/css" rel="stylesheet" href="<%= pinion.asset_url("/assets/style.css") %>" />
  <!-- Shorthand equivalent -->
  <%= pinion.css_url("style.css") %>
</head>
```

Notes
-----

* Currently, Pinion sidesteps the dependency question by invalidating its cache of each file of a particular
  type (say, all `.scss` files) when any such source file is changed.
* The order that paths are added to the watch list is a priority order in case of conflicting assets. (For
  intance, if `foo/bar` and `foo/baz` are both on the watch list, and both of the files `foo/bar/style.scss`
  and `foo/baz/style.scss` exist, then `foo/bar/style.scss` will be used if a request occurs for
  `/style.css`.)

You can see an example app using Pinion and Sinatra in the `example/` directory.

Authors
=======

Pinion was written by Caleb Spare ([cespare](https://github.com/cespare)). Inspiration from
[sprockets](https://github.com/sstephenson/sprockets).

License
=======

Pinion is released under [the MIT License](http://www.opensource.org/licenses/mit-license.php).
