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

## Original environment images

Generated for ONE MORE with OpenAI ImageGen in the November 2026 art pass. The images are stored as JPEGs for the game. They contain no interface or lettering.

| File | Purpose | SHA-256 |
| --- | --- | --- |
| `assets/art/gate-valley.jpg` | Portrait menu backdrop | `f402422caf4ce435d5ad7f576f6ce7056ba1755d10642dc448a9d125e9f47b7b` |
| `assets/art/forest-ground.jpg` | Repeating forest albedo with mipmaps | `fc77f124665090fd5086672eb5411ce3f6735301c539258e7aa6e262c88f584f` |
| `assets/art/forest-slate.jpg` | Forest trail and triplanar masonry material | `9c570d539b0f84c428095120a0f70fa37126220ee2dce4d5787929c5cdd0b6f9` |
| `assets/art/forest-fern.png` | Mipmapped alpha-scissor foliage shared by instanced forest plants | `40964c2228e76a6c9ab3dfb5ddb24b49d93ec0dd29e3bd6b605d009e4084ca60` |
