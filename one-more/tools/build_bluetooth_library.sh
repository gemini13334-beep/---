#!/usr/bin/env bash
set -euo pipefail
project="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -s "${ANDROID_HOME:?Set ANDROID_HOME}/platforms/android-35/android.jar" ]]; then
  sdkmanager 'platforms;android-35'
fi
gradle --no-daemon --project-dir "$project/android-plugin" assembleRelease

library="$project/android-plugin/build/outputs/aar/OneMoreBluetooth-release.aar"
destination="$project/addons/one_more_bluetooth/OneMoreBluetooth.aar"
test -s "$library"
unzip -tq "$library"
cp "$library" "$destination"
