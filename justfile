#!/usr/bin/env just --justfile

# Always require bash. If we allow it to be default, it may work incorrectly on Windows
set shell := ["bash", "-c"]

# if maplibre-native/docker/.cache/use-docker exists, use docker for all commands
docker_cmd := if path_exists("maplibre-native/docker/.cache/use-docker") != "true" { "" } else {
    'docker run --rm -it -v "$PWD:/app/" -v "$PWD/docker/.cache:/home/user/.cache" maplibre-native-image'
}
just_cmd := "cd maplibre-native && " + docker_cmd

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
clone:
    if [[ -d "maplibre-native" ]]; then \
        echo "maplibre-native/ sub-dir already exists" ;\
        exit 0 ;\
    fi
    git clone --recurse-submodules -j8 --origin upstream https://github.com/maplibre/maplibre-native.git

# interactively clean-up git repository, keeping IDE files
git-clean:
    cd maplibre-native && git clean -dxfi -e .idea -e .clwb -e .vscode

# (re-)build `maplibre-native-image` docker image for the current user
@init-docker:
    cd maplibre-native && docker build -t maplibre-native-image --build-arg USER_UID=$(id -u) --build-arg USER_GID=$(id -g) -f docker/Dockerfile docker
    touch maplibre-native/docker/.cache/use-docker
    echo ""
    echo "Docker has been initialized, all build commands will run with it. Run 'just status-docker' to check"

# run a command with docker, e.g. `just docker bazel build //:mbgl-core`, or open docker shell with `just docker`
docker *ARGS:
    @if [ '{{docker_cmd}}' == '' ]; then \
      echo "Docker is not initialized. You must first run   just init-docker" ;\
      exit 1 ;\
    fi
    {{just_cmd}} {{ARGS}}

# Initialize cmake build directory, possibly with docker if initialized
init-cmake:
    {{just_cmd}} cmake -B build -GNinja -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_BUILD_TYPE=RelWithDebInfo -DMLN_WITH_CLANG_TIDY=OFF -DMLN_WITH_COVERAGE=OFF -DMLN_DRAWABLE_RENDERER=ON -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON

# Run `cmake --build` with the given target, possibly with docker if initialized
cmake-build TARGET="mbgl-render":
    @if [[ ! -d "maplibre-native/build" ]]; then \
      {{just_executable()}} init-cmake ;\
    fi
    {{just_cmd}} cmake --build build --target {{quote(TARGET)}} -j $(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null)

# Run `bazel build` with the given target, possibly with docker if initialized
bazel-build TARGET="mbgl-core":
    {{just_cmd}} bazel build '//:{{TARGET}}'

# Creates and opens Xcode project for iOS
[macos]
xcode:
    cd maplibre-native && \
    bazel run //platform/ios:xcodeproj --@rules_xcodeproj//xcodeproj:extra_common_flags="--//:renderer=metal" && \
    xed platform/ios/MapLibre.xcodeproj
