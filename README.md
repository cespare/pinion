# Pinion

Pinion is a Rack application that serves assets, possibly transforming them in the process. It is generally
useful for serving Javascript and CSS, and things that compile to Javascript and CSS such as Coffeescript and
Sass.

# Goals

There are a lot of tools that accomplish very similar things in this space. Pinion is meant to be a very
simple and lightweight solution. It is driven by these core goals (bold goals are implemented):

* **Simple configuration and usage.**
* **No added syntax to your assets (e.g. no `//= require my_other_asset`)**
* **Recompile all compiled assets when they change (or dependencies change) in development and set mtimes**
* Recompile asynchronously from requests (no polling allowed)
* **Compile assets one time in production**

# Installation

    $ gem install pinion

You should add pinion to your project's Gemfile.

# Usage

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
  <%# Shorthand equivalent %>
  <%= pinion.css_url("style.css") %>
</head>
```

# Production usage

In production, you may wish to concatenate and minify your assets before you serve them. This is done through
using asset bundles. Pinion provides a predefined bundle type, `:concatenate_and_uglify_js`, for your
convenience.

You can bundle files by putting this in your app:

``` erb
<%= @pinion.js_bundle(:concatenate_and_uglify_js, "main-bundle",
    "app.js",
    "helpers.js",
    "util.js",
    "jquery.js"
    ) %>
```

In development, the individual `<script>` tags for each asset will be emitted; in production, a single asset
(`main-bundle.js`) will be produced.

The `:concatenate_and_uglify_js` bundle type simply concatenates JS files and runs them through
[Uglifier](https://github.com/lautis/uglifier). No default CSS bundle type is provided (but the built-in Sass
conversion type emits minified code in production, and typically you'll let Sass/Less/Stylus handle
concatenation for you).

You can define your own bundle types and their behavior if you like:

``` ruby
# The block is passed an array of `Pinion::Asset`s; it should return the content of the bundled files.
Pinion::BundleType.create(:concatenate_js_only) do |assets|
  # Demo code only; you need to be a bit more careful in reality. See the definition of
  # :concatenate_and_uglify_js for hints.
  assets.map(&:contents).join("\n")
end
```

Note that in production mode, asset URLs will have the md5sum of the asset inserted into them:

``` html
<link type="text/css" rel="stylesheet" href="/assets/style-698f462d2f43890597ae78df8286d03f.css" />
<script src="/assets/test-bundle-cd94852076ffa13c006cf575dfff9e35.js"></script>
```

and these assets are served with long (1-year) expiry, for good cacheability.

# Notes

* Currently, Pinion sidesteps the dependency question by invalidating its cache of each file of a particular
  type (say, all `.scss` files) when any such source file is changed.
* The order that paths are added to the watch list is a priority order in case of conflicting assets. (For
  intance, if `foo/bar` and `foo/baz` are both on the watch list, and both of the files `foo/bar/style.scss`
  and `foo/baz/style.scss` exist, then `foo/bar/style.scss` will be used if a request occurs for
  `/style.css`.)

You can see an example app using Pinion and Sinatra in the `example/` directory. Run `bundle install` in that
directory to get the necessary gems, then run it:

    rackup config.ru                     # Development mode
    RACK_ENV=production rackup config.ru # Production mode

# Authors

Pinion was written by Caleb Spare ([cespare](https://github.com/cespare)). Inspiration from
[sprockets](https://github.com/sstephenson/sprockets).

Contributions from:

* Alek Storm ([alekstorm](https://github.com/alekstorm))

# License

Pinion is released under [the MIT License](http://www.opensource.org/licenses/mit-license.php).
