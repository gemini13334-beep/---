# Polish priority
Freeze new feature expansion until existing gameplay, menus, Awakening, quests and gates pass regression tests and visual review. Prioritize readable effects, layered audio, animation, lighting and real screenshots. Keep Android 14+ and high refresh options. Use verified free assets without account requirements. Do not claim device performance or visual quality without evidence.

## Release ledger — 2026-11-25
Baseline: d86a9ed739500763ad35cba4349edf10b7734eed.
Count: **25 confirmed substantive polish updates (20 required)**. The numbered 20th commit (12694526) adds regression tests only and is not counted under the substantive-change rule.

| # | Commit | Change |
|---|---|---|
| 1 | 460a50b9 | Combat audio |
| 2 | a07613f1 | Materials |
| 3 | d546e14c | Terrain |
| 4 | 901b2be8 | Animation |
| 5 | 2b290a80 | HUD |
| 6 | 1c36831f | Awakening UI |
| 7 | 249c8fe2 | Hero models |
| 8 | 73731569 | Enemy models |
| 9 | 5bef5907 | Vehicles |
| 10 | c3760fd5 | Ambience |
| 11 | 63d2f1ab | Combat VFX |
| 12 | 0fb5b837 | Biome props |
| 13 | f54f2f5e | Lighting |
| 14 | 63ae1cca | Resource caching |
| 15 | 6b49ea08 | Settings tabs |
| 16 | cb8bd1a7 | Graphics presets |
| 17 | f58a2ece | Touch controls |
| 18 | 6678959c | Audio mixer |
| 19 | 1bfd73a1 | Settings usability |

| 20 | 5153c583 | Profile recovery and touch cleanup |
| 21 | 6fa5fa4a | Arena and HUD visual pass |
| 22 | 4b087207 | Forest cover and terrain materials |
| 23 | fc363c0a | Combat character and equipment models |
| 24 | cc576dc0 | Human character animation and combat HUD |
| 25 | ae4d0d7f | HUD readability and Android texture configuration |

Android run [45696551115](https://github.com/gemini13334-beep/---/actions/runs/45696551115) was cancelled during Godot import. The subsequent [45779859370](https://github.com/gemini13334-beep/---/actions/runs/45779859370) reached the 420-second import timeout before APK export. Godot stalled after scanning `.blend` and `.glb` files. Disabling native `.blend` import allowed a clean Godot 4.4.1 import of all 28 GLB scenes. The Android workflow uses `workflow_dispatch` and requires separate user authorization.

## First APK — 2026-11-26
The six additional entries above were verified against main ancestry and actual changed game files; documentation and CI-only changes are excluded. This is a confirmed minimum, not an exhaustive audit of every intervening commit. [Run 45889567694](https://github.com/gemini13334-beep/---/actions/runs/45889567694) at `9ada4ec87558cfc968e6afc44d1ffa65c62888fc` completed Blender generation, Godot import, APK export and Android 14 compatibility checks successfully. [Android archive](https://github.com/gemini13334-beep/---/actions/runs/45889567694/artifacts/15151485889). The single-build authorization is consumed; do not dispatch or rerun Android without new explicit authorization. Device FPS and usability remain unverified.
