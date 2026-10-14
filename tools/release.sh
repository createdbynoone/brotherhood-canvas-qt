#!/bin/bash
# Builds a standalone, ad-hoc signed Brotherhood Canvas.app (Qt frameworks embedded) and zips it for a GitHub release.
set -euo pipefail
cd "$(dirname "$0")/.."
QT="$(brew --prefix qt)"
VER="$(grep -m1 'project(BrotherhoodCanvas VERSION' CMakeLists.txt | sed -E 's/.*VERSION ([0-9.]+).*/\1/')"
cmake -S . -B build-release -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="$QT"
cmake --build build-release
APP="build-release/Brotherhood Canvas.app"
"$QT/bin/macdeployqt" "$APP" -qmldir=qml -always-overwrite
tools/prune_bundle.sh "$APP"
codesign --force --deep --sign - "$APP"
ZIP="dist/Brotherhood-Canvas-$VER-arm64-mac.zip"
mkdir -p dist
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "$ZIP"
