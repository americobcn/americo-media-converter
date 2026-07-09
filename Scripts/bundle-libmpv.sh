#!/bin/bash
# Vendors libmpv and all of its Homebrew dependency dylibs into a built .app so
# the app runs on machines without Homebrew. Run AFTER building in Xcode.
#
#   Scripts/bundle-libmpv.sh "/path/to/Americo's Media Converter.app"
#
# It copies libmpv + its transitive deps into Contents/Frameworks, rewrites the
# install names to @rpath (the app already has @executable_path/../Frameworks on
# its runpath), then ad-hoc re-signs the bundle so the dylibs load under the
# hardened runtime. For notarized distribution, re-sign with a Developer ID.
set -euo pipefail

APP="${1:?Usage: bundle-libmpv.sh <path-to-.app>}"
BIN="$APP/Contents/MacOS/Americo's Media Converter"
FRAMEWORKS="$APP/Contents/Frameworks"

[ -x "$BIN" ] || { echo "Executable not found: $BIN"; exit 1; }
command -v dylibbundler >/dev/null || { echo "dylibbundler missing: brew install dylibbundler"; exit 1; }

mkdir -p "$FRAMEWORKS"

dylibbundler \
  --overwrite-files \
  --bundle-deps \
  --create-dir \
  --fix-file "$BIN" \
  --dest-dir "$FRAMEWORKS" \
  --install-path "@rpath/" \
  --search-path /opt/homebrew/lib

codesign --force --deep --sign - "$APP"

echo "Bundled into $FRAMEWORKS:"
ls "$FRAMEWORKS"
