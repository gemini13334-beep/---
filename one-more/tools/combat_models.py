"""Original characters and equipment for ONE MORE.

Blender units are metres. Models face -Y and stand on Z=0.
"""

from math import cos, pi, sin, tau

import bpy
import numpy as np
from mathutils import Vector


CHAMFER = [
    (-0.70, -1.0), (0.70, -1.0), (1.0, -0.63), (1.0, 0.63),
    (0.70, 1.0), (-0.70, 1.0), (-1.0, 0.63), (-1.0, -0.63),
]
WEAR_SIZE = 128


def finish_texture(name, color, metal):
    """Bake a small, tileable colour map for each non-luminous finish."""
    rng = np.random.default_rng(sum((i + 1) * ord(c) for i, c in enumerate(name)))
    row, column = np.mgrid[:WEAR_SIZE, :WEAR_SIZE]
    wave = column * tau / WEAR_SIZE
    ridge = row * tau / WEAR_SIZE
    grain = rng.normal(0, 0.019, row.shape)
    cloudy = 0.035 * np.sin(3 * wave + 2 * np.sin(ridge)) * np.cos(4 * ridge - wave)
    machining = 0.011 * np.sin(ridge * 31 + 2 * np.cos(wave))
    scuffs = np.maximum(0.0, np.sin(29 * ridge + 3 * np.sin(3 * wave)) - 0.94)
    scuffs *= np.maximum(0.0, np.sin(4 * wave - 2 * ridge) + 0.25)
    chips = rng.random(row.shape) > 0.992
    wear = np.clip(1.0 + cloudy + grain + metal * machining, 0.86, 1.12)
    rgb = np.asarray(color) * wear[..., None]
    rgb += (scuffs * 0.24 * metal + chips * 0.033)[..., None]
    rgb = np.clip(rgb, 0.0, 1.0)
    srgb = np.where(rgb <= 0.0031308, rgb * 12.92, 1.055 * rgb ** (1 / 2.4) - 0.055)
    pixels = np.ones((WEAR_SIZE, WEAR_SIZE, 4), dtype=np.float32)
    pixels[..., :3] = srgb
    image = bpy.data.images.new(name + " texture", WEAR_SIZE, WEAR_SIZE, alpha=False)
    image.pixels.foreach_set(pixels.ravel())
    image.pack()
    return image


def material(name, color, metal=0.0, roughness=0.6, emission=0.0):
    paint = bpy.data.materials.new(name)
    paint.diffuse_color = (*color, 1.0)
    paint.use_nodes = True
    shader = paint.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Metallic"].default_value = metal
    shader.inputs["Roughness"].default_value = roughness
    if emission:
        shader.inputs["Emission Color"].default_value = (*color, 1.0)
        shader.inputs["Emission Strength"].default_value = emission
    else:
        texture = paint.node_tree.nodes.new("ShaderNodeTexImage")
        texture.image = finish_texture(name, color, metal)
        texture.location = (-320, 240)
        paint.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    return paint


def finish(obj, paint, bevel=0.0):
    obj.data.materials.append(paint)
    if bevel:
        edge = obj.modifiers.new("Machined edges", "BEVEL")
        edge.width = bevel
        edge.segments = 2
        normals = obj.modifiers.new("Corner normals", "WEIGHTED_NORMAL")
        normals.keep_sharp = True
    return obj


def mesh(name, vertices, faces, paint, bevel=0.0):
    geometry = bpy.data.meshes.new(name)
    geometry.from_pydata(vertices, [], faces)
    geometry.update()
    uv_map = geometry.uv_layers.new(name="UVMap")
    for face in geometry.polygons:
        axis = max(range(3), key=lambda i: abs(face.normal[i]))
        u, v = [i for i in range(3) if i != axis]
        for index in face.loop_indices:
            point = geometry.vertices[geometry.loops[index].vertex_index].co
            uv_map.data[index].uv = (point[u] * 1.7, point[v] * 1.7)
    obj = bpy.data.objects.new(name, geometry)
    bpy.context.collection.objects.link(obj)
    return finish(obj, paint, bevel)


def shell(name, rings, paint, bevel=0.018, profile=CHAMFER):
    """Loft rings written as height, half-width, half-depth, x and y."""
    vertices = [
        (x + u * width, y + v * depth, height)
        for height, width, depth, x, y in rings
        for u, v in profile
    ]
    sides = len(profile)
    faces = [tuple(reversed(range(sides)))]
    for row in range(len(rings) - 1):
        for side in range(sides):
            start = row * sides
            following = (side + 1) % sides
            faces.append((start + side, start + following, start + sides + following, start + sides + side))
    faces.append(tuple(range(len(vertices) - sides, len(vertices))))
    return mesh(name, vertices, faces, paint, bevel)


def slab(name, center, half_size, paint, bevel=0.016, tilt=0.0):
    x, y, z = center
    width, depth, height = half_size
    obj = shell(name, [(-height, width, depth, 0, 0), (height, width, depth, 0, 0)], paint, bevel)
    obj.location = (x, y, z)
    obj.rotation_euler.z = tilt
    return obj


def lens(name, center, size, paint, faceted=False):
    if faceted:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, location=center)
    else:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = size
    if not faceted:
        for face in obj.data.polygons:
            face.use_smooth = True
    return finish(obj, paint)


