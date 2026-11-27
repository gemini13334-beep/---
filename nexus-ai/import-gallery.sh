#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
ref="${GALLERY_REF:-main}"
if [ -e gallery ]; then echo 'gallery already exists; refusing to overwrite'; exit 1; fi
git clone --depth 1 --branch "$ref" https://github.com/google-ai-edge/gallery.git gallery
git -C gallery rev-parse HEAD > gallery-revision.txt
rm -rf gallery/.git
