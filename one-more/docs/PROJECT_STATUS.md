# ONE MORE project status

## Current stage

- Android export requires a manual dispatch and separate authorization. The existing timeout, log upload and APK compatibility checks remain in the workflow.
- Godot imports the 28 runtime GLB scenes. Blender source files are available alongside the GLBs from the asset workflow.
- The forest arena has new ground shading and instanced foliage. Map shading distinguishes streets, sand, ice and volcanic terrain. The current art pass revises SLIME, CRYO, enemy silhouettes, the crystal boss and destructible crates.
- The combat HUD, character showcase and settings panels have new layouts. The screenshot workflow captures these screens, the other arenas, upgrade offers and progression screens.
- Automated tests cover settings, touch, combat, sprint, gate completion, quest claims, stats and legacy or damaged profile recovery. Android device performance, physical touch and haptics, and an audible mix review remain open.

## Next art pass

Develop the other biome silhouettes and compositions to the same level as the forest. Check them in actual gameplay, including enemy visibility during dense effects and legibility across portrait aspect ratios.

## Russian interface and Bluetooth

The current menu and game screens use Russian labels. The menu draws separately from the arena using original key art. Forest gameplay uses photographed-style ground shading, weathered rock meshes and conifer silhouettes. The screenshots workflow captures the Russian game and co-op lobby.

The two-player Android co-op mode shares an authoritative host simulation. The Android library and game protocol have separate build and test steps. Physical Bluetooth and Android export are pending.