def shaft(name, start, end, radius, paint, tip=None, sides=12):
    axis = Vector(end) - Vector(start)
    bpy.ops.mesh.primitive_cone_add(
        vertices=sides, radius1=radius, radius2=radius if tip is None else tip,
        depth=axis.length, location=Vector(start) + axis / 2,
    )
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = axis.to_track_quat("Z", "Y").to_euler()
    for face in obj.data.polygons:
        face.use_smooth = len(face.vertices) == 4
    return finish(obj, paint)


def hoop(name, center, radius, tube, paint, rotation=(0, 0, 0), arc=tau):
    segments = 28
    vertices = []
    sides = 8
    for i in range(segments + 1):
        angle = arc * i / segments
        for j in range(sides):
            section = j * tau / sides
            reach = radius + tube * cos(section)
            vertices.append((reach * cos(angle), reach * sin(angle), tube * sin(section)))
    faces = []
    for i in range(segments):
        for j in range(sides):
            a = i * sides + j
            b = i * sides + (j + 1) % sides
            faces.append((a, a + sides, b + sides, b))
    obj = mesh(name, vertices, faces, paint)
    obj.location = center
    obj.rotation_euler = rotation
    for face in obj.data.polygons:
        face.use_smooth = True
    return obj


def plate(name, points, floor, ceiling, paint, bevel=0.015):
    count = len(points)
    winding = sum(
        points[i][0] * points[(i + 1) % count][1] - points[(i + 1) % count][0] * points[i][1]
        for i in range(count)
    )
    if winding < 0:
        points = list(reversed(points))
    vertices = [(x, y, height) for height in (floor, ceiling) for x, y in points]
    faces = [tuple(reversed(range(count))), tuple(range(count, count * 2))]
    for i in range(count):
        j = (i + 1) % count
        faces.append((i, j, j + count, i + count))
    return mesh(name, vertices, faces, paint, bevel)


def light_at(name, x, y, z, width, height, glow):
    return slab(name, (x, y, z), (width, 0.018, height), glow, 0.004)


def muzzle_marker(point):
    marker = bpy.data.objects.new("ShotOrigin", None)
    marker.location = point
    marker.empty_display_size = 0.065
    marker.empty_display_type = "SPHERE"
    bpy.context.collection.objects.link(marker)


def rifle(x, y, z, armor, structural, steel, light, length, paired=False):
    slab("Weapon receiver", (x, y - 0.09, z), (0.134, 0.23, 0.103), armor)
    slab("Weapon shroud", (x, y - 0.20, z + 0.077), (0.102, 0.145, 0.051), structural)
    for offset in ((-0.061, 0.061) if paired else (0,)):
        start = (x + offset, y - 0.25, z)
        end = (x + offset, y - length, z)
        shaft("Barrel", start, end, 0.048, steel)
        shaft("Muzzle collar", (end[0], end[1] + 0.112, z), end, 0.071, structural)
        shaft("Emitter bore", (end[0], end[1] + 0.010, z), (end[0], end[1] - 0.005, z), 0.034, light)
    for i in range(3):
        slab("Receiver ribs", (x, y - 0.12 - i * 0.064, z + 0.122), (0.08, 0.019, 0.014), steel, 0.005)
    muzzle_marker((x, y - length - 0.015, z))


def boots(sign, x, calf_height, armor, frame, steel):
    x *= sign
    shell("Split sole boot", [
        (0.018, 0.125, 0.235, x, -0.068),
        (0.087, 0.148, 0.254, x, -0.062),
        (0.18, 0.119, 0.157, x, 0.011),
    ], frame)
    slab("Toe strike plate", (x, -0.222, 0.111), (0.108, 0.075, 0.049), steel, 0.009)
    shaft("Ankle ram", (x, 0.044, 0.12), (x, 0.018, calf_height), 0.047, steel)
    shell("Greave", [
        (0.15, 0.090, 0.099, x, 0.013),
        (0.27, 0.125, 0.121, x, -0.024),
        (calf_height, 0.079, 0.092, x, 0.031),
    ], armor)


def slime(frame, steel):
    jade = material("Verdigris ceramic", (0.028, 0.20, 0.128), 0.26, 0.39)
    gel = material("Translucent-looking hydrogel coat", (0.018, 0.33, 0.173), 0.05, 0.3)
    optic = material("Smoked lab glass", (0.008, 0.028, 0.023), 0.44, 0.25)
    light = material("Mint capillary light", (0.078, 0.68, 0.41), emission=1.45)
    shell("Mobile containment chassis", [
        (0.13, 0.36, 0.22, 0, 0.02),
        (0.27, 0.57, 0.38, 0, 0.01),
        (0.49, 0.52, 0.36, 0, 0.02),
        (0.63, 0.41, 0.26, 0, 0.03),
    ], jade, 0.03)
    lens("Asymmetric gel mass", (0.0, 0.012, 0.83), (0.43, 0.33, 0.37), gel)
    for radius, height in ((0.405, 0.59), (0.367, 0.69)):
        hoop("Retention band", (0, 0.034, height), radius, 0.033, steel)
    lens("Reinforced inspection window", (0, -0.283, 0.775), (0.37, 0.104, 0.128), frame)
    lens("Optical glass", (0, -0.336, 0.78), (0.319, 0.077, 0.083), optic)
    for side in (-1, 1):
        light_at("Optic split", side * 0.15, -0.406, 0.789, 0.071, 0.023, light)
        slab("Stabilizer arm", (side * 0.53, 0.01, 0.39), (0.137, 0.241, 0.129), jade, tilt=side * 0.21)
        shaft("Hover cushion", (side * 0.46, 0.075, 0.055), (side * 0.46, 0.075, 0.25), 0.126, frame)
        hoop("Ion ring", (side * 0.46, 0.075, 0.095), 0.103, 0.018, light)
        shaft("Rear reagent vial", (side * 0.235, 0.355, 0.33), (side * 0.235, 0.355, 0.72), 0.075, steel)
        slab("Tank sight glass", (side * 0.235, 0.425, 0.56), (0.029, 0.02, 0.088), light, 0.008)
    light_at("Front charge aperture", 0, -0.371, 0.39, 0.088, 0.057, light)
    rifle(0.65, -0.026, 0.397, jade, frame, steel, light, 0.67)


