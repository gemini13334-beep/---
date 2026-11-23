extends RefCounted

# Bind-space cells are shared by every instance of the same uniform or armour.
# Each cell's posed bounds enclose all weighted vertices, including bent joints.
var vertices: PackedVector3Array
var bones: PackedInt32Array
var weights: PackedFloat32Array
var cells: Array = []

func _init(mesh: ArrayMesh) -> void:
 var arrays := mesh.surface_get_arrays(0)
 vertices = arrays[Mesh.ARRAY_VERTEX]
 bones = arrays[Mesh.ARRAY_BONES]
 weights = arrays[Mesh.ARRAY_WEIGHTS]
 var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
 var grid := {}
 for offset in range(0, indices.size(), 3):
  var a := indices[offset]
  var b := indices[offset + 1]
  var c := indices[offset + 2]
  var cell := Vector3i(((vertices[a] + vertices[b] + vertices[c]) / 0.60).floor())
  if not grid.has(cell):
   grid[cell] = {"faces": [], "bounds": {}}
  var bucket: Dictionary = grid[cell]
  bucket.faces.append_array([a, b, c])
  for index: int in [a, b, c]:
   for k in 4:
    var slot := index * 4 + k
    if weights[slot] <= 0.0: continue
    var bone := bones[slot]
    var bounds: AABB = bucket.bounds.get(bone, AABB(vertices[index], Vector3.ZERO))
    bucket.bounds[bone] = bounds.expand(vertices[index])
 cells = grid.values()

func _vertex(index: int, pose: Array[Transform3D], cache: Dictionary) -> Vector3:
 if cache.has(index): return cache[index]
 var point := Vector3.ZERO
 for k in 4:
  var slot := index * 4 + k
  if weights[slot] > 0.0:
   point += (pose[bones[slot]] * vertices[index]) * weights[slot]
 cache[index] = point
 return point

func intersect(start: Vector3, finish: Vector3, pose: Array[Transform3D]) -> Variant:
 var nearest = null
 var cache := {}
 for cell: Dictionary in cells:
  var box := AABB()
  var first := true
  for bone: int in cell.bounds:
   var bounds: AABB = pose[bone] * cell.bounds[bone]
   box = bounds if first else box.merge(bounds)
   first = false
  if box.grow(0.0001).intersects_segment(start, finish) == null: continue
  var faces: Array = cell.faces
  for i in range(0, faces.size(), 3):
   var point = Geometry3D.segment_intersects_triangle(start, finish,
    _vertex(faces[i], pose, cache), _vertex(faces[i+1], pose, cache), _vertex(faces[i+2], pose, cache))
   if point != null:
    nearest = point
    finish = point
 return nearest
