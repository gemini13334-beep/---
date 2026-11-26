# Blender build recovery
The shared installer first checks the existing Blender binary, NumPy and the glTF exporter. Package downloads and installation have explicit timeouts. If the distro build cannot be installed or fails preflight, the installer tries the official portable Blender 4.5.3 LTS archive with a bounded download and extraction. Strict model verification remains mandatory in the standalone asset workflow.

Blender produces both editable `.blend` sources and runtime `.glb` scenes. Godot imports the GLB scenes. Native `.blend` import is disabled in `project.godot`, so Godot does not invoke Blender again during project import. Both file types remain available from the Blender workflow artifact.