def cyborg(frame, steel):
    armor = material("Ceramic cobalt", (0.056, 0.15, 0.27), 0.55, 0.37)
    light = material("Cobalt telemetry", (0.11, 0.52, 0.91), emission=1.3)
    shell("Narrow field cuirass", [
        (0.47, 0.21, 0.14, 0, 0.045), (0.59, 0.22, 0.18, 0.015, 0.027),
        (0.78, 0.37, 0.20, 0, 0.012), (0.97, 0.29, 0.17, -0.02, 0.043),
    ], armor, 0.023)
    shell("Helmet with pointed chin", [
        (0.96, 0.146, 0.16, 0, -0.035), (1.074, 0.233, 0.222, 0, -0.033),
        (1.28, 0.208, 0.165, 0, 0.022), (1.38, 0.127, 0.132, 0, 0.05),
    ], steel)
    slab("Single sensor slit recess", (0, -0.252, 1.13), (0.193, 0.042, 0.074), frame, 0.01)
    light_at("Single sensor slit", -0.018, -0.291, 1.139, 0.129, 0.017, light)
    for side in (-1, 1):
        boots(side, 0.235, 0.43, armor, frame, steel)
        shaft("Hip linkage", (side * 0.22, 0.048, 0.38), (side * 0.17, 0.026, 0.58), 0.056, steel)
        lens("Shoulder socket", (side * 0.365, 0.027, 0.799), (0.134, 0.13, 0.127), frame)
        shaft("Arm skeleton", (side * 0.413, 0.03, 0.79), (side * 0.52, -0.06, 0.49), 0.054, steel)
    slab("Left shield blade", (-0.49, 0.015, 0.72), (0.12, 0.216, 0.17), armor, tilt=-0.19)
    slab("Backplate cylinder rack", (0, 0.259, 0.775), (0.235, 0.118, 0.215), frame)
    shaft("Radio aerial", (-0.25, 0.30, 0.89), (-0.30, 0.334, 1.53), 0.028, steel, 0.012, 8)
    light_at("Chest data strip", 0, -0.197, 0.792, 0.089, 0.023, light)
    rifle(0.53, -0.02, 0.604, armor, frame, steel, light, 0.70, paired=True)


def inferno(frame, steel):
    armor = material("Oxide firebrick armor", (0.28, 0.060, 0.024), 0.42, 0.52)
    brass = material("Furnace copper", (0.33, 0.141, 0.051), 0.68, 0.43)
    light = material("Ceramic heat light", (0.94, 0.21, 0.045), emission=1.6)
    shell("Sealed thermal suit", [
        (0.28, 0.27, 0.18, 0, 0.04), (0.47, 0.34, 0.26, 0, 0.035),
        (0.79, 0.43, 0.26, 0, 0.055), (0.97, 0.32, 0.2, 0, 0.092),
    ], armor, 0.034)
    shell("Breathing helmet", [
        (0.84, 0.185, 0.155, 0, -0.195), (1.01, 0.255, 0.2, 0, -0.13),
        (1.17, 0.202, 0.163, 0, -0.07), (1.21, 0.123, 0.111, 0, -0.015),
    ], frame)
    light_at("Visor slit", 0.0, -0.336, 1.035, 0.146, 0.026, light)
    slab("Jaw respirator", (0.0, -0.333, 0.904), (0.145, 0.057, 0.049), brass)
    for side in (-1, 1):
        boots(side, 0.253, 0.367, armor, frame, steel)
        lens("Heat shoulder plate", (side * 0.46, 0.025, 0.79), (0.205, 0.215, 0.17), armor, True)
        slab("Thermal mitt", (side * 0.48, -0.115, 0.46), (0.144, 0.169, 0.149), frame)
        shaft("Exhaust riser", (side * 0.309, 0.27, 0.68), (side * 0.42, 0.36, 1.36), 0.109, brass, 0.073)
        hoop("Manifold clamp", (side * 0.411, 0.353, 1.29), 0.078, 0.019, steel)
        light_at("Heat exchanger lamp", side * 0.40, 0.277, 1.252, 0.043, 0.027, light)
    for i in range(4):
        light_at("Radiant grille", 0, -0.245, 0.64 - i * 0.054, 0.148, 0.015, light)
    rifle(0.59, -0.04, 0.495, brass, frame, steel, light, 0.685)


