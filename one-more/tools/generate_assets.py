import bpy, math, os, sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
import combat_models
import human_models
out=os.path.abspath(os.path.join(os.path.dirname(__file__),"../assets/models"))
os.makedirs(out,exist_ok=True)
def mat(name,c,metal=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True
 p=m.node_tree.nodes.get("Principled BSDF");p.inputs["Base Color"].default_value=(*c,1);p.inputs["Metallic"].default_value=metal;p.inputs["Roughness"].default_value=max(.24,.76-metal*.8)
 return m
def glow(name,c):
 m=mat(name,c,.15)
 p=m.node_tree.nodes.get("Principled BSDF")
 p.inputs["Emission Color"].default_value=(*c,1)
 p.inputs["Emission Strength"].default_value=1.8
 return m
def reset():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def part(name,loc,scale,m,kind='sphere'):
 if kind=='sphere': bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=loc)
 elif kind=='facet': bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,location=loc)
 elif kind=='crystal': bpy.ops.mesh.primitive_cone_add(vertices=5,radius1=1.0,radius2=.43,depth=2.0,location=loc)
 elif kind=='trunk': bpy.ops.mesh.primitive_cone_add(vertices=9,radius1=1.0,radius2=.56,depth=2.0,location=loc)
 else: bpy.ops.mesh.primitive_cube_add(size=2,location=loc)
 o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(m)
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if kind=='cube':
  mod=o.modifiers.new("Rounded armor","BEVEL");mod.width=.045;mod.segments=3
  normal=o.modifiers.new("Weighted armor normals","WEIGHTED_NORMAL");normal.keep_sharp=True
 elif kind=='sphere':
  for face in o.data.polygons: face.use_smooth=True
 return o

def weathered_stone(name, location, scale, stone, cover):
 obj = part(name, location, scale, stone, 'facet')
 obj.data.materials.append(cover)
 for vertex in obj.data.vertices:
  x, y, z = vertex.co
  variation = 1.0 + .20 * math.sin(23*x + 14*y + 17*z + location[0]*9)
  vertex.co.x = (x + .16*z) * variation
  vertex.co.y = (y - .09*x) * variation
  vertex.co.z = max(-scale[2]*.68, z * variation)
 for face in obj.data.polygons:
  center = sum((obj.data.vertices[index].co for index in face.vertices), Vector((0,0,0))) / len(face.vertices)
  if center.z + .16*math.sin(21*center.x + 15*center.y) > scale[2]*.35:
   face.material_index = 1
 return obj

def pine_branches(shade, tips, inner):
 vertices = []
 faces = []
 colors = []

 def triangle(a, b, c, color):
  first = len(vertices)
  vertices.extend((a,b,c))
  faces.append((first,first+1,first+2))
  colors.append(color)

 up = Vector((0,0,1))
 for tier in range(8):
  height = .66 + tier*.214
  radius = .87 - tier*.103
  branches = 8 if tier < 4 else 6
  for index in range(branches):
   angle = index*math.tau/branches + tier*1.09 + .14*math.sin(index+tier)
   outward = Vector((math.cos(angle),math.sin(angle),0))
   side_vector = Vector((-outward.y,outward.x,0))
   length = radius*(.82 + .24*math.sin(index*2.49+tier*1.2)**2)
   root = up*(height + .05*math.cos(index*2.7))
   end = root + outward*length + up*(-.13+.032*tier)
   for needle in range(8):
    along = (needle+1)/9
    origin = root.lerp(end,along*.88)
    width = length*(.31*(1-along) + .078)
    for side in [-1,1]:
     tip = origin + outward*(length*.29*(1-along)+.024) + side_vector*width*side
     tip += up*(.047+math.sin(needle*7.2+index)*.027)
     vein = origin.lerp(tip,.53) + up*.062
     shoulder = origin + outward*(length*.115) - up*.023
     accent = 1 if (needle+index+tier) % 5 == 0 else 0
     triangle(origin,tip,vein,accent)
     triangle(vein,tip,shoulder,accent)
     triangle(origin,vein,shoulder,2)
     triangle(shoulder,tip,origin,2)
 mesh = bpy.data.meshes.new("Fir needle sprays")
 mesh.from_pydata(vertices, [], faces)
 mesh.update()
 for material in (shade,tips,inner):
  mesh.materials.append(material)
 for face,color in zip(mesh.polygons,colors):
  face.material_index = color
 branches = bpy.data.objects.new("Irregular fir branchlets",mesh)
 bpy.context.collection.objects.link(branches)

