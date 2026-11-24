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
# The landscape viewport is 1280x720. Wait for the highlighted deployment button
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
sys.exit(0 if r > 155 and 42 < g < 198 and b < 113 and r > g + 42 else 1)
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
# Shader compilation on a software-rendered emulator may outlast the first tap.
for attempt in {1..40}; do
  adb shell pidof "$PACKAGE" >/dev/null
  adb exec-out screencap -p > device-check/combat.png
  if python3 - <<'PY'
from PIL import Image
im = Image.open("device-check/combat.png").convert("RGB")
def gold(x,y):
    r,g,b=im.getpixel((x,y))
    return r>175 and r>g+20 and g>b+25
radar=any(gold(95,y) for y in range(18,23)) and any(gold(x,95) for x in range(18,23))
slot=any(gold(x,y) for x in range(1178,1183) for y in range(149,159))
raise SystemExit(0 if radar and slot else 1)
PY
  then break; fi
  if (( attempt == 10 )); then
    if python3 - <<'PY'
from PIL import Image
r,g,b=Image.open("device-check/combat.png").convert("RGB").getpixel((1010,612))
raise SystemExit(0 if r>155 and 42<g<198 and b<113 and r>g+42 else 1)
PY
    then adb shell input tap 1105 608; fi
  fi
  if (( attempt == 40 )); then exit 1; fi
  sleep 1
done
# Capture the same combat view with each hand pose on the Android renderer.
for entry in two:201 three:246 four:291 five:336; do
  slot=${entry%:*}
  y=${entry#*:}
  adb shell input tap 1221 "$y"
  for attempt in {1..24}; do
    adb exec-out screencap -p > "device-check/slot-$slot.png"
    if python3 - "$slot" "$y" <<'PYCODE'
import sys
from PIL import Image
im = Image.open("device-check/slot-" + sys.argv[1] + ".png").convert("RGB")
center = int(sys.argv[2])
pixels = [im.getpixel((x,y)) for x in range(1178,1184) for y in range(center-4,center+5)]
raise SystemExit(0 if any(r>200 and r>g+20 and g>b+40 for r,g,b in pixels) else 1)
PYCODE
    then break; fi
    if (( attempt == 24 )); then exit 1; fi
    sleep 1
  done
done
adb shell input tap 1150 608
for attempt in {1..24}; do
  adb exec-out screencap -p > device-check/crouched.png
  if python3 - <<'PY'
from PIL import Image
im=Image.open("device-check/crouched.png").convert("RGB")
r,g,b=im.getpixel((1154,598))
raise SystemExit(0 if r>195 and 130<g<217 and b<145 and r>g+25 else 1)
PY
  then break; fi
  if (( attempt == 24 )); then exit 1; fi
  sleep 1
done
adb logcat -d -s godot:E AndroidRuntime:E > device-check/first-run.log
if grep -E 'SCRIPT ERROR|Parse Error|FATAL EXCEPTION|Failed to load script' device-check/first-run.log; then exit 1; fi
adb install -r "dist/$APK"
adb shell am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -n "$activity"
sleep 3
adb shell pidof "$PACKAGE"
# Render the full-width lobby after an Android configuration change. In 20:9
# the controls stay in the safe area and the portrait reaches the screen edges.
adb shell am force-stop "$PACKAGE"
adb shell wm size 720x1600
adb shell am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -n "$activity"
wait_for_button wide-lobby 1185 652
python3 - <<'PYCODE'
from PIL import Image, ImageStat
im=Image.open("device-check/wide-lobby.png").convert("RGB")
assert im.size==(1600,720), im.size
for x in (0,1520):
    panel=im.crop((x,150,x+80,510))
    assert max(ImageStat.Stat(panel).stddev)>8, "flat margin at edge of lobby"
PYCODE
