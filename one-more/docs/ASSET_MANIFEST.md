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

## Illustrated combat HUD

OpenAI ImageGen created an original atlas for the combat kit and 16 abilities. The game uses 112 × 112 WebP tiles in `assets/hud/`, ordered by the original ability IDs. Four tiles also illustrate equipment stats while a new run has available slots. The input atlas SHA-256 is `2fa5824657dabf87e539ca4d5416c5f71cc82cc4c12ce509e1c9caf4d73ddbdc`.

## Arena surfaces

Four 512 × 512 albedo textures from an original OpenAI ImageGen material sheet cover broken asphalt, stratified sandstone, fractured glacial ice and cooled basalt. The arena shader blends rotated samples at two scales. The source atlas SHA-256 is `d6c17f6e419b4c3226f87bcee858b91f071afef6e36601ce127867923941ef6d`.

## Third-party files used in the game

The game ships selected files in `assets/vendor/` and loads them from the package. It requires no service, third-party addon, telemetry, or downloads at runtime. License texts are in `assets/vendor/licenses/`. `assets/vendor/SHA256SUMS` pins the files shipped here.

| Author / source | Version and permissions | Integrated files |
| --- | --- | --- |
| Kenney Vleugels, [City Kit Industrial](https://opengameart.org/content/city-kit-industrial) | 2.0, CC0 1.0, archive SHA-256 `5b381164e5760f3830a2dbee43b972deee38b2a695d091b56e238ab2910c96d2` | Two factory buildings, a shipping container and a water tower. Blender embedded the atlas and normalized the pivots. The city layout uses them as scenery. |
| Amal Kumar, [Concrete Road Barrier](https://polyhaven.com/a/concrete_road_barrier) | Poly Haven 1K release, 2023-08-18, CC0 1.0. Original glTF manifest MD5 `6d6feaf068f434e8dc163a1a9d983f4a`, original geometry MD5 `f256cb4d2bd9e5623b062502605dfcf2` | 2,300 triangles and embedded 512 px textures. Used for street barricades. |
| Dario Barresi and Charlotte Baglioni, [Concrete Wall 008](https://polyhaven.com/a/concrete_wall_008) | Poly Haven 1K release, file revision `d77307121f21d7ce51b194dcc7456117afe03dd4`, CC0 1.0 | Diffuse, normal, and roughness maps resized to 512 px for factories and existing city ruins. |
| Kenney Vleugels, [50 RPG sound effects](https://opengameart.org/content/50-rpg-sound-effects) | Author's CC0 1.0 archive, SHA-256 `3ae398ad63e293f9c450bda22d5d81c3af69c74df66fc1400f33c012c0bbc231` | Three metal impact and two pickup variations. Trimmed, capped, and converted to mono Vorbis for rapid combat events. |
| The Exo 2 Project Authors, [Exo 2](https://github.com/google/fonts/tree/441734fe1262150806e3b8d2410fbd85ebf541eb/ofl/exo2) | Google Fonts Git commit `441734fe1262150806e3b8d2410fbd85ebf541eb`, SIL OFL 1.1 | Unmodified variable font used for the title and the Russian combat HUD. |

The Poly Haven license declaration is at [polyhaven.com/license](https://polyhaven.com/license). The original geometry and the Kenney palette were imported as glTF data using Blender with automatic script execution disabled. `tools/prepare_external_models.py` reproduces the pivot normalization, embedded resources and mesh simplification from those inputs.
