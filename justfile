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

@status-docker:
    if [ '{{docker_cmd}}' == '' ]; then \
      echo "Docker is not initialized, will build directly on the host" ;\
    else \
      echo "Docker is initialized, will use it for all build commands" ;\
    fi

# interactively clean-up git repository, keeping IDE files
git-clean:
    cd maplibre-native && git clean -dxfi -e .idea -e .clwb -e .vscode

# (re-)build `maplibre-native-image` docker image for the current user
@init-docker:
    cd maplibre-native && docker build -t maplibre-native-image --build-arg USER_UID=$(id -u) --build-arg USER_GID=$(id -g) -f docker/Dockerfile docker
    touch maplibre-native/docker/.cache/use-docker
    echo ""
    echo "Docker has been initialized, all build commands will run with it. Run 'just status-docker' to check"

# run command with docker, e.g. `just docker bazel build //:mbgl-core`, or open docker shell with `just docker`
docker *ARGS:
    if [ '{{docker_cmd}}' == '' ]; then \
      echo "Docker is not initialized. Run  just init-docker  first." ;\
      exit 1 ;\
    fi
    {{just_cmd}} {{ARGS}}


init-cmake:
    {{just_cmd}} cmake -B build -GNinja -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_BUILD_TYPE=RelWithDebInfo -DMLN_WITH_CLANG_TIDY=OFF -DMLN_WITH_COVERAGE=OFF -DMLN_DRAWABLE_RENDERER=ON -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON

cmake TARGET="mbgl-render":
    if [[ ! -d "maplibre-native/build" ]]; then \
      {{just_executable()}} init-cmake ;\
    fi
    {{just_cmd}} cmake --build build --target {{TARGET}} -j $(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null)

bazel TARGET="mbgl-core":
    {{just_cmd}} bazel build //:{{TARGET}}
