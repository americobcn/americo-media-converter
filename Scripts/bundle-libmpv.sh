#!/bin/bash
# Vendors libmpv and all of its Homebrew dependency dylibs into the built .app so
# the app runs on machines without Homebrew. Runs from the target's "Embed libmpv"
# build phase on every build (Debug, Release, Archive), before Xcode code-signs the bundle.
#
#   Scripts/bundle-libmpv.sh "/path/to/Americo's Media Converter.app"
#
# It copies libmpv + its transitive deps into Contents/Frameworks, rewrites the
# install names to @rpath, signs the copied dylibs, and finally verifies that nothing in
# the bundle still points outside the system or the bundle itself.
set -euo pipefail

# Xcode.app launched from Finder/Dock/Spotlight doesn't inherit the interactive shell's
# PATH, so Homebrew tools (dylibbundler) are invisible to build phases and scheme actions
# even though they work fine from a Terminal-launched xcodebuild. Force it explicitly.
export PATH="/opt/homebrew/bin:$PATH"

APP="${1:?Usage: bundle-libmpv.sh <path-to-.app>}"
MACOS="$APP/Contents/MacOS"
FRAMEWORKS="$APP/Contents/Frameworks"
IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:--}"

[ -d "$MACOS" ] || { echo "error: $MACOS not found"; exit 1; }
command -v dylibbundler >/dev/null || { echo "error: dylibbundler missing: brew install dylibbundler"; exit 1; }

# Debug builds split the app into a stub executable plus "<name>.debug.dylib" (and
# __preview.dylib); the real code, and the libmpv reference, lives in the debug dylib.
# Fix every Mach-O in MacOS/ that still points at Homebrew.
targets=()
while IFS= read -r file; do
  if otool -L "$file" 2>/dev/null | grep -q '/opt/homebrew/'; then
    targets+=("$file")
  fi
done < <(find "$MACOS" -type f)

if [ "${#targets[@]}" -gt 0 ]; then
  mkdir -p "$FRAMEWORKS"

  fix_args=()
  for file in "${targets[@]}"; do
    fix_args+=(--fix-file "$file")
  done

  dylibbundler \
    --overwrite-files \
    --bundle-deps \
    --create-dir \
    "${fix_args[@]}" \
    --dest-dir "$FRAMEWORKS" \
    --install-path "@rpath/" \
    --search-path /opt/homebrew/lib

  # dylibbundler adds an rpath equal to the literal --install-path string ("@rpath/") to
  # every file it touches. That's not a real search path, so every @rpath/*.dylib
  # reference in the chain (app -> libmpv -> its own sibling deps like libavcodec) is
  # unresolvable. Strip it and restore a real search path: @executable_path/../Frameworks
  # on the app's own code, @loader_path (same directory) on each sibling dylib.
  fix_rpath() {
    local file="$1" real_rpath="$2"
    while install_name_tool -delete_rpath "@rpath/" "$file" 2>/dev/null; do :; done
    install_name_tool -add_rpath "$real_rpath" "$file" 2>/dev/null || true
  }

  for file in "${targets[@]}"; do
    fix_rpath "$file" "@executable_path/../Frameworks"
  done
  for dylib in "$FRAMEWORKS"/*.dylib; do
    fix_rpath "$dylib" "@loader_path"
  done

  # install_name_tool invalidates signatures. Xcode's own CodeSign step only seals the
  # bundle, so re-sign each rewritten Mach-O here.
  for file in "${targets[@]}" "$FRAMEWORKS"/*.dylib; do
    codesign --force --sign "$IDENTITY" "$file"
  done
fi

# Verify: every Mach-O in the bundle (app code, Frameworks, and the ffmpeg/ffprobe/jq
# helpers in Resources) may only link against system libraries or the bundle itself.
bad=0
while IFS= read -r file; do
  refs=$(otool -L "$file" 2>/dev/null | tail -n +2 | awk '{print $1}' \
    | grep -v -E '^(/usr/lib/|/System/Library/|@rpath/|@loader_path/|@executable_path/)' || true)
  if [ -n "$refs" ]; then
    echo "error: $file links outside the bundle:"
    echo "$refs" | sed 's/^/    /'
    bad=1
  fi
done < <(find "$APP/Contents" -type f \( -perm -u+x -o -name '*.dylib' \) ! -path '*/_CodeSignature/*')
[ "$bad" -eq 0 ] || exit 1

echo "Embedded dependencies in $FRAMEWORKS: $(ls "$FRAMEWORKS" 2>/dev/null | wc -l | tr -d ' ') dylibs"