def save(name):
 bpy.context.view_layer.update()
 bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out,name+".blend"))
 # Keep one baked mesh per joint, sharing surfaces by material within the joint.
 sources=[obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
 markers=[obj for obj in bpy.context.scene.objects if obj.type == 'EMPTY']
 groups={}
 for obj in sources:
  groups.setdefault(obj.parent,[]).append(obj)
 baked=[]
 meshes=[]
 try:
  for joint,parts in groups.items():
   bpy.ops.object.select_all(action='DESELECT')
   depsgraph=bpy.context.evaluated_depsgraph_get()
   inverse=joint.matrix_world.inverted() if joint is not None else None
   for source in parts:
    mesh=bpy.data.meshes.new_from_object(source.evaluated_get(depsgraph),depsgraph=depsgraph)
    transform=source.matrix_world if inverse is None else inverse @ source.matrix_world
    mesh.transform(transform)
    meshes.append(mesh)
    obj=bpy.data.objects.new(source.name+" export",mesh)
    bpy.context.collection.objects.link(obj)
    obj.select_set(True)
   label=name if joint is None else joint.name+" mesh"
   combined_mesh=bpy.data.meshes.new(label)
   meshes.append(combined_mesh)
   combined=bpy.data.objects.new(label,combined_mesh)
   bpy.context.collection.objects.link(combined)
   baked.append(combined)
   combined.select_set(True)
   bpy.context.view_layer.objects.active=combined
   bpy.ops.object.join()
   combined.parent=joint
  bpy.ops.object.select_all(action='DESELECT')
  for obj in baked+markers:
   obj.select_set(True)
  result=bpy.ops.export_scene.gltf(
   filepath=os.path.join(out,name+".glb"),export_format='GLB',use_selection=True
  )
  if 'FINISHED' not in result:
   raise RuntimeError(f"GLB export failed for {name}")
 finally:
  for obj in baked:
   bpy.data.objects.remove(obj,do_unlink=True)
  for mesh in meshes:
   if mesh.users == 0:
    bpy.data.meshes.remove(mesh)

def generate():
 dark=mat("Graphite",(.025,.045,.065),.5)
 combat_models.generate(reset, save)
 human_models.generate(reset,out)
 for name,c in [("forest",(.18,.48,.22)),("city",(.35,.4,.48)),("desert",(.72,.45,.18)),("ice",(.3,.72,.88)),("volcano",(.35,.09,.05))]:
  reset()
  surface=mat(name+" surface",c)
  if name == "forest":
   slate=mat("Wet slate",(.055,.076,.085),.16)
   moss=mat("Slate moss",(.085,.145,.065))
   growth=glow("Forest spores",(.16,.75,.38))
   for x,y,height in [(-.64,.33,.37),(.15,.17,.65),(.69,-.37,.43)]:
    rock=weathered_stone("Slate outcrop",(x,y,height*.52),(.52,.45,height),slate,moss)
    rock.rotation_euler.z=x*1.3
    for i in range(2):
     part("Glow lichen",(x+i*.086-.07,y-.34,height*.53+i*.031),(.028,.021,.045),growth,'facet')
  elif name == "city":
   aggregate=mat("Weathered concrete aggregate",(.22,.23,.225))
   rebar=mat("Oxidized reinforcement",(.17,.081,.042),.55)
   for i, (x,y,height) in enumerate([(-.52,.1,1.28),(.06,.3,.76),(.59,.18,.98)]):
    slab=combat_models.shell("Fractured concrete pier",[
     (0,.22,.25,x,y),(.30,.237,.21,x-.05,y),(height*.76,.18,.20,x+.044,y),
     (height,.13,.15,x-.032,y+.04),
    ], surface if i%2 else aggregate)
    for j in range(2):
     bx=x+(j-.5)*.16
     combat_models.shaft("Bent exposed rebar",(bx,y,height*.86),(bx+.06,y-.14,height+.17-j*.13),.019,rebar,sides=8)
    weathered_stone("Fallen concrete chips",(x-.1,y-.52,.1),(.21,.29,.15),aggregate,surface)
  elif name == "desert":
   seam=mat("Wind-carved sandstone laminae",(.43,.24,.112))
   for i, (x,y,height) in enumerate([(-.63,.26,.48),(.05,-.16,.77),(.67,.28,.54)]):
    formation=combat_models.shell("Sandstone bedrock",[
     (0,.43,.36,x,y),(.13,.45,.34,x+.033,y),(height*.68,.32,.28,x+.10,y-.065),
     (height,.23,.21,x+.09,y+.032),
    ], surface, .033)
    for fraction in (.27,.49,.70):
     z=height*fraction
     seam_band=combat_models.slab("Sediment edge",(x+.05,y-(.347-fraction*.099),z),
                                  (.35-fraction*.12,.043,.014),seam,.008)
     seam_band.rotation_euler.y=(i-1)*.14
  elif name == "ice":
   blue=mat("Compressed glacial ice",(.08,.26,.40),.18)
   frost=mat("Snow crust",(.52,.72,.83))
   for x,y,height,width in [(-.67,.24,.59,.30),(-.14,-.18,1.15,.34),(.58,.14,.89,.38)]:
    weathered_stone("Rough glacial footing",(x,y,.196),(.48,.44,.35),blue,frost)
    combat_models.crystal("Exposed blue crevasse ice",(x,y,.18),(x+.16,y-.08,height),width,surface)
    combat_models.crystal("Frost rind",(x-.17,y-.15,.18),(x-.22,y-.09,height*.79),width*.48,frost)
  elif name == "volcano":
   basalt=mat("Columnar basalt",(.047,.039,.040),.22)
   clinker=mat("Oxidized volcanic clinker",(.14,.063,.032))
   ember=glow("Hot bedrock seams",(.87,.13,.023))
   for x,y,height in [(-.67,.18,.51),(-.27,-.19,1.05),(.24,.18,.73),(.67,.09,.49)]:
    combat_models.shell("Broken basalt column",[
     (0,.28,.26,x,y),(.12,.30,.27,x,y),(height*.64,.235,.221,x+.055,y-.03),
     (height,.187,.17,x+.036,y+.019),
    ], basalt,.014,combat_models.CHAMFER)
    weathered_stone("Lava-crusted rubble",(x+.1,y-.39,.17),(.28,.25,.20),clinker,surface)
    combat_models.shaft("Small heated fracture",(x+.02,y-.18,.1),(x+.13,y-.25,height*.62),.027,ember,.011,7)
  save(name)
 for name,c in [("tree",(.15,.55,.24)),("rock",(.42,.43,.48)),("ruin",(.5,.47,.4)),("cactus",(.2,.58,.25)),("ice_spire",(.2,.8,.95)),("lava_vent",(.9,.22,.04))]:
  reset()
  shell=mat(name,c)
  if name=="tree":
   bark=mat("Fir bark",(.104,.061,.032))
   shaded=mat("Evergreen needles",(.026,.087,.042))
   tips=mat("Sunlit fir tips",(.064,.155,.063))
   inner=mat("Deep evergreen",(.012,.042,.021))
   part("Tapered fir trunk",(0,0,1.14),(.082,.084,1.14),bark,'trunk')
   pine_branches(shaded,tips,inner)
  elif name=="rock":
   cover=mat("Basalt lichen",(.13,.17,.10))
   weathered_stone("Fractured boulder",(0,0,.41),(.75,.53,.52),shell,cover)
   weathered_stone("Boulder fragment",(.43,-.31,.15),(.34,.28,.24),shell,cover)
  elif name=="cactus":
   ribs=mat("Drought-worn succulent ribs",(.088,.205,.071))
   thorn=mat("Dried cactus spines",(.33,.235,.117))
   for x,y,height,radius in [(-.31,.16,.84,.14),(.035,-.10,1.36,.204),(.39,.14,1.04,.157)]:
    stem_profile=[(math.cos(i*math.tau/20)*(1 if i%2 else .82),
                   math.sin(i*math.tau/20)*(1 if i%2 else .82)) for i in range(20)]
    combat_models.shell("Ribbed saguaro branch",[
     (0,radius*.82,radius*.79,x,y),(.23,radius,radius,x,y),
     (height*.77,radius*.89,radius*.84,x+.058,y-.024),
     (height,radius*.36,radius*.35,x+.071,y-.041),
    ],ribs,.011,stem_profile)
    for i in range(7):
     angle=i*math.tau/7
     z=height*(.38+.041*i)
     base=(x+(radius-.007)*math.cos(angle),y+(radius-.007)*math.sin(angle),z)
     tip=(x+(radius+.06)*math.cos(angle),y+(radius+.06)*math.sin(angle),z+.026)
     combat_models.shaft("Saguaro spine",base,tip,.009,thorn,.001,5)
  elif name=="lava_vent":
   clinker=mat("Rough lava crust",(.073,.047,.036))
   ember=glow("Molten fracture",(.93,.139,.023))
   combat_models.lens("Viscous vent surface",(0,0,.061),(.48,.43,.071),ember)
   for i in range(9):
    angle=i*math.tau/9
    x,y = math.cos(angle)*.44,math.sin(angle)*.44
    height=.28+.13*math.sin(i*2.1)**2
    bank=weathered_stone("Solidified crater shoulder",(x,y,.123),(.26,.22,height),clinker,dark)
    bank.rotation_euler.z=angle+.14
  elif name=="ice_spire":
   frost=mat("Mineral frost",(.45,.66,.76),.18)
   footing=mat("Blue glacier dirt",(.072,.17,.24))
   weathered_stone("Cracked moraine footing",(0,0,.117),(.62,.49,.21),footing,frost)
   for i, (x,y,height,width) in enumerate([(-.31,.13,.86,.18),(.02,-.07,1.55,.26),(.36,.16,1.03,.24),(.16,-.33,.67,.18)]):
    combat_models.crystal("Wind-fractured ice blade",(x,y,.12),(x*1.36+.11,y-.09,height),width,frost if i%2 else shell)
  elif name=="ruin":
   mortar=mat("Aged masonry",(.26,.24,.19))
   cover=mat("Wall moss",(.09,.14,.07))
   part("Sunken wall foot",(0,.02,.10),(.91,.30,.12),mortar,'cube')
   for side,tiers in [(-1,5),(1,3)]:
    for tier in range(tiers):
     x=side*(.63+.035*math.cos(tier*2.1))
     block=part("Hewn wall course",(x,.035*math.sin(tier),.26+tier*.26),
                (.22+.03*math.cos(tier),.25,.124),shell if tier%2 else mortar,'cube')
     block.rotation_euler.z=.10*math.sin(tier*1.9+side)
   for index,angle in enumerate([2.15,1.76,1.39]):
    span=part("Fallen arch segment",(.61*math.cos(angle),0,1.08+.61*math.sin(angle)),
              (.22,.24,.107),mortar if index%2 else shell,'cube')
    span.rotation_euler.y=-angle
   for x,y,size in [(-.96,-.23,.25),(-.10,-.34,.33),(.25,-.3,.26),(.99,.18,.23),(.82,.42,.19)]:
    fragment=weathered_stone("Weathered rubble",(x,y,size*.52),(size,size*.75,size*.70),mortar,cover)
    fragment.rotation_euler.z=x*3.4
  save(name)

def render_previews():
 preview=os.path.join(out,"previews")
 os.makedirs(preview,exist_ok=True)
 for name in ("hero cyborg inferno ghost titan cryo vega fox amber north enemy enemy_fast enemy_armored boss_overlord boss_crystal boss_inferno buggy hovercraft tank mech crate forest city desert ice volcano tree rock ruin cactus ice_spire lava_vent").split():
  bpy.ops.wm.open_mainfile(filepath=os.path.join(out,name+".blend"))
  scene=bpy.context.scene
  corners=[obj.matrix_world @ Vector(corner) for obj in scene.objects
           if obj.type == 'MESH' for corner in obj.bound_box]
  low=Vector(tuple(min(p[i] for p in corners) for i in range(3)))
  high=Vector(tuple(max(p[i] for p in corners) for i in range(3)))
  center=(low+high)/2
  span=max(high-low)
  bpy.ops.mesh.primitive_plane_add(size=span*150,location=(center.x,center.y,low.z-.015))
  bpy.context.object.data.materials.append(mat("Matte studio ground",(.083,.102,.112)))
  bpy.ops.object.camera_add(location=center+Vector((.48,-.79,.53))*span*3.2)
  cam=bpy.context.object
  cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
  cam.data.type='ORTHO'
  cam.data.ortho_scale=span*1.50
  scene.camera=cam
  for offset,energy,color in [
   ((1.3,-2.2,2.7),230,(1.,.85,.65)),
   ((-2.,1.4,2.),270,(.55,.76,1.)),
   ((-.7,-2.,.8),95,(.82,.91,1.)),
  ]:
   bpy.ops.object.light_add(type='AREA',location=center+Vector(offset)*span)
   lamp=bpy.context.object
   lamp.data.energy=energy*span*span
   lamp.data.color=color
   lamp.data.shape='DISK'
   lamp.data.size=span*1.8
   lamp.rotation_euler=(center-lamp.location).to_track_quat('-Z','Y').to_euler()
  scene.render.engine='CYCLES'
  scene.cycles.samples=20
  scene.cycles.use_denoising=False
  scene.render.resolution_x=420
  scene.render.resolution_y=420
  scene.render.resolution_percentage=100
  scene.render.image_settings.file_format='PNG'
  scene.render.filepath=os.path.join(preview,name+".png")
  bpy.ops.render.render(write_still=True)


def render_portraits():
 portrait_folder=os.path.abspath(os.path.join(out,"../portraits"))
 os.makedirs(portrait_folder,exist_ok=True)
 for name in ("hero","cyborg","inferno","ghost","titan","cryo",*human_models.OPERATORS):
  bpy.ops.wm.open_mainfile(filepath=os.path.join(out,name+".blend"))
  scene=bpy.context.scene
  corners=[obj.matrix_world @ Vector(corner) for obj in scene.objects if obj.type == 'MESH' for corner in obj.bound_box]
  high=max(point.z for point in corners)
  low=min(point.z for point in corners)
  span=high-low
  human=name in human_models.OPERATORS
  center=Vector((0,0,high-span*(.107 if human else .25)))
  bpy.ops.object.camera_add(location=center+Vector((.32,-1,.13))*span*2)
  cam=bpy.context.object
  cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
  cam.data.type="ORTHO"
  cam.data.ortho_scale=span*(.29 if human else .73)
  scene.camera=cam
  for offset,energy,color in [
   ((-.6,-1.5,1.1),193,(1.,.86,.70)),
   ((1.5,-.7,.3),104,(.62,.79,1.)),
   ((.5,.9,.9),180,(1.,.55,.25)),
  ]:
   bpy.ops.object.light_add(type='AREA',location=center+Vector(offset)*span)
   lamp=bpy.context.object
   lamp.data.energy=energy*span*span
   lamp.data.color=color
   lamp.data.size=span*.8
   lamp.rotation_euler=(center-lamp.location).to_track_quat('-Z','Y').to_euler()
  scene.render.engine="CYCLES"
  scene.cycles.samples=64 if human else 32
  scene.cycles.use_denoising=False
  scene.render.film_transparent=True
  scene.view_settings.exposure=-1.45
  scene.render.resolution_x=192 if human else 128
  scene.render.resolution_y=scene.render.resolution_x
  scene.render.resolution_percentage=100
  scene.render.image_settings.file_format="PNG"
  scene.render.image_settings.color_mode="RGBA"
  scene.render.filepath=os.path.join(portrait_folder,name+".png")
  bpy.ops.render.render(write_still=True)


if "--preview" in sys.argv:
 render_previews()
elif "--portraits" in sys.argv:
 render_portraits()
else:
 generate()
