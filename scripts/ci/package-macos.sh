#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$project_dir"
stage="$project_dir/build/macos-dmg"
app="$stage/Sori.app"
version="$(python3 -c "import tomllib; print(tomllib.load(open('core/Cargo.toml','rb'))['package']['version'])")"
output="$project_dir/build/Sori-$version-macos-arm64-unnotarized.dmg"
rm -rf -- "$stage"
mkdir -p "$stage"
ditto build/sori.app "$app"
cp -R resources/kiwi "$app/Contents/MacOS/kiwi"
cp -R build/helpers "$app/Contents/MacOS/helpers"
cp "$(command -v ffmpeg)" "$(command -v ffprobe)" "$app/Contents/MacOS/"
mkdir -p "$app/Contents/Resources/licenses"
cp LICENSE assets/*LICENSE* assets/OFL-*.txt assets/kiwi/*LICENSE "$app/Contents/Resources/licenses/"

# Generate the native icon using the platform's tools and the shared PNG.
iconset="$project_dir/build/sori.iconset"
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
"$QT_ROOT_DIR/bin/macdeployqt" "$app" -qmldir="$project_dir/qml" -always-overwrite \
    -executable="$app/Contents/MacOS/ffmpeg" -executable="$app/Contents/MacOS/ffprobe"
codesign --force --deep --sign - "$app"
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
hdiutil detach "$mount_dir"
rmdir "$mount_dir"
trap - EXIT
cd "$project_dir/build"
shasum -a 256 "$(basename "$output")" > "$(basename "$output").sha256"
