#!/usr/bin/env bash
set -euo pipefail

# Rebuild the native part of the stock 4.4.1 Gradle template with 16 KiB support.
output="$(realpath -m "${1:?Pass an output directory}")"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
revision=49a5bc7b616bd04689a2c89e89bda41f50241464
ndk_version=28.2.13676358

curl -fsSL --retry 3 "https://codeload.github.com/godotengine/godot/tar.gz/$revision" -o "$work/godot.tar.gz"
curl -fsSL --retry 3 https://github.com/godotengine/godot-swappy/releases/download/from-source-2025-01-31/godot-swappy.zip -o "$work/godot-swappy.zip"
printf '%s  %s\n' 2dd05484de29a3040106658d6f95915778fd71abc3261130eada6090ed1c153d "$work/godot-swappy.zip" | sha256sum -c
tar -xzf "$work/godot.tar.gz" -C "$work"
cd "$work/godot-$revision"
unzip -q "$work/godot-swappy.zip" -d thirdparty/swappy-frame-pacing

if [[ ! -x "${ANDROID_HOME:?}/ndk/$ndk_version/toolchains/llvm/prebuilt/linux-x86_64/bin/clang++" ]]; then
  sdkmanager "ndk;$ndk_version"
fi
ndk_libcxx="$ANDROID_HOME/ndk/$ndk_version/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so"
test -s "$ndk_libcxx"
sed -i "s/23\.2\.8568313/$ndk_version/" platform/android/detect.py
sed -i 's|/sources/cxx-stl/llvm-libc++/libs/" + lib_arch_dir + "/libc++_shared.so|/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so|' platform/android/SCsub

scons platform=android target=template_debug arch=arm64 ndk_platform=android-34 \
  swappy=yes production=yes LINKFLAGS='-Wl,-z,max-page-size=16384' -j"$(nproc)"

mkdir -p "$output"
cp platform/android/java/lib/libs/debug/arm64-v8a/libgodot_android.so "$output/"
cp "$ndk_libcxx" "$output/"
