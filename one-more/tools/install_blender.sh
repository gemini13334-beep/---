#!/usr/bin/env bash
set -euo pipefail
# Prefer the distro build when its exporter dependencies are usable.
if sudo apt-get update && sudo apt-get install -y blender python3-numpy python3-pil && blender -b --python-exit-code 1 --python-expr "import numpy; from io_scene_gltf2.blender.exp import export; print(numpy.__version__)"; then
  blender --version
  exit 0
fi
# Official portable LTS build, with bundled Python dependencies.
version=4.5.3
archive="blender-${version}-linux-x64.tar.xz"
dir="$RUNNER_TEMP/blender-lts"
mkdir -p "$dir"
curl -fL --retry 4 "https://download.blender.org/release/Blender4.5/$archive" -o "$dir/$archive"
tar -xJf "$dir/$archive" -C "$dir"
bin="$dir/blender-${version}-linux-x64"
"$bin/blender" -b --python-exit-code 1 --python-expr "import numpy; from io_scene_gltf2.blender.exp import export; print(numpy.__version__)"
echo "$bin" >> "$GITHUB_PATH"