def ghost(frame, steel):
    armor = material("Satin violet composite", (0.103, 0.063, 0.175), 0.42, 0.42)
    membrane = material("Graphite field veil", (0.036, 0.027, 0.061), 0.24, 0.5)
    light = material("Spectral violet conduction", (0.59, 0.32, 0.91), emission=1.5)
    shell("Tapered levitation frame", [
        (0.13, 0.11, 0.118, 0, 0.11), (0.41, 0.20, 0.18, 0, 0.064),
        (0.72, 0.34, 0.235, 0, 0.028), (0.99, 0.29, 0.215, 0, 0.027),
    ], armor)
    shell("Gliding cowl", [
        (0.75, 0.166, 0.15, 0, -0.155), (0.99, 0.24, 0.221, 0, -0.086),
        (1.224, 0.21, 0.191, 0, -0.036), (1.375, 0.104, 0.166, 0, 0.135),
    ], membrane)
    shell("Porcelain mask", [
        (0.902, 0.098, 0.064, 0, -0.237), (1.047, 0.153, 0.089, 0, -0.254),
        (1.181, 0.116, 0.058, 0, -0.246),
    ], steel, 0.011)
    light_at("Vertical mask seam", 0, -0.346, 1.071, 0.023, 0.089, light)
    for side in (-1, 1):
        shell("Floating mantle blade", [
            (0.14, 0.035, 0.067, side * 0.52, 0.216),
            (0.38, 0.116, 0.136, side * 0.456, 0.14),
            (0.74, 0.145, 0.188, side * 0.397, 0.028),
            (0.91, 0.093, 0.103, side * 0.32, 0.047),
        ], armor)
        shaft("Mantle edge filament", (side * 0.52, 0.13, 0.26), (side * 0.48, -0.126, 0.73), 0.016, light, 0.010, 8)
    hoop("Field stabilizer", (0, 0.1, 0.255), 0.174, 0.024, light)
    rifle(0.47, -0.07, 0.607, armor, frame, steel, light, 0.62)


def titan(frame, steel):
    armor = material("Loader ochre polymer", (0.43, 0.246, 0.072), 0.42, 0.52)
    light = material("Amber work indicators", (0.91, 0.49, 0.095), emission=1.25)
    shell("Load-bearing torso", [
        (0.33, 0.37, 0.24, 0, 0.012), (0.48, 0.51, 0.33, 0, -0.006),
        (0.78, 0.58, 0.31, 0, 0.021), (0.96, 0.46, 0.235, 0, 0.062),
    ], armor, 0.037)
    shell("Recessed operator compartment", [
        (0.775, 0.23, 0.15, 0, -0.199), (0.93, 0.29, 0.188, 0, -0.194),
        (1.112, 0.25, 0.145, 0, -0.09),
    ], frame)
    light_at("Operator viewplate", 0, -0.382, 0.956, 0.162, 0.037, light)
    for side in (-1, 1):
        boots(side, 0.31, 0.34, armor, frame, steel)
        shell("Shoulder shield", [
            (0.55, 0.16, 0.19, side * 0.58, -0.048),
            (0.73, 0.21, 0.24, side * 0.65, 0.01),
            (0.98, 0.175, 0.21, side * 0.64, 0.06),
        ], armor, 0.027)
        shaft("External piston", (side * 0.69, 0.155, 0.267), (side * 0.59, 0.155, 0.71), 0.056, steel)
        light_at("Shoulder hazard marker", side * 0.655, -0.236, 0.826, 0.081, 0.024, light)
        slab("Back counterweight", (side * 0.273, 0.345, 0.53), (0.174, 0.118, 0.194), frame)
    slab("Auxiliary breaker", (-0.70, -0.119, 0.415), (0.19, 0.19, 0.14), steel, 0.023)
    rifle(0.67, -0.04, 0.453, armor, frame, steel, light, 0.73, paired=True)


def cryo(frame, steel):
    armor = material("Glacier ceramic armor", (0.53, 0.63, 0.68), 0.23, 0.41)
    coil = material("Blue coolant ceramics", (0.047, 0.238, 0.36), 0.47, 0.34)
    light = material("Refrigerant blue", (0.12, 0.59, 0.88), emission=1.35)
    shell("Pressure suit torso", [
        (0.33, 0.25, 0.186, 0, 0.046), (0.49, 0.37, 0.234, 0, 0.045),
        (0.77, 0.45, 0.243, 0, 0.043), (0.93, 0.34, 0.174, 0, 0.077),
    ], armor, 0.023)
    shell("Pressure helmet", [
        (0.85, 0.179, 0.147, 0, -0.122), (1.045, 0.233, 0.203, 0, -0.095),
        (1.233, 0.19, 0.178, 0, -0.022), (1.312, 0.123, 0.111, 0, 0.022),
    ], armor)
    lens("Polarized face shield", (0, -0.279, 1.077), (0.197, 0.06, 0.095), frame)
    light_at("Goggle line", 0, -0.338, 1.092, 0.137, 0.019, light)
    for side in (-1, 1):
        boots(side, 0.233, 0.423, armor, frame, steel)
        slab("Expedition shoulder plates", (side * 0.445, 0.01, 0.782), (0.153, 0.22, 0.145), armor)
        shaft("Coolant reservoir", (side * 0.282, 0.266, 0.49), (side * 0.282, 0.33, 1.137), 0.105, coil)
        for height in (0.61, 0.995):
            hoop("Reservoir retention band", (side * 0.282, 0.279 + (height - 0.61) * 0.10, height), 0.104, 0.022, steel)
        shaft("Hose feed", (side * 0.285, 0.236, 0.504), (side * 0.399, -0.09, 0.419), 0.045, frame)
        light_at("Left and right pressure indicators", side * 0.232, -0.21, 0.614, 0.052, 0.024, light)
    rifle(0.542, -0.07, 0.505, coil, frame, steel, light, 0.69)


