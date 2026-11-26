# Android support

The Android preset uses the Godot 4.4.1 Gradle template with minSdk 34, targetSdk 35 and ARM64. The manual Android workflow stages editable Blender files outside the import tree. It retains bounded import and export, logs, and verifies the APK archive, Android and ARM64 metadata, manifest permissions, and signing certificate. The manual `publish_preview` input publishes the verified APK on a prerelease specific to the commit.

Bluetooth uses Godot's Android plugin v2 and a secure RFCOMM connection between two devices paired in system settings. The plugin requests BLUETOOTH_CONNECT and uses neither scanning nor location. Android allows launch of the solo game on devices without Bluetooth. The plugin exposes a separately built AAR for the Gradle APK export, which remains a manual workflow.

The validation workflow compiles the AAR and runs Godot's host/guest tests with an in-memory transport. Physical devices are needed to verify pairing, permission dialogs, throughput and reconnect behavior over real Bluetooth. Both devices must run the same build for the current co-op protocol. APK export needs separate user authorization.
