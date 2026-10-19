#!/usr/bin/env bash
# Export playable builds and zip them into dist/. Needs the Godot 4.7 export templates installed.
# Usage: tools/build_zips.sh [label]    (label defaults to the short git hash)
cd "$(dirname "$0")/.." || exit 1
label="${1:-$(git rev-parse --short HEAD)}"
rm -rf dist; mkdir -p dist/win dist/linux dist/web
cd game || exit 1
godot --headless --path . --import >/dev/null 2>&1
godot --headless --path . --export-release Windows >/dev/null 2>&1
godot --headless --path . --export-release Linux >/dev/null 2>&1
godot --headless --path . --export-release Web >/dev/null 2>&1
cd ../dist || exit 1
cp ../tools/PLAY-README.txt win/README.txt; cp ../tools/PLAY-README.txt linux/README.txt; cp ../tools/PLAY-README.txt web/README.txt
(cd win && zip -qr "../Understudy-$label-windows.zip" .)
(cd linux && zip -qr "../Understudy-$label-linux.zip" .)
(cd web && zip -qr "../Understudy-$label-web.zip" .)
rm -rf win linux web
ls -la
