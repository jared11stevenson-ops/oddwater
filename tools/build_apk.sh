#!/usr/bin/env bash
# Build the sideloadable Android APK (arm64-v8a, for the Samsung Galaxy S25) into dist/.
# Needs: Godot (latest stable) + matching export templates, Android SDK at /opt/android-sdk (build-tools 35.0.1,
# platforms android-35), JDK 21, and ~/.android/debug.keystore. See AUTOBUILD.md for one-time setup.
cd "$(dirname "$0")/.." || exit 1
label="${1:-$(git rev-parse --short HEAD)}"
rm -rf dist; mkdir -p dist
cd game || exit 1
godot --headless --path . --import >/dev/null 2>&1
godot --headless --path . --export-release Android >/dev/null 2>&1
cd ../dist || exit 1
rm -f Understudy.apk.idsig
mv Understudy.apk "Understudy-$label-android-arm64.apk"
ls -la
