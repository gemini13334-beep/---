#!/usr/bin/env bash
set -euo pipefail

image="${1:?Pass an SDK system image}"
expected_page_size="${2:?Pass the Android page size}"
apk="${3:-}"
package="${4:-}"
baseline="${5:-}"
[[ -n "$apk" && -n "$package" || -n "$baseline" ]]
log_dir=install-logs
avd=one-more-install
adb="$ANDROID_HOME/platform-tools/adb"
mkdir -p "$log_dir"

sdkmanager emulator "$image"
printf 'no\n' | avdmanager create avd --force --name "$avd" --package "$image"
emulator="$ANDROID_HOME/emulator/emulator"
"$emulator" -accel-check
df -h "$ANDROID_HOME" "${ANDROID_AVD_HOME:-$HOME/.android}"
"$adb" start-server
"$emulator" -avd "$avd" -no-window -noaudio -no-boot-anim -skip-adb-auth \
  -no-snapshot -gpu swiftshader_indirect -partition-size 2048 -memory 3072 -cores 2 > "$log_dir/emulator.log" 2>&1 &
emulator_pid=$!
cleanup() {
  local status=$?
  if ((status != 0)); then
    tail -100 "$log_dir/emulator.log"
    "$adb" devices -l
  fi
  timeout 15s "$adb" logcat -d -t 2000 > "$log_dir/android.log" 2>&1 || true
  kill "$emulator_pid" 2>/dev/null || true
}
trap cleanup EXIT

for attempt in {1..90}; do
  if [[ "$(timeout 5s "$adb" shell getprop sys.boot_completed 2>/dev/null || true)" == 1 ]]; then
    break
  fi
  kill -0 "$emulator_pid"
  sleep 2
done
[[ "$(timeout 5s "$adb" shell getprop sys.boot_completed)" == 1 ]]
"$adb" shell svc power stayon true
"$adb" shell wm dismiss-keyguard

{
  echo "Android API: $("$adb" shell getprop ro.build.version.sdk)"
  echo "Supported ABIs: $("$adb" shell getprop ro.product.cpu.abilist)"
  echo "Page size: $("$adb" shell getconf PAGE_SIZE)"
} | tee "$log_dir/device.txt"
[[ "$("$adb" shell getconf PAGE_SIZE)" == "$expected_page_size" ]]
grep -Fq arm64-v8a "$log_dir/device.txt"

if [[ -n "$baseline" ]]; then
  timeout 90s "$adb" install --no-streaming "$baseline" 2>&1 | tee "$log_dir/baseline-install.txt" || true
fi

if [[ -z "$apk" ]]; then
  exit 0
fi
timeout 90s "$adb" install --no-streaming "$apk" 2>&1 | tee "$log_dir/install.txt"
grep -Fxq Success "$log_dir/install.txt"
timeout 45s "$adb" shell am start -W -n "$package/com.godot.game.GodotApp" | tee "$log_dir/launch.txt"
grep -Fxq 'Status: ok' "$log_dir/launch.txt"
sleep 12
"$adb" shell pidof "$package" | tee "$log_dir/game-pid.txt"
