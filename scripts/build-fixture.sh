#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product PaneManagementTestWindows --disable-sandbox --cache-path .build/cache
task_bin_dir="$(swift build -c release --show-bin-path --disable-sandbox --cache-path .build/cache)"
task_app="$PWD/dist/Pane Management Test Windows.app"
if pgrep -x PaneManagementTestWindows >/dev/null; then
    printf 'Quit Pane Management Test Windows before packaging.\n' >&2
    exit 1
fi
mkdir -p "$task_app/Contents/MacOS"
cp "$task_bin_dir/PaneManagementTestWindows" "$task_app/Contents/MacOS/"
cp Resources/TestWindowsInfo.plist "$task_app/Contents/Info.plist"
codesign --force --sign - "$task_app"
