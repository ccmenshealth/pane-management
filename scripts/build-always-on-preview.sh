#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if pgrep -x AlwaysOnPreview >/dev/null; then
    printf 'Quit Always-on Preview before packaging.\n' >&2
    exit 1
fi
swift build -c release --product AlwaysOnPreview --disable-sandbox --cache-path .build/cache
task_bin_dir="$(swift build -c release --show-bin-path --disable-sandbox --cache-path .build/cache)"
task_app="$PWD/dist/Always-on Preview.app"
mkdir -p "$task_app/Contents/MacOS"
cp "$task_bin_dir/AlwaysOnPreview" "$task_app/Contents/MacOS/"
cp Resources/AlwaysOnPreviewInfo.plist "$task_app/Contents/Info.plist"
codesign --force --sign - "$task_app"
