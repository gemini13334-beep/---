# Blender build recovery
Confirmed failure: Blender 5.0.1 distro package lacked NumPy, causing glTF export to fail after saving hero.blend. Install python3-numpy and python3-pil alongside Blender; preflight import inside Blender; fail on generation errors. Verify all fourteen GLB and BLEND pairs in standalone workflow. Do not claim success until artifacts exist.
