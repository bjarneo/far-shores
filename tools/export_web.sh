#!/bin/sh
# Exports the web build to build/web and adds the web app manifest and icons.
set -e
cd "$(dirname "$0")/.."
rm -rf build/web
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html
cp web_extra/manifest.webmanifest web_extra/icon-192.png web_extra/icon-512.png build/web/
echo "Exported to build/web"
