TODO
====

* Async recompilation (FSSM or something else?) in development
* Figure out if there is a better way to let Pinion know its mount point, and for the app to talk to pinion.
  **Idea:** Construct the `Pinion::Server` instance in the app. This should be a much better way.
* Move `find_asset` and friends to be `Asset` class methods.
