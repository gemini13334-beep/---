#!/usr/bin/env bash
set -euo pipefail
mkdir -p device-check
trap 'adb logcat -d -s AndroidRuntime:E godot:E > device-check/errors.log || true' EXIT
adb install "dist/$APK"
activity=$(adb shell cmd package resolve-activity --brief "$PACKAGE" | tail -1 | tr -d '\r')
adb shell am start -W -n "$activity" | tee device-check/launch.txt
grep -F 'Status: ok' device-check/launch.txt
sleep 8
adb shell pidof "$PACKAGE"
adb exec-out screencap -p > device-check/lobby.png
adb install -r "dist/$APK"
adb shell am start -W -n "$activity"
sleep 3
adb shell pidof "$PACKAGE"
