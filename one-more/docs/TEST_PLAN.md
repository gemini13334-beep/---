# Gameplay regression

Godot 4.4.1 validation uses separate profile directories for the solo and co-op tests.

- `tests/gameplay_test.gd` checks settings, touch, enemy spawning and damage, upgrades, boss attacks, defeat and restart, the 60-second limit, quests, gates, and legacy or corrupt profile recovery. The corrupt fixture produces a ConfigFile diagnostic as part of the backup recovery case.
- `tests/coop_test.gd` runs two arenas over an in-memory link. It checks the map handshake, authoritative movement and actors, damage, upgrade pauses, shared results, and cleanup after disconnection. The Android validation job separately builds the Bluetooth AAR.
- `tests/capture.gd` runs the graphical game with generated models. It checks portrait panel bounds and menu button spacing and captures the forest trail, ruins, other arenas, hero views, and menus.
- Physical Android checks cover permissions, pairing, an actual two-phone run, touch comfort, audio, and frame times. APK export requires separate authorization.
