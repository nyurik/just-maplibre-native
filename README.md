Helper utilities to develop [MapLibre Native](https://github.com/maplibre/maplibre-native) code.  The actual `maplibre-native` repo would be a subdirectory under this one (but not a sub-module to avoid various build and clone issues).  This justfile should be living in the MapLibre Native repo, but the maintainers feel a [bit uncertain](https://github.com/maplibre/maplibre-native/pull/2653) about it for now, so keeping it separate. 

| Example recipes (the list might not be up to date) |
|----------------------------------------------------|
| ![just-info.png](just-info.png)                    |

* Clone this repo
* Install [just](https://github.com/casey/just#readme), a modern alternative to `make`.  Must be version 1.33 or later.
* If you already have a local clone of [maplibre-native](https://github.com/maplibre/maplibre-native), move it as a sub-dir of this one.
* If not, run `mkdir -p maplibre-native && just clone` to clone that repo with submodules to `./maplibre-native`.
  * **NOTE** `maplibre-native` directory must exist before running any `just` commands, even to clone a repo into it.
* Run `just` to see the list of available commands.
* To use Docker, run `just init-docker` to initialize the Docker container. All subsequent cmake and bazel commands will use docker.

# FAQ
* if you see `error: Recipe ... could not be run because just could not find the shell: No such file or directory (os error 2)`, you need to create an empty `maplibre-native` directory and run `just clone` to clone the repo.
