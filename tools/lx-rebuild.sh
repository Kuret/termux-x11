#!/usr/bin/env bash
# Refreshes the per-app windows from the phone, rebuilds the APK and installs it.
#
#   tools/lx-rebuild.sh           pull the app list off the phone, regenerate, build, install
#   tools/lx-rebuild.sh --local   skip the pull and build from lorie/lx-apps as it stands
#
# Run it after adding a Linux app to /etc/lx/apps.conf and launching it once, so that
# /data/local/bin/lx has published that app's name and icon.
#
# See FORK.md for why this fork exists and what the build needs.

set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
spec=$repo/lorie/lx-apps
apk=$repo/lorie-app/build/outputs/apk/standalone/debug/termux-x11-universal-debug.apk
: "${JAVA_HOME:=/opt/homebrew/opt/openjdk@17}"
export JAVA_HOME PATH="$JAVA_HOME/bin:$PATH"

if [ "${1-}" != "--local" ]; then
    echo "==> pulling the app list from the phone"
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    adb exec-out su -c 'tar -C /data/data/com.termux.x11/files -cf - lx-tags' | tar -xf - -C "$tmp"
    mkdir -p "$spec"
    cp "$tmp"/lx-tags/*.name "$spec/" 2>/dev/null || true
    cp "$tmp"/lx-tags/*.png  "$spec/" 2>/dev/null || true
fi

echo "==> regenerating the per-app activities"
"$repo/tools/lx-gen-aliases.sh" "$spec"

echo "==> building"
(cd "$repo" && ./gradlew :lorie-app:assembleStandaloneDebug)

echo "==> installing"
adb install -r "$apk"

echo
echo "Relaunch each app so its window picks up the new activity:"
echo "  adb shell su -c '/data/local/bin/lx stop <id>; /data/local/bin/lx <id>'"
