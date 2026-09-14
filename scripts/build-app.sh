#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --disable-sandbox --cache-path .build/cache
task_bin_dir="$(swift build -c release --show-bin-path --disable-sandbox --cache-path .build/cache)"
task_app="$PWD/dist/Pane Management.app"
if pgrep -x PaneManagement >/dev/null; then
    printf 'Quit Pane Management before packaging; the running app has not been changed.\n' >&2
    exit 1
fi
mkdir -p "$task_app/Contents/MacOS" "$task_app/Contents/Resources"
cp "$task_bin_dir/PaneManagement" "$task_app/Contents/MacOS/PaneManagement"
cp Resources/Info.plist "$task_app/Contents/Info.plist"
iconutil --convert icns --output "$task_app/Contents/Resources/AppIcon.icns" Icons/AppIcon.iconset
cp Icons/Assets.xcassets/MenuBarIconTemplate.imageset/MenuBarIconTemplate.pdf "$task_app/Contents/Resources/MenuBarIconTemplate.pdf"
codesign --force --sign - --identifier local.snapbridge.app "$task_app"
codesign --verify --strict "$task_app"
printf 'Built %s\n' "$task_app"
