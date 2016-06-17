**NOTE: I neither use nor maintain this project anymore.**

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

Pinion is intended to be easy to set up and use with any Rack app, and even simpler with Sinatra.

## With Sinatra

Pinion provides helpers to make it interact well with Sinatra. In your app:

``` ruby
require "sinatra"
require "pinion"
require "pinion/sinatra_helpers"

class YourApp < Sinatra::Base
  set :pinion, Pinion::Server.new("/assets")

  configure do
    # Tell Pinion each type of conversion it should perform:
    # * Sass and Coffeescript will just work if you have the gems installed
    # * Conversion types correspond to file extensions. .coffee -> .js
    pinion.convert :scss => :css
    pinion.convert :coffee => :js
    pinion.convert :styl => :css do |file_contents|
      Stylus.compile file_contents # Requires the stylus gem
    end
    # Tell Pinion the paths to watch for files
    pinion.watch "public/javascripts"
    pinion.watch "public/scss"
    pinion.watch "public/stylus"
  end

  helpers Pinion::SinatraHelpers
  ...
end
```

and your config.ru:

``` ruby
require "your_app.rb"

map YourApp.pinion.mount_point do
  run YourApp.pinion
end

map "/" do
  run YourApp
end
```

## Without Sinatra

If you're not using Sinatra, the easiest way to use Pinion is to create and mount a `Pinion::Server` instance
in your `config.ru`.

``` ruby
require "pinion"
require "your_app.rb"

MOUNT_POINT = "/assets"
pinion = Pinion::Server.new(MOUNT_POINT)
# Tell Pinion each type of conversion it should perform:
# * Sass and Coffeescript will just work if you have the gems installed
# * Conversion types correspond to file extensions. .coffee -> .js
pinion.convert :scss => :css
pinion.convert :coffee => :js
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
  # If you want to use Pinion's helper methods inside your app, you'll have to pass in the Pinion instance to
  # the app somehow.
  run Your::App.new(pinion)
end
```

## App helpers

Pinion provides some helpers to help you construct links for assets.

``` erb
<head>
  <title>My App</title>
  <link type="text/css" rel="stylesheet"
        href="<%= pinion.asset_url("/assets/style.css") %>" />
  <%# Shorthand equivalent %>
  <%= pinion.css_url("style.css") %>
</head>
```

This assumes that you have the `Pinion::Server` instance available inside your app as `pinion`. If you're
using Sinatra and `Pinion::SinatraHelpers`, then the helpers are available right in your app's scope:

``` erb
<%= css_url("style.css") %>
```

## In Production

In production, you may wish to concatenate and minify your assets before you serve them. This is done through
using asset bundles. Pinion provides a predefined bundle type, `:concatenate_and_uglify_js`, for your
convenience.

You will create bundles when you set up your `Pinion::Server` instance:

``` ruby
pinion.create_bundle(:main_bundle,
                     :concatenate_and_uglify_js,
                     ["app.js", "util.js", "jquery.js"])
```

In this case, `:main_bundle` is an identifier for this bundle, and will the name under which this bundle is
served. In your view, you will use the bundle similarly to how you use the `js_url` or `css_url` helpers:

``` erb
<%= js_bundle(:main_bundle) %>
```

In development, the individual `<script>` tags for each asset will be emitted; in production, a single
asset (`main-bundle.js`) will be produced.

The `:concatenate_and_uglify_js` bundle type simply concatenates JS files and runs them through
[Uglifier](https://github.com/lautis/uglifier). No default CSS bundle type is provided (but the built-in Sass
conversion type emits minified code in production, and typically you'll let Sass/Less/Stylus handle
concatenation for you).

You can define your own bundle types and their behavior if you like:

``` ruby
# The block is passed an array of `Pinion::Asset`s; it should return the content
# of the bundled files.
Pinion::BundleType.create(:concatenate_js_only) do |assets|
  # Demo code only; you need to be a bit more careful in reality. See the
  # definition of :concatenate_and_uglify_js for hints.
  assets.map(&:contents).join("\n")
end
```

Note that in production mode, asset URLs will have the md5sum of the asset inserted into them:

``` html
<link type="text/css" rel="stylesheet"
      href="/assets/style-698f462d2f43890597ae78df8286d03f.css" />
<script src="/assets/test-bundle-cd94852076ffa13c006cf575dfff9e35.js"></script>
```

and these assets are served with long (1-year) expiry, for good cacheability.

# Example

You can see an example app using Pinion and Sinatra in the `example/` directory. This app shows serving some
static and compiled assets as well as a simple asset bundle. Run `bundle install` in that directory to get the
necessary gems, then run it:

    rackup config.ru                     # Development mode
    RACK_ENV=production rackup config.ru # Production mode

# Notes

* Currently, Pinion sidesteps the dependency question by invalidating its cache of each file of a particular
  type (say, all `.scss` files) when any such source file is changed.
* The order that paths are added to the watch list is a priority order in case of conflicting assets. (For
  intance, if `foo/bar` and `foo/baz` are both on the watch list, and both of the files `foo/bar/style.scss`
  and `foo/baz/style.scss` exist, then `foo/bar/style.scss` will be used if a request occurs for
  `/style.css`.)
* If you don't use the url helpers provided by Pinion and instead just serve assets with a plain url (that is,
  without a checksum in the url), Pinion will serve the assets with 10-minute expiry in the Cache-Control
  header. In general, you should try to serve all your assets by using the urls given by the helpers.

## Why not use Sprockets?

You should! [Sprockets](https://github.com/sstephenson/sprockets/) is a great project. Pinion is a smaller
project than Sprockets, and it does fewer things. I made Pinion because I'm not using Rails (the Rails
integration is where Sprockets really shines) and because some of the design choices that Sprockets makes
don't really fit my ideal workflow. Here are a few things that Pinion does differently:

* Conversions are defined from one filetype to another (e.g. `:scss => :css`), not by the chain of file
  extensions (e.g. `foo.css.scss`). I like the asset manager to follow the file naming scheme, not the other
  way around.
* It's very easy to define your own conversions instead of using the built-in ones (and this is expected, as
  Pinion only comes with a few of them). This makes it very simple to customize the behavior for your own
  needs. Want to output minified css in production but a human-readable version in dev? This is easy to do
  (and this is the default behavior of the built-in sass/scss converters).
* To support concatenation, Sprockets uses special directives in comments at the beginning of files (e.g.
  `//= require jquery`) to specify dependencies between files. To my mind, this is not desirable because:

    * It's easier to debug in development if the files aren't all concatenated together.
    * Other systems (say, a node.js-based JS test runner) don't understand these dependencies.
    * How you bundle assets is mostly a caching/performance concern separate from your app logic, so it
      doesn't necessarily make sense to tie them together. For instance, you may wish to bundle together your
      vendored JS separately from your application JS if you expect the latter to change much more frequently.

  In contrast, Pinion bundles are created by using the `*_bundle` methods in your app server (view) code,
  which (in my opinion) is much more obvious behavior.

This being said, you should certainly consider using Sprockets if it fits into your project. It is a very
established project that powers the Rails asset pipeline, and it has great support for a wide variety of
conversion types. If you use both, let me know what you think!

# Authors

Pinion was written by Caleb Spare ([cespare](https://github.com/cespare)). Inspiration from
[sprockets](https://github.com/sstephenson/sprockets).

Contributions from:

* Alek Storm ([alekstorm](https://github.com/alekstorm))

# License

Pinion is released under [the MIT License](http://www.opensource.org/licenses/mit-license.php).
