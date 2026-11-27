#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$project_dir"
build_dir="${SORI_BUILD_DIR:-$project_dir/build}"
stage="$build_dir/macos-dmg"
app="$stage/Sori.app"
version="$(python3 -c "import tomllib; print(tomllib.load(open('core/Cargo.toml','rb'))['package']['version'])")"
output="$build_dir/Sori-$version-macos-arm64-unnotarized.dmg"
rm -rf -- "$stage"
mkdir -p "$stage"
ditto "$build_dir/sori.app" "$app"
kiwi_dir="$(sed -n 's/^SORI_KIWI_DIR:PATH=//p' "$build_dir/CMakeCache.txt")"
cp "$(command -v ffmpeg)" "$(command -v ffprobe)" "$app/Contents/MacOS/"
mkdir -p "$app/Contents/Resources/licenses"
cp LICENSE assets/*LICENSE* assets/OFL-*.txt assets/kiwi/*LICENSE "$app/Contents/Resources/licenses/"

# Generate the native icon using the platform's tools and the shared PNG.
iconset="$build_dir/sori.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" packaging/linux/sori.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
    doubled=$((size * 2))
    sips -z "$doubled" "$doubled" packaging/linux/sori.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$app/Contents/Resources/sori.icns"
plist="$app/Contents/Info.plist"
for key in CFBundleShortVersionString CFBundleVersion; do
    /usr/libexec/PlistBuddy -c "Set :$key $version" "$plist"
done
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile sori.icns" "$plist" \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string sori.icns" "$plist"
# Give Qt a private plugin view containing only SQLite database support. Qt's
# other SQL drivers require external database clients that Sori does not use.
# qt.conf belongs to our tool copy; the installed SDK is left untouched.
deploy_tools="$build_dir/macdeployqt"
rm -rf -- "$deploy_tools"
mkdir -p "$deploy_tools/plugins/sqldrivers"
ditto "$QT_ROOT_DIR/bin/macdeployqt" "$deploy_tools/macdeployqt"
for plugin_dir in "$QT_ROOT_DIR/plugins/"*; do
    test -d "$plugin_dir" || continue
    test "$(basename "$plugin_dir")" = sqldrivers && continue
    ln -s "$plugin_dir" "$deploy_tools/plugins/$(basename "$plugin_dir")"
done
ln -s "$QT_ROOT_DIR/plugins/sqldrivers/libqsqlite.dylib" "$deploy_tools/plugins/sqldrivers/libqsqlite.dylib"
cat > "$deploy_tools/qt.conf" <<EOF
[Paths]
Prefix = $QT_ROOT_DIR
Plugins = $deploy_tools/plugins
EOF
DYLD_FRAMEWORK_PATH="$QT_ROOT_DIR/lib" "$deploy_tools/macdeployqt" "$app" \
    -qmldir="$project_dir/qml" -always-overwrite -verbose=2 -codesign=- \
    -executable="$app/Contents/MacOS/ffmpeg" -executable="$app/Contents/MacOS/ffprobe"

# Python metadata and model data belong in Resources. Relative aliases preserve
# the runtime lookup paths. Copy after Qt deployment so its binary rewriting
# does not disturb the self-contained PyInstaller payload or Kiwi's install ID.
ditto "$kiwi_dir" "$app/Contents/Resources/kiwi"
ditto "$build_dir/helpers" "$app/Contents/Resources/helpers"
ln -s ../Resources/kiwi "$app/Contents/MacOS/kiwi"
ln -s ../Resources/helpers "$app/Contents/MacOS/helpers"
codesign --force --sign - "$app/Contents/Resources/kiwi/lib/libkiwi.dylib"
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
ln -s /Applications "$stage/Applications"
hdiutil create -volname Sori -srcfolder "$stage" -format UDZO -ov "$output"
hdiutil verify "$output"
mount_dir="$(mktemp -d "${RUNNER_TEMP:-/tmp}/sori-dmg.XXXXXX")"
trap 'hdiutil detach "$mount_dir" >/dev/null 2>&1 || true; rmdir "$mount_dir" 2>/dev/null || true' EXIT
hdiutil attach -readonly -nobrowse -mountpoint "$mount_dir" "$output"
test -d "$mount_dir/Sori.app"
test "$(readlink "$mount_dir/Applications")" = /Applications
test -f "$mount_dir/Sori.app/Contents/MacOS/kiwi/lib/libkiwi.dylib"
test -f "$mount_dir/Sori.app/Contents/MacOS/helpers/sori-youtube-transcript/sori-youtube-transcript"
codesign --verify --deep --strict "$mount_dir/Sori.app"
env -u QT_PLUGIN_PATH -u QML2_IMPORT_PATH -u DYLD_LIBRARY_PATH -u DYLD_FRAMEWORK_PATH \
    "$mount_dir/Sori.app/Contents/MacOS/sori" --help
"$mount_dir/Sori.app/Contents/MacOS/ffmpeg" -version >/dev/null
"$mount_dir/Sori.app/Contents/MacOS/helpers/sori-youtube-transcript/sori-youtube-transcript" --self-test \
    | python3 -c 'import json, sys; assert json.load(sys.stdin)["ready"]'
hdiutil detach "$mount_dir"
rmdir "$mount_dir"
trap - EXIT
cd "$build_dir"
shasum -a 256 "$(basename "$output")" > "$(basename "$output").sha256"
