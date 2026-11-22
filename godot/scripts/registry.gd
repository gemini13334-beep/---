extends Node3D

const FILE_COUNT := 3
const DESKS := [Vector3(-4.8,0,3.4), Vector3(4.8,0,-1.8), Vector3(-4.8,0,-7.6)]
const SPAWN_X := [-7.4,0.0,7.4]
var files:Array[Node3D]=[]
var materials:Dictionary={}

func material(tint:Color, texture_path:="", tile:=0.0, unshaded:=false)->StandardMaterial3D:
 var key:=[tint,texture_path,tile,unshaded]
 if materials.has(key): return materials[key]
 var mat:=StandardMaterial3D.new()
 mat.albedo_color=tint
 mat.roughness=0.86
 if texture_path!="":
  mat.albedo_texture=load(texture_path)
  mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
 if tile>0:
  mat.uv1_triplanar=true
  mat.uv1_world_triplanar=true
  mat.uv1_scale=Vector3.ONE*tile
 if unshaded: mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 materials[key]=mat
 return mat

func box(parent:Node3D, pos:Vector3, dims:Vector3, mat:Material, solid:=false)->MeshInstance3D:
 var part:=MeshInstance3D.new()
 var mesh:=BoxMesh.new()
 mesh.size=dims
 part.mesh=mesh
 part.material_override=mat
 part.position=pos
 parent.add_child(part)
 if solid:
  var body:=StaticBody3D.new()
  var shape:=CollisionShape3D.new()
  var block:=BoxShape3D.new()
  block.size=dims
  shape.shape=block
  body.add_child(shape)
  part.add_child(body)
 return part

func lettering(value:String, pos:Vector3, scale_factor:float, tint:Color)->Label3D:
 var label:=Label3D.new()
 label.text=value
 label.font=preload("res://assets/type/OpenSans-CondBold.ttf")
 label.font_size=64
 label.pixel_size=scale_factor
 label.modulate=tint
 label.outline_size=0
 label.position=pos
 add_child(label)
 return label