def scout(frame, steel):
    armor = material("Oxide field carapace", (0.27, 0.052, 0.032), 0.47, 0.46)
    light = material("Red hostile optical core", (0.9, 0.082, 0.045), emission=1.45)
    shell("Arthropod carrying frame", [
        (0.185, 0.29, 0.32, 0, 0.041), (0.34, 0.41, 0.41, 0, 0.055),
        (0.462, 0.34, 0.39, 0, 0.088), (0.523, 0.24, 0.30, 0, 0.135),
    ], armor, 0.024)
    shell("Jaw segment", [
        (0.195, 0.175, 0.136, 0, -0.346), (0.329, 0.24, 0.22, 0, -0.344),
        (0.404, 0.182, 0.149, 0, -0.362),
    ], frame)
    light_at("Three-part eye", 0, -0.558, 0.353, 0.089, 0.021, light)
    for side in (-1, 1):
        light_at("Outer optic", side * 0.145, -0.521, 0.349, 0.039, 0.026, light)
        for row in (-1, 1):
            joint = (side * 0.37, row * 0.236, 0.28)
            knee = (side * 0.585, row * 0.37, 0.142)
            claw = (side * 0.71, row * 0.405 + 0.024, 0.045)
            lens("Actuator joint", joint, (0.085, 0.087, 0.075), steel)
            shaft("Leg armor linkage", joint, knee, 0.074, armor, 0.049, 8)
            shaft("Ground hook", knee, claw, 0.049, frame, 0.019, 8)
        slab("Dorsal armor strip", (side * 0.165, 0.126, 0.476), (0.11, 0.223, 0.049), steel, tilt=side * 0.09)


def interceptor(frame, steel):
    armor = material("Oxide flight enamel", (0.38, 0.106, 0.038), 0.53, 0.43)
    light = material("Hot red turbofan light", (0.94, 0.143, 0.043), emission=1.55)
    shell("Arrowhead fuselage", [
        (0.19, 0.176, 0.397, 0, -0.034), (0.295, 0.205, 0.567, 0, -0.022),
        (0.447, 0.173, 0.459, 0, 0.052), (0.54, 0.12, 0.262, 0, 0.118),
    ], armor, 0.023)
    panel = [(-0.74, 0.34), (-0.58, 0.56), (-0.25, 0.36), (0, 0.318),
             (0.25, 0.36), (0.58, 0.56), (0.74, 0.34), (0, -0.273)]
    plate("Swept interceptor wing", panel, 0.275, 0.364, steel)
    for side in (-1, 1):
        x = side * 0.46
        shaft("Outboard engine pod", (x, 0.031, 0.328), (x, 0.43, 0.328), 0.091, frame)
        shaft("Rear nozzle glow", (x, 0.419, 0.328), (x, 0.459, 0.328), 0.063, light)
        fin = slab("Steering vane", (side * 0.54, 0.34, 0.488), (0.048, 0.177, 0.108), armor, tilt=side * 0.31)
        fin.rotation_euler.y = side * 0.23
    slab("Targeting nose", (0, -0.451, 0.30), (0.101, 0.111, 0.071), frame)
    light_at("Forward target lock", 0, -0.565, 0.318, 0.081, 0.017, light)


def tread_pair(x, z, travel, radius, width, frame, steel):
    for side in (-1, 1):
        offset = side * x
        for wheel in range(5):
            y = -travel + wheel * travel / 2
            shaft("Road wheel", (offset - width / 2, y, z), (offset + width / 2, y, z), radius, frame, sides=12)
            cap_start = offset + side * width * 0.48
            shaft("Hardened wheel hub", (cap_start, y, z), (cap_start + side * 0.037, y, z), radius * 0.59, steel)
        for row in (-1, 1):
            for index in range(11):
                y = (index - 5) * travel / 5
                slab("Tread shoe", (offset, y, z + row * radius), (width * 0.58, 0.045, 0.034), steel, 0.0)
        for end in (-1, 1):
            for i in range(3):
                angle = (i - 1) * pi / 4
                block = slab("Tread return shoe", (offset, end * (travel + radius * cos(angle)), z + radius * sin(angle)),
                             (width * 0.58, 0.032, 0.064), steel, 0.0)
                block.rotation_euler.x = end * angle


def armored(frame, steel):
    armor = material("Heavy scarab red oxide", (0.22, 0.04, 0.03), 0.62, 0.49)
    light = material("Scarab range finder", (0.95, 0.13, 0.05), emission=1.35)
    tread_pair(0.55, 0.173, 0.37, 0.122, 0.235, frame, steel)
    shell("Sloped scarab carapace", [
        (0.18, 0.57, 0.51, 0, 0.047), (0.35, 0.66, 0.62, 0, 0.027),
        (0.53, 0.55, 0.565, 0, 0.045), (0.71, 0.335, 0.355, 0, 0.151),
    ], armor, 0.027)
    for side in (-1, 1):
        slab("Split frontal glacis", (side * 0.32, -0.49, 0.383), (0.236, 0.168, 0.133), steel, tilt=side * 0.35)
        slab("Track guard", (side * 0.575, 0.06, 0.342), (0.135, 0.48, 0.076), armor)
    slab("Protected sensor bay", (0, -0.487, 0.482), (0.141, 0.102, 0.065), frame)
    light_at("Horizontal range finder", 0, -0.586, 0.492, 0.121, 0.023, light)
    for i in range(4):
        slab("Rear heat vent", (0, 0.27 + i * 0.063, 0.694 - i * 0.019), (0.173, 0.019, 0.015), frame, 0.006)


