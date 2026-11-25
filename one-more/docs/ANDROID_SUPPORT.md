# Android support
Required supported baseline: Android 14 (API 34), ARM64. Newer Android releases are intended to be supported. Compatibility renderer remains enabled. CI verifies APK manifest minSdk <= 34, targetSdk >= 34 and ARM64. Older Android installation is not deliberately blocked. Manifest verification is not a device runtime test. Test on physical Android 14 before declaring support.
