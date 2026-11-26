# ONE MORE

Portrait survival arcade game for Godot 4.4.1. Drag on the arena or use the arrow keys to move. Weapons fire automatically at nearby enemies. Play Endless, a 60-second Score Attack or a ranked Gate.

Run the project with `godot --path one-more`. To use the production models, run `blender -b -t 2 --python-exit-code 1 -P one-more/tools/generate_assets.py` first, then import the project with `godot --headless --path one-more --editor --import`.

The validation, Blender and screenshot workflows run independently of Android export. The Android workflow is manual and requires separate authorization.