def overlord(frame, steel):
    armor = material("Burgundy command armor", (0.224, 0.048, 0.062), 0.47, 0.36)
    light = material("Command warning spectrum", (0.81, 0.089, 0.11), emission=1.7)
    shell("Command chassis", [
        (0.61, 0.44, 0.36, 0, 0.12), (0.92, 0.62, 0.40, 0, 0.105),
        (1.48, 0.71, 0.48, 0, 0.12), (1.74, 0.43, 0.35, 0, 0.08),
    ], armor, 0.038)
    shell("Narrow optical head", [
        (1.44, 0.214, 0.201, 0, -0.353), (1.63, 0.36, 0.22, 0, -0.313),
        (1.837, 0.274, 0.166, 0, -0.219),
    ], frame)
    light_at("Command visor", 0, -0.532, 1.692, 0.212, 0.042, light)
    for side in (-1, 1):
        x = side * 0.51
        shell("Command ground foot", [
            (0.035, 0.252, 0.343, x, -0.105), (0.19, 0.275, 0.364, x, -0.106),
            (0.34, 0.244, 0.22, x, 0.02),
        ], steel, 0.035)
        shaft("Hydraulic leg", (x, 0.053, 0.272), (side * 0.45, 0.106, 0.94), 0.153, frame)
        slab("Knee armour", (x, -0.103, 0.539), (0.218, 0.161, 0.215), armor)
        shell("High command shoulder", [
            (1.02, 0.26, 0.25, side * 0.86, 0.032),
            (1.36, 0.38, 0.34, side * 0.92, 0.056),
            (1.67, 0.29, 0.24, side * 0.83, 0.098),
        ], armor, 0.033)
        shaft("Arm cylinder", (side * 0.885, 0, 1.258), (side * 1.07, -0.182, 0.68), 0.151, steel)
        slab("Siege gauntlet", (side * 1.06, -0.245, 0.628), (0.239, 0.278, 0.179), frame)
        light_at("Shoulder declaration light", side * 0.91, -0.275, 1.40, 0.124, 0.035, light)
    hoop("Broken command halo", (0, 0.34, 1.84), 0.56, 0.068, steel, (pi / 2, 0, -0.39), pi * 1.68)
    hoop("Halo telemetry path", (0, 0.31, 1.845), 0.574, 0.026, light, (pi / 2, 0, -0.39), pi * 1.68)


def crystal(name, base, end, width, paint):
    direction = Vector(end) - Vector(base)
    height = direction.length
    obj = shell(name, [
        (0, width * 0.73, width * 0.78, 0, 0),
        (height * 0.30, width, width * 0.90, 0, 0),
        (height * 0.79, width * 0.83, width * 0.67, 0, 0),
        (height, width * 0.10, width * 0.14, 0, 0),
    ], paint, 0.0, [(cos(i * tau / 5), sin(i * tau / 5)) for i in range(5)])
    obj.location = base
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    return obj


def crystal_boss(frame, steel):
    stone = material("Deep glacial rock", (0.066, 0.132, 0.171), 0.2, 0.61)
    mineral = material("Glacial mineral prism", (0.16, 0.40, 0.55), 0.36, 0.26)
    frost = material("Pale mineral facet", (0.385, 0.568, 0.65), 0.25, 0.36)
    light = material("Ice blue core", (0.09, 0.60, 0.84), emission=1.45)
    lens("Riven glacial torso", (0.02, 0.06, 0.98), (0.65, 0.52, 0.73), stone, True)
    lens("Exposed fracture heart", (0, -0.414, 0.983), (0.274, 0.175, 0.311), light, True)
    hoop("Fracture containment belt", (0, 0.075, 0.826), 0.612, 0.049, steel)
    for side in (-1, 1):
        lens("Mineral foot", (side * 0.46, -0.147, 0.232), (0.31, 0.392, 0.241), stone, True)
        crystal("Crystal tibia", (side * 0.475, -0.04, 0.17), (side * 0.33, 0.06, 0.84), 0.258, mineral)
        lens("Stone shoulder mass", (side * 0.72, 0.02, 1.22), (0.36, 0.33, 0.31), stone, True)
        lens("Fractured forearm", (side * 0.95, -0.25, 0.654), (0.315, 0.38, 0.301), stone, True)
        crystal("Outward crystal arm", (side * 0.83, -0.02, 0.95), (side * 1.23, -0.07, 1.56), 0.138, frost)
        crystal("Forearm fang", (side * 0.94, -0.4, 0.66), (side * 1.13, -0.64, 0.31), 0.153, mineral)
    for i, (base, tip, width) in enumerate([
        ((-0.41, 0.13, 1.24), (-0.65, 0.28, 2.09), .179),
        ((-0.16, 0.11, 1.41), (-0.22, 0.08, 2.36), .233),
        ((0.21, 0.22, 1.36), (0.49, 0.41, 2.20), .263),
        ((0.32, -0.10, 1.46), (0.55, -0.40, 1.96), .171),
        ((-0.44, -0.19, 1.43), (-0.57, -0.40, 1.87), .107),
    ]):
        crystal("Asymmetric glacier crown", base, tip, width, frost if i % 2 == 0 else mineral)


