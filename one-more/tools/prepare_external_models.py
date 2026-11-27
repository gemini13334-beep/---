"""Embed the approved source atlas and simplify the road-barrier scan for mobile."""
from pathlib import Path
import sys

import bpy
from mathutils import Vector


def prepare(source, destination, triangle_limit):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise ValueError(f"No geometry in {source}")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    model = bpy.context.object
    parts = len(model.data.loop_triangles)
    if triangle_limit and parts > triangle_limit:
        reduction = model.modifiers.new("Mobile triangle budget", "DECIMATE")
        reduction.ratio = triangle_limit / parts
        bpy.ops.object.modifier_apply(modifier=reduction.name)
    corners = [Vector(corner) for corner in model.bound_box]
    lo = Vector(tuple(min(corner[axis] for corner in corners) for axis in range(3)))
    hi = Vector(tuple(max(corner[axis] for corner in corners) for axis in range(3)))
    model.location = Vector((-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z))
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    model.name = destination.stem
    for paint in model.data.materials:
        if paint is not None:
            paint.use_backface_culling = True
    bpy.ops.file.pack_all()
    if "FINISHED" not in bpy.ops.export_scene.gltf(
        filepath=str(destination), export_format="GLB", use_selection=True, export_animations=False
    ):
        raise RuntimeError(f"Export failed for {destination}")
    triangles = len(model.data.loop_triangles)
    if triangle_limit and triangles > triangle_limit:
        raise RuntimeError(f"Triangle budget exceeded for {destination}: {triangles}")
    print(f"{destination.name}: {parts} → {triangles} triangles")


if __name__ == "__main__":
    source, destination, limit = sys.argv[sys.argv.index("--") + 1:]
    prepare(Path(source), Path(destination), int(limit))
