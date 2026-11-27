#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if [ -e upstream ]; then echo 'upstream exists; refusing overwrite'; exit 1; fi
git clone --depth 1 --branch 4.4.1-stable https://github.com/godotengine/godot.git upstream
git -C upstream rev-parse HEAD > upstream-revision.txt
printf 'Godot sources ready; preserve upstream license and notices.\n'
