# Procedural asset manifest

The original models are authored by `tools/generate_assets.py`. Every entry has editable Blender geometry and a runtime GLB. The GLB batches the static geometry by material, while the Blender source retains the separately named parts and modifiers. Godot uses the GLB scenes at runtime. The standalone Blender workflow produces the model files and preview images.

| Use | Model basenames |
| --- | --- |
| Heroes | hero, cyborg, inferno, ghost, titan, cryo |
| Enemies | enemy, enemy_fast, enemy_armored |
| Bosses | boss_overlord, boss_crystal, boss_inferno |
| Vehicles | buggy, hovercraft, tank, mech |
| Arena props | crate, forest, city, desert, ice, volcano, tree, rock, ruin, cactus, ice_spire, lava_vent |

The terrain and forest fronds are procedural Godot assets. Ambient music and effects are synthesized by the game. This revision adds no third-party files or runtime dependencies.
