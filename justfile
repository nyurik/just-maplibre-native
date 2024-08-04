#!/usr/bin/env just --justfile

# This command requires just v1.33+
set working-directory := 'maplibre-native'


# Always require bash. If we allow it to be default, it may work incorrectly on Windows
set shell := ["bash", "-c"]
set positional-arguments

# if maplibre-native/docker/.cache/use-docker exists, use docker for all commands
# otherwise this is a no-op, i.e. the command will run in the user's environment
# BUG workaround: https://github.com/casey/just/issues/2292
docker_cmd := if path_exists(join(justfile_directory(), "maplibre-native/docker/.cache/use-docker")) != "true" { "" } else {
    'docker run --rm -it -v "$PWD:/app/" -v "$PWD/docker/.cache:/home/user/.cache" maplibre-native-image'
}

[no-cd]
@_default:
    {{just_executable()}} --list

# Print if docker is initialized or not
@status-docker:
    if [ '{{docker_cmd}}' == '' ]; then \
      echo "Docker is not initialized, will build directly on the host" ;\
    else \
      echo "Docker is initialized, will use it for all build commands" ;\
    fi

# Clone maplibre-native repository with all submodules if it doesn't already exist
[no-cd]
[no-exit-message]
clone:
    #!/usr/bin/env bash
    set -euo pipefail
    cd {{quote(justfile_directory())}}
    # check if dir exists and is not empty
    if [ -d "maplibre-native" ] && [ "$(ls -A maplibre-native)" ]; then
      echo "maplibre-native directory already exists and is not empty"
      exit 1
    fi
    # git clone will clone into an existing directory if that directory is empty
    git clone --recurse-submodules -j8 --origin upstream https://github.com/maplibre/maplibre-native.git

# interactively clean-up git repository, keeping IDE files
[no-exit-message]
git-clean:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -n "$(git status -u --porcelain)" ]; then
      echo 'GIT repo is not clean. Commit needed changes and/or reset to clean state with  `git reset --hard`'
      exit 1
    fi
    git clean -dxfi -e .idea -e .clwb -e .ijwb -e .vscode -e platform/darwin/bazel/config.bzl

# (re-)build `maplibre-native-image` docker image for the current user
@init-docker:
    docker build -t maplibre-native-image --build-arg USER_UID=$(id -u) --build-arg USER_GID=$(id -g) -f docker/Dockerfile docker
    touch docker/.cache/use-docker
    echo ""
    echo "Docker has been initialized, all build commands will run with it. Run 'just status-docker' to check"

# run a command with docker, e.g. `just docker bazel build //:mbgl-core`, or open docker shell with `just docker`
docker *ARGS:
    @if [ '{{docker_cmd}}' == '' ]; then \
      echo "Docker is not initialized. You must first run   just init-docker" ;\
      exit 1 ;\
    fi
    {{docker_cmd}} {{ARGS}}

# Initialize cmake build directory, possibly with docker if initialized
init-cmake:
    {{docker_cmd}} cmake -B build -GNinja -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_BUILD_TYPE=RelWithDebInfo -DMLN_WITH_CLANG_TIDY=OFF -DMLN_WITH_COVERAGE=OFF -DMLN_DRAWABLE_RENDERER=ON -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON

# Run `cmake --build` with the given target, possibly with docker if initialized
cmake-build TARGET="mbgl-render":
    @if [[ ! -d "build" ]]; then \
      {{just_executable()}} init-cmake ;\
    fi
    {{docker_cmd}} cmake --build build --target {{quote(TARGET)}} -j $(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null)

# Run `bazel build` with the given arguments, possibly with docker if initialized
bazel-build *ARGS="//:mbgl-core":
    {{docker_cmd}} bazel build "$@"

# Creates and opens Xcode project for iOS
[macos]
xcode:
    bazel run //platform/ios:xcodeproj \
          --@rules_xcodeproj//xcodeproj:extra_common_flags="--//:renderer=metal" \
      && xed platform/ios/MapLibre.xcodeproj
