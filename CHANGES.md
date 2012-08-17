This a log of changes between Pinion versions (since 0.1.x).

### 0.3.0
* Change the way that bundles are created. v0.3.0 fixes a couple of big bugs with bundles in 0.2.2 (issues #5
  and #7).
* Set a reasonable cache-control even for assets without the checksum in the request path when in production
  mode (issue #6).
* Set `type="text/javascript"` in JS tags for IE compatibility (issue #4).

### 0.2.2
* Sinatra helpers for nicer Pinion/Sinatra synergy.

### 0.2.1
* In production mode, the builtin scss/sass converters will emit compressed CSS.

### 0.2.0
* Implement asset bundling
* Handle static files directly
* Inline assets (Pull request #1)
* Lots of refactoring
