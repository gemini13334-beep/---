#!/usr/bin/env bash
set -euo pipefail

check_blender() {
  timeout --kill-after=10s 45s "$1" -b --python-exit-code 1 \
    --python-expr "import bpy; import numpy; from io_scene_gltf2.blender.exp import export; assert bpy.app.version >= (4, 3, 0); print(numpy.__version__)"
}

if command -v blender >/dev/null && check_blender blender; then
  blender --version
  exit 0
fi

# Bound the package manager so an unavailable mirror does not hold the job open.
apt_options=(-o Acquire::Retries=1 -o Acquire::http::Timeout=30 -o Acquire::https::Timeout=30)
if sudo timeout --kill-after=10s 70s apt-get "${apt_options[@]}" update \
  && sudo timeout --kill-after=10s 140s apt-get "${apt_options[@]}" install -y blender python3-numpy python3-pil \
  && check_blender blender; then
  blender --version
  exit 0
fi

# Official portable LTS build, with bundled Python dependencies.
version=4.5.3
archive="blender-$version-linux-x64.tar.xz"
dir="$RUNNER_TEMP/blender-lts"
mkdir -p "$dir"
echo "Distro Blender is unavailable or failed preflight. Trying Blender $version LTS."
curl -fL --retry 2 --connect-timeout 15 --max-time 180 --retry-max-time 220 \
  "https://download.blender.org/release/Blender4.5/$archive" -o "$dir/$archive"
timeout --kill-after=10s 120s tar -xJf "$dir/$archive" -C "$dir"
bin="$dir/blender-$version-linux-x64"
check_blender "$bin/blender"
echo "$bin" >> "$GITHUB_PATH"
