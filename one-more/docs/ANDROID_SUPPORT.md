# Android support

The Android preset uses the Godot 4.4.1 Gradle template with minSdk 34, targetSdk 35 and ARM64. The manual Android workflow retains bounded import and export, logs, and APK manifest verification.

Bluetooth uses Godot's Android plugin v2 and a secure RFCOMM connection between two devices paired in system settings. The plugin requests BLUETOOTH_CONNECT and uses neither scanning nor location. Android allows launch of the solo game on devices without Bluetooth. The plugin exposes a separately built AAR for the Gradle APK export, which remains a manual workflow.

The validation workflow compiles the AAR and runs Godot's host/guest tests with an in-memory transport. Physical devices are needed to verify pairing, permission dialogs, throughput and reconnect behavior over real Bluetooth. APK export needs separate user authorization.
