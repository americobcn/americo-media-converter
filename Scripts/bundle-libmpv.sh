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

# Xcode.app launched from Finder/Dock/Spotlight doesn't inherit the interactive shell's
# PATH, so Homebrew tools (dylibbundler) are invisible to scheme pre/post-action scripts
# even though they work fine from a Terminal-launched xcodebuild. Force it explicitly.
export PATH="/opt/homebrew/bin:$PATH"

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

# dylibbundler adds an rpath equal to the literal --install-path string ("@rpath/") to
# the main binary AND to every dylib it copies. That's not a real search path, so every
# @rpath/*.dylib reference in the chain (main binary -> libmpv -> its own sibling deps
# like libavcodec) is unresolvable. Strip it everywhere and restore a real search path:
# @executable_path/../Frameworks on the main binary, @loader_path (same directory) on
# each sibling dylib.
fix_rpath() {
  local file="$1" real_rpath="$2"
  while install_name_tool -delete_rpath "@rpath/" "$file" 2>/dev/null; do :; done
  install_name_tool -add_rpath "$real_rpath" "$file" 2>/dev/null || true
}

fix_rpath "$BIN" "@executable_path/../Frameworks"
for dylib in "$FRAMEWORKS"/*.dylib; do
  fix_rpath "$dylib" "@loader_path"
done

codesign --force --deep --sign - "$APP"

echo "Bundled into $FRAMEWORKS:"
ls "$FRAMEWORKS"
