extends RefCounted

const PLAY_HALF := 48.0
const SPAWN_HALF := 51.0
const MAP_HALF := 54.0
const FLOOR_HALF := 83.0
const GRID := 112
const STARTING_CRATES := 54

static func xz(point: Vector3) -> Vector2:
	return Vector2(point.x,point.z)

static func keep_inside(point: Vector3, limit: float) -> Vector3:
	point.x = clampf(point.x,-limit,limit)
	point.z = clampf(point.z,-limit,limit)
	return point

static func trail(z: float) -> float:
	return sin(z*0.107)*5.4-z*0.20

# Keep the interior formula in sync with terrain_ring.gdshader so rings sit on the mesh.
static func height(biome: int,x: float,z: float) -> float:
	var softly := sin(x*0.14+z*0.066)*sin(z*0.15-x*0.047)
	var ridges := sin(z*0.081+x*0.13)*cos(x*0.057-z*0.08)
	var outskirts := smoothstep(PLAY_HALF+3.0,FLOOR_HALF-10.0,maxf(absf(x),absf(z)))
	var feature := 0.0
	match biome:
		0:
			var bank := smoothstep(2.4,11.0,absf(x-trail(z)))
			feature = (softly*0.51+ridges*0.24)*lerpf(0.40,1.0,bank)
		1:
			var roadside := smoothstep(2.2,8.5,absf(x+z*0.18))
			feature = softly*0.56*roadside + ridges*0.14
		2:
			feature = softly*0.68+ridges*0.86
		3:
			feature = softly*0.63+ridges*0.37
		4:
			feature = softly*0.81+ridges*0.42
	return feature+outskirts*(4.3+2.0*ridges)

static func positioned(biome: int,pos: Vector3,offset: float) -> Vector3:
	pos.y = height(biome,pos.x,pos.z)+offset
	return pos

static func surface(biome: int) -> ArrayMesh:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(GRID+1):
		for column in range(GRID+1):
			var x := lerpf(-FLOOR_HALF,FLOOR_HALF,float(column)/GRID)
			var z := lerpf(-FLOOR_HALF,FLOOR_HALF,float(row)/GRID)
			mesh.add_vertex(Vector3(x,height(biome,x,z),z))
	for row in GRID:
		for column in GRID:
			var a := row*(GRID+1)+column
			var b := a+GRID+1
			for index in [a,a+1,b,a+1,b+1,b]:
				mesh.add_index(index)
	mesh.generate_normals()
	return mesh.commit()

static func rock_profile(family: int) -> Mesh:
	if family == 1:
		var facade := BoxMesh.new()
		facade.size = Vector3(1.0,1.0,1.0)
		return facade
	var rock := SurfaceTool.new()
	rock.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := [
		Vector3(0.0,1.03,1.0),Vector3(0.25,0.94,0.90),Vector3(0.67,0.78,0.73),
		Vector3(1.05,0.45,0.49),Vector3(1.16,0.22,0.25)]
	if family == 3:
		rings = [Vector3(0.0,0.89,1.0),Vector3(0.38,0.84,0.85),Vector3(1.05,0.46,0.59),Vector3(1.27,0.05,0.14)]
	if family == 4:
		rings = [Vector3(0.0,0.82,0.80),Vector3(0.18,0.86,0.85),Vector3(0.91,0.82,0.83),Vector3(1.01,0.70,0.73)]
	var sides := 6 if family == 4 else 10
	for ring in rings.size():
		var section: Vector3 = rings[ring]
		for i in sides:
			var angle := float(i)/sides*TAU
			var erosion := sin(angle*3.0+ring*0.7)*0.11+cos(angle*7.0)*0.10
			var shelf := section.x*(1.0+sin(angle*5.0+float(ring))*0.14)
			rock.add_vertex(Vector3(cos(angle)*(section.y+erosion)+section.x*0.14,shelf,sin(angle)*(section.z+erosion)))
	for ring in range(rings.size()-1):
		for i in sides:
			var a := ring*sides+i
			var b := ring*sides+(i+1)%sides
			for k in [a,b,a+sides,b,b+sides,a+sides]:
				rock.add_index(k)
	var top := (rings.size()-1)*sides
	for i in range(1,sides-1):
		for k in [top,top+i,top+i+1]:
			rock.add_index(k)
	rock.generate_normals()
	return rock.commit()

static func atmosphere_geometry(biome: int, texture: Texture2D, tint: Color) -> MultiMeshInstance3D:
	var group := MultiMeshInstance3D.new()
	var shader := ShaderMaterial.new()
	shader.shader = preload("res://shaders/forest_stone.gdshader")
	shader.set_shader_parameter("stone_surface",texture)
	shader.set_shader_parameter("tint",tint)
	group.material_override = shader
	var batch := MultiMesh.new()
	batch.mesh = rock_profile(biome)
	batch.transform_format = MultiMesh.TRANSFORM_3D
	var transforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 4741+biome*797
	for side in 4:
		var heading := float(side)*PI*0.5
		for i in 15:
			var edge := Vector2(-58.0+8.3*i+rng.randf_range(-1.6,1.6),rng.randf_range(54.0,64.0)).rotated(heading)
			var size := Vector3(rng.randf_range(2.2,4.8),rng.randf_range(1.8,5.4),rng.randf_range(1.6,4.5))
			var place := positioned(biome,Vector3(edge.x,0,edge.y),size.y*0.32 if biome == 1 else -0.35)
			var facing := Basis(Vector3.UP,heading+rng.randf_range(-0.36,0.36))
			transforms.append(Transform3D(facing*Basis.from_scale(size),place))
			if biome == 1 and i % 3 != 0:
				var window_frame := place+Vector3(0,size.y*0.37,0)
				var reinforced := size*Vector3(0.72,0.44,0.76)
				transforms.append(Transform3D(facing*Basis.from_scale(reinforced),window_frame))
	# Lower formations break up the interiors while the paths remain readable.
	if biome >= 2:
		for i in 24:
			var p := Vector2(rng.randf_range(-46.0,46.0),rng.randf_range(-46.0,46.0))
			if p.length_squared() < 200.0:
				p.x += 9.0 if p.x >= 0.0 else -9.0
			var feature_size := Vector3(rng.randf_range(1.15,2.9),rng.randf_range(0.38,1.75),rng.randf_range(1.2,2.5))
			transforms.append(Transform3D(Basis(Vector3.UP,rng.randf_range(-PI,PI))*Basis.from_scale(feature_size),
				positioned(biome,Vector3(p.x,0,p.y),-0.25)))
	batch.instance_count = transforms.size()
	for i in transforms.size():
		batch.set_instance_transform(i,transforms[i])
	group.multimesh = batch
	return group
