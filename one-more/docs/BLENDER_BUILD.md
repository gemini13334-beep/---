# Blender build recovery
Confirmed missing NumPy in distro Blender 5.0.1. Shared installer tests NumPy and actual glTF exporter import, falls back to official portable Blender 4.5.3 LTS if distro installation or preflight fails. Fallback is not yet verified in CI. Strict model verification remains mandatory in standalone asset workflow.

Blender produces both editable `.blend` sources and runtime `.glb` scenes. Godot imports the GLB scenes. Native `.blend` import is disabled in `project.godot`, so Godot does not invoke Blender again during project import. Both file types remain available from the Blender workflow artifact.
