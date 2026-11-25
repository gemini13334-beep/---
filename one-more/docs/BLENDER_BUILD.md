# Blender build recovery
Confirmed missing NumPy in distro Blender 5.0.1. Shared installer tests NumPy and actual glTF exporter import, falls back to official portable Blender 4.5.3 LTS if distro installation or preflight fails. Fallback is not yet verified in CI. Strict model verification remains mandatory in standalone asset workflow.
