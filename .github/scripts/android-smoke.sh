#!/usr/bin/env bash
set -euo pipefail
mkdir -p device-check
diagnostics() {
 adb logcat -d > device-check/logcat.txt
 adb shell dumpsys activity exit-info "$PACKAGE" > device-check/exits.txt
 grep -Ei 'godot|FATAL EXCEPTION|Fatal signal' device-check/logcat.txt | tail -90 || true
}
trap diagnostics EXIT
adb shell settings put secure immersive_mode_confirmations confirmed
adb shell input keyevent KEYCODE_WAKEUP
adb shell wm dismiss-keyguard
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 1
adb shell wm density 320
adb shell wm size 720x1280
until adb shell getprop init.svc.bootanim | grep -q stopped; do sleep 2; done
sleep 12
if [[ -n "${BASELINE_APK:-}" ]]; then
  adb install "$BASELINE_APK"
  adb shell dumpsys package "$PACKAGE" | grep -m1 'versionCode=' > device-check/upgrade-from.txt
  adb install -r "dist/$APK"
else
  adb install "dist/$APK"
fi
activity=$(adb shell cmd package resolve-activity --brief "$PACKAGE" | tail -1 | tr -d '\r')
adb shell am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -n "$activity" | tee device-check/launch.txt
grep -F 'Status: ok' device-check/launch.txt
# The landscape viewport is 1280x720. Wait for the rust-red deployment button
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
sys.exit(0 if r > 155 and 42 < g < 135 and b < 105 and r > g + 60 else 1)
PYCODE
    then return; fi
    if (( attempt == 15 )); then adb shell pidof "$PACKAGE" || return 1; fi
    sleep 1
  done
  return 1
}
wait_for_button lobby 1025 654
adb shell input tap 1090 579
wait_for_button cases 450 507
adb shell input tap 537 507
wait_for_button reward 454 563
adb shell input tap 340 32
wait_for_button return-lobby 1025 654
adb shell input tap 1090 654
wait_for_button missions 1010 612
adb shell input tap 1070 612
sleep 5
adb shell pidof "$PACKAGE"
adb exec-out screencap -p > device-check/combat.png
adb logcat -d -s godot:E AndroidRuntime:E > device-check/first-run.log
if grep -E 'SCRIPT ERROR|Parse Error|FATAL EXCEPTION|Failed to load script' device-check/first-run.log; then exit 1; fi
adb install -r "dist/$APK"
adb shell am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -n "$activity"
sleep 3
adb shell pidof "$PACKAGE"
