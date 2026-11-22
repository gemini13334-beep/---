#!/usr/bin/env bash
set -euo pipefail
mkdir -p device-check
trap 'adb logcat -d -s AndroidRuntime:E godot:E > device-check/errors.log || true' EXIT
adb shell wm size 720x1280
adb install "dist/$APK"
activity=$(adb shell cmd package resolve-activity --brief "$PACKAGE" | tail -1 | tr -d '\r')
adb shell am start -W -n "$activity" | tee device-check/launch.txt
grep -F 'Status: ok' device-check/launch.txt
# The landscape viewport is 1280x720. Wait for the amber deployment button
# before sending input so a slow emulator can finish importing the first frame.
wait_for_button() {
  local screen=$1 x=$2 y=$3
  for attempt in {1..40}; do
    adb exec-out screencap -p > "device-check/$screen.png"
    if python3 - "$screen" "$x" "$y" <<'PYCODE'
import sys
from PIL import Image
image = Image.open("device-check/" + sys.argv[1] + ".png").convert("RGB")
if image.width < image.height:
    sys.exit(1)
r,g,b = image.getpixel((int(sys.argv[2]), int(sys.argv[3])))
sys.exit(0 if r > 170 and 100 < g < 215 and b < 130 and r > g + 30 else 1)
PYCODE
    then return; fi
    sleep 1
  done
  return 1
}
wait_for_button lobby 1025 654
adb shell input tap 1090 654
wait_for_button missions 1010 612
adb shell input tap 1070 612
sleep 5
adb shell pidof "$PACKAGE"
adb exec-out screencap -p > device-check/combat.png
adb logcat -d -s godot:E AndroidRuntime:E > device-check/first-run.log
if grep -E 'SCRIPT ERROR|Parse Error|FATAL EXCEPTION|Failed to load script' device-check/first-run.log; then exit 1; fi
adb install -r "dist/$APK"
adb shell am start -W -n "$activity"
sleep 3
adb shell pidof "$PACKAGE"
