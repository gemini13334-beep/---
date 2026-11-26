# Procedural asset manifest

`tools/generate_assets.py` builds the scenery and calls `tools/combat_models.py` and `tools/human_models.py` for actors and equipment. The Blender workflow exports 32 editable source files and runtime GLBs, plus 32 preview renders. Godot imports the GLBs and renders four galleries. The robot and vehicle GLBs batch surfaces by material at each movable joint.

| Use | Model basenames |
| --- | --- |
| Mechanical heroes | hero, cyborg, inferno, ghost, titan, cryo |
| Operators | vega, fox, amber, north |
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

## Character and equipment art

ONE MORE uses original geometry and generated materials. The six mechanical heroes export a `ShotOrigin` marker attached to a weapon pivot. Vega, Fox, Amber and North have an armature, a textured skinned mesh, a `Muzzle` bone and five keyframed clips for idle, running, firing, impact and falling. The models face Blender −Y and stand on Z=0.

`assets/portraits/` contains ten original HUD portraits rendered directly from the Blender models. Regenerate them after model export with `blender -b -P one-more/tools/generate_assets.py -- --portraits`. Character paint, steel patina and wear textures are generated and packed into the model files. The original six hero IDs remain valid in profiles and cooperative messages.
