#!/bin/bash
# Removes Qt plugins the app never uses. Some of them (PDF, virtual keyboard, 3D, the other Controls styles,
# glib networkinformation) depend on Qt frameworks that macdeployqt does not bundle, which made the app load
# a SECOND copy of QtCore / QtGui from Homebrew. Usage: prune_bundle.sh "<path to .app>"
set -euo pipefail
APP="$1"; P="$APP/Contents/PlugIns"
rm -f  "$P/imageformats/libqpdf.dylib" \
       "$P/platforminputcontexts/libqtvirtualkeyboardplugin.dylib" \
       "$P/networkinformation/libqglib.dylib" \
       "$P/quick/libpdfquickplugin.dylib" \
       "$P/quick/libqmldesignsupportplugin.dylib" \
       "$P/quick/libqtquickscene2dplugin.dylib" \
       "$P/quick/libqtquickscene3dplugin.dylib" \
       "$P/quick/libparticlesplugin.dylib" \
       "$P/quick/libqtquicktimelineblendtreesplugin.dylib" \
       "$P/quick/libqtqmlstatemachineplugin.dylib" \
       "$P/quick/libqmllocalstorageplugin.dylib" \
       "$P/quick/libqmlxmllistmodelplugin.dylib" \
       "$P/quick/libqmlfolderlistmodelplugin.dylib" \
       "$P/quick/libqtquickshapesdesignhelpersplugin.dylib"
# Controls styles other than Basic (and the native style plugins that pull in the macOS style)
rm -f "$P"/quick/libqtquickcontrols2{fluentwinui3,fusion,imagine,ios,macos,material,universal}style*plugin.dylib \
      "$P"/quick/libqtquickcontrols2nativestyleplugin.dylib "$P"/quick/libqtquicknativestyleplugin.dylib
# macdeployqt links each QML plugin from Resources/qml/... into PlugIns/: drop the links (and their now-empty
# module folders) whose target was just removed, or `codesign --strict` fails on dangling symlinks.
find "$APP/Contents" -type l ! -exec test -e {} \; -delete
find "$APP/Contents/Resources/qml" -type d -empty -delete 2>/dev/null || true
# CMake writes a qt.conf that points QmlImports at the BUILD directory (handy for development). Shipped as is,
# the app would read that folder (here an external SSD) at every launch: slow, a macOS "removable volume"
# permission prompt, and a dependency on the disk being plugged in. Point it inside the bundle instead.
cat > "$APP/Contents/Resources/qt.conf" <<'CONF'
[Paths]
Plugins = PlugIns
Imports = Resources/qml
QmlImports = Resources/qml
CONF
echo "pruned: $(find "$P" -name '*.dylib' | wc -l | tr -d ' ') plugins left"
