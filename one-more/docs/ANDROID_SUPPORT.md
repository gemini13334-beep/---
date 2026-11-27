# Android support

The Android preset uses the Godot 4.4.1 Gradle template with minSdk 34, targetSdk 35 and ARM64. The manual Android workflow rebuilds its native template libraries using NDK r28c, aligns the APK for 16 KiB pages, then signs it. It stages editable Blender files outside the import tree and retains bounded import and export, logs, package and permission checks, signature verification, and ELF alignment checks. Godot requires ETC2/ASTC texture import for Android export.

The workflow installs and starts the same ARM64 APK on Android 14 with 4 KiB pages and Android 15 with 16 KiB pages using emulators with ARM translation. The manual `publish_preview` input publishes the APK on a prerelease specific to the commit after both checks pass. The optional `baseline_preview` input compares a prior release. With `baseline_only` it runs the comparison without an APK export. The published 0.2.3 preview installed on Android 14 and returned `INSTALL_FAILED_INVALID_APK: Failed to extract native libraries` on the Android 15 16 KiB emulator. Physical device checks still cover vendor installer behavior and performance.

Bluetooth uses Godot's Android plugin v2 and a secure RFCOMM connection between two devices paired in system settings. The plugin requests BLUETOOTH_CONNECT and uses neither scanning nor location. Android allows launch of the solo game on devices without Bluetooth. The plugin exposes a separately built AAR for the Gradle APK export, which remains a manual workflow.

The validation workflow compiles the AAR and runs Godot's host/guest tests with an in-memory transport. Physical devices are needed to verify pairing, permission dialogs, throughput and reconnect behavior over real Bluetooth. Both devices must run the same build for the current co-op protocol. APK export needs separate user authorization.

Published previews use `com.onemore.arcade.preview.v<versionCode>`. Android installs them alongside the main app and older previews, preserving their separate profiles. Each preview uses the same profile format. The runner generates a debug signing key for each build.