def furnace_boss(frame, steel):
    basalt = material("Carbonized thermal hull", (0.073, 0.051, 0.046), 0.56, 0.56)
    copper = material("Fire-scaled furnace alloy", (0.30, 0.088, 0.036), 0.67, 0.45)
    light = material("Furnace exhaust spectrum", (0.95, 0.237, 0.036), emission=1.85)
    shell("Smelter core", [
        (0.26, 0.50, 0.33, 0, 0.09), (0.57, 0.74, 0.48, 0, 0.09),
        (1.15, 0.78, 0.55, 0, 0.12), (1.49, 0.61, 0.41, 0, 0.21),
    ], basalt, 0.045)
    lens("Incandescent furnace chamber", (0, -0.392, 0.925), (0.419, 0.235, 0.426), light)
    hoop("Refractory chamber collar", (0, -0.489, 0.915), 0.443, 0.069, copper, (pi / 2, 0, 0))
    for i in range(5):
        x = (i - 2) * 0.155
        slab("Refractory face ribs", (x, -0.586, 0.92), (0.038, 0.067, 0.269 - abs(i - 2) * 0.037), frame)
    for side in (-1, 1):
        stack_height = 2.10 if side == -1 else 1.89
        shaft("Auxiliary exhaust stack", (side * 0.50, 0.39, 0.96), (side * 0.57, 0.46, stack_height), 0.155, copper, 0.104)
        hoop("Hot stack rim", (side * 0.57, 0.46, stack_height), 0.102, 0.026, light)
        shaft("Furnace suspension", (side * 0.615, 0.12, 0.77), (side * 0.88, -0.03, 0.287), 0.179, steel)
        slab("Protective ground ram", (side * 0.86, -0.052, 0.245), (0.236, 0.387, 0.217), copper, 0.033)
        crystal("Forged intake spike", (side * 0.57, -0.243, 1.37), (side * 0.87, -0.53, 1.81), 0.153, basalt)
        light_at("Cooling status", side * 0.66, -0.381, 0.667, 0.112, 0.037, light)


def buggy(frame, steel):
    armor = material("Sandstone rally enamel", (0.30, 0.212, 0.106), 0.50, 0.46)
    tire = material("Grooved rubber", (0.024, 0.026, 0.024), 0.08, 0.82)
    light = material("Warm rally lamps", (0.91, 0.61, 0.32), emission=1.35)
    shell("Tapered scout buggy body", [
        (0.259, 0.44, 0.813, 0, 0.01), (0.43, 0.557, 0.963, 0, 0),
        (0.62, 0.51, 0.92, 0, 0.015), (0.71, 0.384, 0.67, 0, 0.035),
    ], armor, 0.032)
    for side in (-1, 1):
        for end in (-1, 1):
            x, y, z = side * 0.65, end * 0.625, 0.289
            shaft("Knobbly wheel carcass", (x - .119, y, z), (x + .119, y, z), .282, tire, sides=20)
            shaft("Wheel arm", (side * 0.39, y - 0.049, 0.461), (x, y, z), .054, steel)
            shaft("Alloy center", (x + side * 0.116, y, z), (x + side * 0.139, y, z), .132, steel)
            for tread in range(14):
                angle = tread * tau / 14
                block = slab("Raised tire tread", (x, y + .274 * cos(angle), z + .274 * sin(angle)),
                             (.123, .035, .027), tire, 0.0)
                block.rotation_euler.x = angle - pi / 2
        sx = side * 0.404
        shaft("Front cage stanchion", (sx, -0.415, .592), (sx * .81, -0.24, 1.07), .040, steel)
        shaft("Roof rail", (sx * .81, -.24, 1.07), (sx * .77, .25, 1.10), .044, steel)
        shaft("Rear cage stanchion", (sx * .77, .25, 1.10), (sx, .57, .615), .040, steel)
        light_at("Forward rally headlight", side * .316, -.924, .597, .119, .067, light)
    shaft("Cabin crossmember", (-.322, -.24, 1.07), (.322, -.24, 1.07), .043, steel)
    slab("Low cockpit seat", (0, .143, .703), (.187, .29, .113), frame)
    slab("Front crash beam", (0, -.959, .372), (.49, .096, .064), steel)
    for i in range(5):
        slab("Rear engine cooling rib", (0, .56 + i * .06, .691), (.209, .019, .027), frame, .008)


def hovercraft(frame, steel):
    armor = material("Patrol hover ceramic", (0.065, 0.264, 0.291), 0.44, 0.32)
    light = material("Air cushion plasma", (0.11, .68, .83), emission=1.35)
    hover_outline = [(-0.67, -0.65), (-0.35, -1.05), (0.35, -1.05), (0.67, -0.65),
                     (0.81, 0.43), (0.56, 0.91), (-0.56, 0.91), (-0.81, 0.43)]
    plate("Ray-shaped air cushion skirt", hover_outline, .17, .31, frame, .023)
    shell("Streamlined relief boat", [
        (.28, .62, .879, 0, -.022), (.51, .69, .90, 0, -.012),
        (.67, .43, .753, 0, .049), (.78, .237, .52, 0, .122),
    ], armor, .025)
    lens("Swept canopy", (0, -.166, .708), (.295, .442, .203), frame)
    light_at("Forward navigation strip", 0, -.83, .508, .20, .032, light)
    for side in (-1, 1):
        x = side * .65
        shaft("Thrust pod", (x, .035, .442), (x, .89, .462), .147, armor, .117)
        shaft("Rear thrust outlet", (x, .85, .46), (x, .911, .46), .092, light)
        hoop("Cushion stabilizer", (side * .535, -.048, .248), .191, .025, light)
        fin = slab("Tail control rudder", (side * .535, .611, .665), (.049, .239, .226), steel, tilt=side * .158)
        fin.rotation_euler.y = side * .13