func build()->void:
 var plaster:=material(Color("#e3dbc5"),"res://assets/registry/office-3.webp",0.33)
 var teal:=material(Color("#56817c"),"res://assets/registry/office-3.webp",0.33)
 var walnut:=material(Color("#9e7c5c"),"res://assets/courtyard/surface-2.webp",0.55)
 var metal:=material(Color("#455458"))
 var trim:=material(Color("#9a8a72"))
 var ceiling:=material(Color("#c6c6b9"))
 var glass:=material(Color("#d8e4dc"),"",0.0,true)
 var light:=material(Color("#fff0bd"),"",0.0,true)
 box(self,Vector3(0,-0.14,0),Vector3(22,0.28,31),material(Color("#d8dfd9"),"res://assets/registry/office-2.webp",0.24),true)
 box(self,Vector3(0,5.08,0),Vector3(22,0.16,31),ceiling)
 for side in [-1,1]:
  # Masonry around the openings casts stripes of late sunlight onto the hall.
  box(self,Vector3(side*11.0,0.85,0),Vector3(0.35,1.7,31),plaster,true)
  box(self,Vector3(side*11.0,4.64,0),Vector3(0.35,0.72,31),plaster)
  for gap in [-13.78,-6.5,0.5,7.5,14.28]:
   var span:=2.96
   if gap==-13.78: span=3.45
   if gap==14.28: span=2.45
   box(self,Vector3(side*11.0,2.98,gap),Vector3(0.35,2.6,span),plaster)
  box(self,Vector3(side*10.77,0.65,0),Vector3(0.11,1.3,31),teal)
  box(self,Vector3(0,2.5,side*15.4),Vector3(22,5,0.35),plaster,true)
  box(self,Vector3(0,0.65,side*15.17),Vector3(22,1.3,0.11),teal)
  box(self,Vector3(side*10.65,1.34,0),Vector3(0.16,0.09,31),trim)
  for z in [-10.0,-3.0,4.0,11.0]:
   var pane:=box(self,Vector3(side*11.3,2.97,z),Vector3(0.04,2.58,4.12),glass)
   pane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   for edge in [-1,1]:
    box(self,Vector3(side*10.65,2.97,z+edge*1.99),Vector3(0.19,2.64,0.12),walnut)
   for slat in 5:
    var blind:=box(self,Vector3(side*10.57,4.19-0.15*slat,z),Vector3(0.19,0.047,4.0),trim)
    blind.rotation.z=side*0.33
   box(self,Vector3(side*10.43,2.97,z),Vector3(0.09,2.34,0.07),metal)
   for y in [2.53,3.38]:
    box(self,Vector3(side*10.43,y,z),Vector3(0.09,0.06,3.86),metal)
   box(self,Vector3(side*10.44,1.73,z),Vector3(0.55,0.13,4.26),trim)
 for z in [-11.0,-4.0,3.0,10.0]:
  box(self,Vector3(0,4.76,z),Vector3(21.7,0.29,0.36),teal)
  for x in [-4.8,4.8]:
   box(self,Vector3(x,4.49,z),Vector3(2.2,0.19,0.52),metal)
   box(self,Vector3(x,4.37,z),Vector3(1.98,0.06,0.39),light)
 # Counters leave three unobstructed routes between the two ends of the hall.
 for desk in DESKS:
  box(self,desk+Vector3.UP*0.6,Vector3(3,1.2,1.46),teal,true)
  box(self,desk+Vector3.UP*1.25,Vector3(3.14,0.11,1.56),walnut)
  box(self,desk+Vector3(0.82,1.39,-0.24),Vector3(0.44,0.16,0.32),material(Color("#e0cfab")))
  box(self,desk+Vector3(0.82,1.48,-0.24),Vector3(0.46,0.025,0.34),metal)
  var papers:=material(Color("#e7dfc4"))
  var leather:=material(Color("#744b35"))
  box(self,desk+Vector3(0,0.67,0.744),Vector3(2.78,0.7,0.035),walnut)
  for layer in 3:
   var page:=box(self,desk+Vector3(0.39,1.318+layer*0.012,0.25),Vector3(0.31,0.008,0.40),papers)
   page.rotation.y=0.16*layer
  box(self,desk+Vector3(-1,1.33,-0.39),Vector3(0.32,0.07,0.23),metal)
  box(self,desk+Vector3(-1,1.57,-0.39),Vector3(0.044,0.48,0.044),trim)
  box(self,desk+Vector3(-1,1.82,-0.36),Vector3(0.53,0.16,0.25),metal)
  box(self,desk+Vector3(-1,1.735,-0.36),Vector3(0.45,0.015,0.2),light)
  var chair:Vector3=desk+Vector3(0.4,0,-1.48)
  box(self,chair+Vector3.UP*0.56,Vector3(0.65,0.14,0.58),leather,true)
  box(self,chair+Vector3(0,0.92,-0.27),Vector3(0.64,0.65,0.11),leather)
  for dx in [-0.25,0.25]:
   for dz in [-0.22,0.22]:
    box(self,chair+Vector3(dx,0.27,dz),Vector3(0.055,0.54,0.055),metal)
 # Slatted benches leave a clear lane between the queues and the desks.
 for side in [-1,1]:
  for row in [-6,7]:
   var bench:=Vector3(side*9.4,0,row)
   box(self,bench+Vector3.UP*0.42,Vector3(0.76,0.40,2.9),metal,true)
   for k in 4:
    box(self,bench+Vector3(-0.29+0.19*k,0.67,0),Vector3(0.16,0.09,3.05),walnut)
   for h in [0.95,1.18]:
    box(self,bench+Vector3(side*0.36,h,0),Vector3(0.08,0.16,3.05),walnut)
 for side in [-1,1]:
  for j in 5:
   var x:float=side*(3.65+j*1.33)
   box(self,Vector3(x,1.22,-14.45),Vector3(1.27,2.44,0.94),metal,true)
   box(self,Vector3(x,1.22,-13.95),Vector3(1.23,2.38,0.035),material(Color.WHITE,"res://assets/registry/office-0.webp"))
 box(self,Vector3(0,1.52,-15.04),Vector3(2.78,3.04,0.24),walnut)
 box(self,Vector3(0,1.52,-14.89),Vector3(0.04,3.02,0.04),metal)
 box(self,Vector3(0,3.85,-15.05),Vector3(6.9,0.88,0.22),teal)
 lettering("КАНЦЕЛЯРИЯ",Vector3(0,3.85,-14.92),0.008,Color("#ffebbf"))
 for x in [-7.2,7.2]:
  box(self,Vector3(x,3.6,-15.1),Vector3(3.2,1.75,0.15),walnut)
  box(self,Vector3(x,3.6,-14.99),Vector3(3.04,1.6,0.03),material(Color.WHITE,"res://assets/registry/office-1.webp"))
 var env:=Environment.new()
 env.background_mode=Environment.BG_COLOR
 env.background_color=Color("#829793")
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color=Color("#d4dedb")
 env.ambient_light_energy=0.65
 env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 var lighting:=WorldEnvironment.new()
 lighting.environment=env
 add_child(lighting)
 var sun:=DirectionalLight3D.new()
 sun.rotation_degrees=Vector3(-17,-72,0)
 sun.light_color=Color("#ffe7bb")
 sun.light_energy=1.6
 sun.shadow_enabled=true
 sun.directional_shadow_max_distance=42
 add_child(sun)
 for z in [-8,6]:
  var lamp:=OmniLight3D.new()
  lamp.position=Vector3(-6,3.9,z)
  lamp.light_color=Color("#ffdfac")
  lamp.light_energy=1.4
  lamp.omni_range=13
  add_child(lamp)

func reset_files()->void:
 for file in files: file.free()
 files.clear()
 for i in DESKS.size():
  var folder:=Node3D.new()
  folder.position=DESKS[i]+Vector3(-0.62,1.32,0.49)
  add_child(folder)
  box(folder,Vector3.ZERO,Vector3(0.59,0.08,0.41),material(Color("#ffbf52")))
  box(folder,Vector3(0.01,0.054,0),Vector3(0.51,0.03,0.35),material(Color("#fff1d2")))
  var tag:=lettering("ДЕЛО  %02d"%[i+1],folder.position+Vector3.UP*0.58,0.0036,Color("#ffda83"))
  tag.reparent(folder)
  tag.billboard=BaseMaterial3D.BILLBOARD_ENABLED
  tag.outline_size=7
  files.append(folder)

func collect_near(player:Vector3)->void:
 for i in range(files.size()-1,-1,-1):
  var pos:=files[i].position
  if Vector2(pos.x-player.x,pos.z-player.z).length()<1.4:
   files[i].queue_free()
   files.remove_at(i)
