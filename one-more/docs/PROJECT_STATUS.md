# ONE MORE project status

## Current stage

- Android export requires a manual dispatch and separate authorization. The existing timeout, log upload and APK compatibility checks remain in the workflow.
- Godot imports the 32 runtime GLB scenes. Blender source files are available alongside the GLBs from the asset workflow.
- The forest arena has new ground shading and instanced foliage. Map shading distinguishes streets, sand, ice and volcanic terrain. The current art pass revises SLIME, CRYO, enemy silhouettes, the crystal boss and destructible crates.
- The combat HUD, character showcase and settings panels have new layouts. The screenshot workflow captures these screens, the other arenas, upgrade offers and progression screens.
- Automated tests cover settings, touch, combat, sprint, gate completion, quest claims, stats and legacy or damaged profile recovery. Android device performance, physical touch and haptics, and an audible mix review remain open.

## Next art pass

Develop the other biome silhouettes and compositions to the same level as the forest. Check them in actual gameplay, including enemy visibility during dense effects and legibility across portrait aspect ratios.

## Russian interface and Bluetooth

The current menu and game screens use Russian labels. The menu draws separately from the arena using original key art. Forest gameplay uses photographed-style ground shading, weathered rock meshes and conifer silhouettes. The screenshots workflow captures the Russian game and co-op lobby.

The two-player Android co-op mode shares an authoritative host simulation. The Android library and game protocol have separate build and test steps. Physical Bluetooth testing is pending.

## Forest environment pass

The forest arena now has a slate trail with relief and canopy lighting, material-mapped boulders and ruins, instanced ferns and mesh-based fir branchlets. The new scenery is visual and the original arena movement rules still apply. Graphics presets adjust fern density, and the medium preset enables 2× MSAA for new settings. The screenshot workflow captures the trail and a second view at the ruined wall.

## Character and equipment pass

Original hero, enemy, boss, vehicle and crate models replace the previous roster. Hero weapons export their muzzle locations, and the regular enemy silhouettes distinguish a ground scout, flying interceptor and tracked armour. The art change also reworks city, desert, ice and volcanic formations and their decorative props. Godot gallery renders cover all 17 characters and equipment assets.

## Combat HUD and character motion

The Russian combat HUD draws live pickups, score, combo, health, experience, current quest progress and acquired upgrade ranks. Its minimap marks local actors and shared Bluetooth replicas. The range control shows the auto-fire radius used by the simulation. Opening settings from a run preserves it, and the co-op menu leaves the partner in combat.

Vega starts new profiles. Existing profiles retain their selected hero. The four operators have Blender rigs and exported action clips. Mechanical opponents telegraph attacks and react to shots using their moving joints. The capture workflow checks the imported rigs and records motion from the game.

The combat HUD uses illustrated skill and equipment cards, with an overhead arena render reused as the minimap background. Counters respond to pickups, changes in health, and leveling. Players can inspect a skill or a piece of equipment during combat.

## Expanded arenas and operator gait

Playable bounds are 96 × 96 world units, with terrain extending to 166 × 166 so the combat camera remains over solid terrain at the outermost corners. The minimap and Bluetooth snapshots share the new bounds. Walkable terrain varies in elevation. Crates, characters, props and local effects are placed from the same height function. City, desert, glacier and volcano use individual surface textures, grouped props and distinct relief. The layout supports the existing combat rules.

The four human operators use separate walk and run clips selected according to movement speed. Blender validates the knee pole and support foot height at each frame. Their trousers use blended weights across each knee; the revised shoulder plates, footwear and facial geometry are baked into the original models.