def tank(frame, steel):
    armor = material("Olive reactive plating", (0.121, 0.174, 0.09), 0.56, 0.50)
    light = material("Sage pilot light", (.63, .75, .40), emission=1.08)
    tread_pair(.665, .231, .625, .176, .279, frame, steel)
    shell("Armored tank glacis", [
        (.235, .58, .708, 0, -.025), (.49, .714, .848, 0, -.004),
        (.692, .56, .76, 0, .075),
    ], armor, .028)
    for side in (-1, 1):
        slab("Armored track fairing", (side * .661, .002, .489), (.175, .812, .104), armor)
        light_at("Tank lamps", side * .392, -.82, .493, .098, .049, light)
    shaft("Turret collar", (0, .102, .64), (0, .102, .78), .398, steel)
    shell("Chamfered turret", [
        (.736, .33, .401, 0, .087), (.849, .453, .469, 0, .102),
        (1.029, .386, .40, 0, .142), (1.113, .285, .337, 0, .174),
    ], armor, .032)
    shaft("Armored barrel", (0, -.207, .918), (0, -1.19, .938), .091, steel)
    shaft("Sleeve", (0, -.959, .933), (0, -1.245, .941), .121, frame)
    slab("Optics housing", (.286, -.134, 1.088), (.069, .13, .065), steel)
    light_at("Optic marker", .286, -.257, 1.101, .046, .023, light)
    for i in range(4):
        slab("Rear louvres", (0, .487 + i * .078, .682), (.305, .021, .022), frame, .008)


def mech(frame, steel):
    armor = material("Walker amethyst grey", (.165, .122, .194), .48, .47)
    light = material("Industrial walker lamps", (.72, .51, .88), emission=1.3)
    shell("Suspended walker cabin", [
        (.77, .297, .28, 0, .073), (1.091, .475, .379, 0, .08),
        (1.381, .429, .35, 0, .108), (1.544, .261, .264, 0, .13),
    ], armor, .027)
    slab("Operator canopy panel", (0, -.278, 1.188), (.294, .075, .177), frame)
    light_at("Walker viewstrip", 0, -.365, 1.226, .158, .035, light)
    for side in (-1, 1):
        hip = (side * .43, .05, .901)
        knee = (side * .54, -.18, .502)
        ankle = (side * .599, .121, .165)
        lens("Hip actuator bearing", hip, (.174, .187, .168), steel)
        shaft("Walker upper leg", hip, knee, .118, armor)
        shaft("Walker lower actuator", knee, ankle, .109, steel, .085)
        slab("Walker foot", (side * .59, -.046, .097), (.187, .267, .079), frame)
        lens("Protected knee", knee, (.137, .13, .129), armor, True)
        shaft("Tool shoulder", (side * .46, .028, 1.206), (side * .692, -.055, .943), .105, steel)
        slab("Outboard tool pack", (side * .698, -.149, .855), (.128, .228, .132), armor)
        light_at("Outboard work light", side * .698, -.38, .859, .069, .04, light)


def supply_case(frame, steel):
    tile = material("Reinforced field container", (.055, .124, .119), .49, .48)
    brass = material("Weathered brass edge guards", (.39, .222, .067), .66, .46)
    light = material("Case charge panels", (.93, .49, .083), emission=1.32)
    shell("Shockproof case lower body", [
        (.035, .294, .257, 0, 0), (.099, .458, .399, 0, 0),
        (.51, .421, .371, 0, 0), (.578, .399, .365, 0, 0),
    ], tile, .027)
    shell("Recessed lid surround", [
        (.516, .468, .4, 0, 0), (.651, .456, .383, 0, 0),
        (.744, .366, .305, 0, .011),
    ], frame, .021)
    for side in (-1, 1):
        for end in (-1, 1):
            corner = slab("Replaceable corner armour", (side * .388, end * .335, .407),
                          (.119, .094, .277), brass, .019, side * end * .27)
            corner.rotation_euler.x = end * .08
            lens("Lid fastener", (side * .293, end * .251, .729), (.03, .03, .018), steel)
        slab("Lid hinge", (side * .218, .39, .494), (.083, .055, .056), steel)
        slab("Recessed roof warning latch", (side * .155, -.071, .746), (.036, .114, .011), light, .005)
    slab("Recessed mechanical lock", (0, -.381, .413), (.105, .087, .111), steel)
    light_at("Latch indicator", 0, -.468, .443, .056, .019, light)


def generate(reset, save):
    graphite = material("Dark structural graphite", (.023, .033, .039), .63, .45)
    steel = material("Brushed blue grey steel", (.181, .22, .233), .79, .38)
    for name, make in [
        ("hero", slime), ("cyborg", cyborg), ("inferno", inferno),
        ("ghost", ghost), ("titan", titan), ("cryo", cryo),
        ("enemy", scout), ("enemy_fast", interceptor), ("enemy_armored", armored),
        ("boss_overlord", overlord), ("boss_crystal", crystal_boss), ("boss_inferno", furnace_boss),
        ("buggy", buggy), ("hovercraft", hovercraft), ("tank", tank), ("mech", mech),
        ("crate", supply_case),
    ]:
        reset()
        make(graphite, steel)
        save(name)
