import bpy, math, os
from mathutils import Vector
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
def hero_details(name,shell):
 accents={"hero":(.12,1,.65),"cyborg":(.15,.55,1),"inferno":(1,.22,.025),"ghost":(.72,.24,1),"titan":(1,.65,.12),"cryo":(.3,.9,1)}
 light=glow(name+" energy",accents.get(name,(.12,.85,1)))
 trim=mat(name+" brushed trim",(.24,.30,.36),.8)
 part("Reactor housing",(0,-.46,.43),(.23,.095,.23),dark)
 part("Visor brow",(0,-.43,1.02),(.36,.095,.045),trim,'cube')
 for x in [-1,1]:
  part("Side armor",(x*.48,-.22,.61),(.12,.20,.25),shell,'cube')
  part("Boot toe",(x*.25,-.28,.13),(.19,.13,.09),trim,'cube')
  part("Backpack vent",(x*.16,.61,.72),(.055,.035,.16),trim,'cube')
  part("Backpack indicator",(x*.16,.65,.72),(.028,.018,.10),light,'cube')
 if name=="titan":
  for x in [-1,1]: part("Heavy pauldron",(x*.67,.02,.85),(.28,.28,.13),trim,'cube')
 elif name=="ghost":
  for x in [-1,1]: part("Spectral stabilizer",(x*.43,.36,.95),(.08,.24,.25),light)
 elif name=="cryo":
  for x in [-1,1]: part("Coolant cylinder",(x*.24,.45,.82),(.10,.12,.30),trim)

 part("Chest reactor",(0,-.47,.43),(.16,.075,.16),light)
 part("Backpack",(0,.43,.65),(.32,.19,.35),dark,'cube')
 for x in [-1,1]:
  part("Knee armor",(x*.25,-.22,.25),(.14,.11,.14),shell,'cube')
  part("Shoulder stripe",(x*.58,-.16,.71),(.10,.10,.045),light,'cube')
 part("Weapon receiver",(.72,-.25,.42),(.16,.30,.15),dark,'cube')
 part("Weapon barrel",(.72,-.58,.42),(.07,.22,.07),shell,'cube')
 part("Muzzle",(.72,-.79,.42),(.09,.04,.09),light,'cube')
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
 bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out,name+".blend"))
 # Keep parts editable in Blender and batch the static geometry by material in glTF.
 depsgraph = bpy.context.evaluated_depsgraph_get()
 sources = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
 export_meshes = []
 export_objects = []
 for source in sources:
  mesh = bpy.data.meshes.new_from_object(source.evaluated_get(depsgraph), depsgraph=depsgraph)
  export_meshes.append(mesh)
  obj = bpy.data.objects.new(source.name + " export", mesh)
  bpy.context.collection.objects.link(obj)
  obj.matrix_world = source.matrix_world.copy()
  export_objects.append(obj)
 combined_mesh = bpy.data.meshes.new(name)
 combined = bpy.data.objects.new(name, combined_mesh)
 bpy.context.collection.objects.link(combined)
 try:
  bpy.ops.object.select_all(action='DESELECT')
  for obj in export_objects:
   obj.select_set(True)
  combined.select_set(True)
  bpy.context.view_layer.objects.active = combined
  bpy.ops.object.join()
  result = bpy.ops.export_scene.gltf(
   filepath=os.path.join(out,name+".glb"), export_format='GLB', use_selection=True
  )
  if 'FINISHED' not in result:
   raise RuntimeError(f"GLB export failed for {name}")
 finally:
  bpy.data.objects.remove(combined, do_unlink=True)
  for mesh in [combined_mesh, *export_meshes]:
   if mesh.users == 0:
    bpy.data.meshes.remove(mesh)
mint=mat("Jade shell",(.024,.47,.31),.26);dark=mat("Graphite",(.025,.045,.065),.5);gold=mat("Amber",(.95,.48,.06),.3);red=mat("Coral",(.85,.08,.09),.2)
reset()
core=glow("Jade energy",(.085,.76,.49))
gel=mat("Slime membrane",(.032,.32,.205),.12)
optic=mat("Smoked green visor",(.009,.043,.043),.42)
bezel=mat("Burnished titanium trim",(.21,.31,.29),.76)
part("Gel dome",(0,.025,.98),(.57,.45,.35),gel)
part("Dome collar",(0,.04,.76),(.61,.49,.12),mint)
part("Wave guard",(0,-.016,.56),(.55,.43,.26),dark,'facet')
part("Visor bezel",(0,-.355,.853),(.49,.16,.202),bezel)
part("Visor lens",(0,-.438,.849),(.45,.129,.158),optic)
for side in [-1,1]:
 eye=part("Visor light",(side*.19,-.536,.865),(.102,.036,.031),core)
 eye.rotation_euler.z=side*.16
 part("Shoulder seal",(side*.56,-.006,.614),(.192,.235,.21),dark)
 part("Armored shoulder",(side*.61,.034,.68),(.19,.23,.145),mint,'facet')
 for rib in range(3):
  part("Shoulder plate seam",(side*.72,.015+rib*.084,.689),(.028,.020,.096),bezel,'cube')
 part("Forearm guiding rail",(side*.61,-.146,.475),(.106,.118,.149),bezel,'cube')
 part("Boot",(side*.267,-.089,.128),(.223,.279,.132),dark,'cube')
 part("Boot toe",(side*.267,-.293,.13),(.159,.123,.080),mint,'facet')
 part("Pack cell",(side*.25,.379,.64),(.147,.135,.26),mint)
 part("Pack indicator",(side*.25,.493,.64),(.06,.027,.158),core,'cube')
part("Reactor bezel",(0,-.405,.484),(.184,.070,.155),bezel,'facet')
part("Reactor light",(0,-.464,.484),(.109,.065,.094),core,'facet')
part("Weapon receiver",(.725,-.279,.445),(.155,.30,.119),dark,'cube')
part("Weapon rail",(.725,-.412,.545),(.075,.218,.038),bezel,'cube')
part("Weapon barrel",(.725,-.59,.423),(.073,.216,.071),mint,'cube')
part("Muzzle",(.725,-.795,.423),(.086,.036,.08),core,'cube')
save("hero")
for name,color,shape in [
 ("cyborg",(.25,.45,.8),"cube"),
 ("inferno",(.95,.18,.035),"sphere"),
 ("ghost",(.48,.25,.85),"sphere"),
 ("titan",(.65,.42,.12),"cube"),
 ("cryo",(.08,.36,.55),"facet")]:
 reset()
 shell=mat(name+" shell",color,.35)
 part("Body",(0,0,.65),(.64,.48,.62),shell,shape)
 part("Visor",(0,-.43,.83),(.43,.13,.24),dark)
 for x in [-.19,.19]: part("Eye",(x,-.55,.86),(.08,.035,.075),gold)
 for x in [-.65,.65]:
  part("Shoulder",(x,0,.68),(.24,.25,.26),shell,shape)
  part("Arm",(x,0,.38),(.16,.18,.25),dark)
 for x in [-.25,.25]: part("Boot",(x,-.08,.12),(.23,.32,.13),dark,'cube')
 if name=="titan":
  part("Chest plate",(0,-.4,.48),(.46,.13,.22),gold,'cube')
 if name=="inferno":
  for x in [-.35,.35]: part("Heat fin",(x,.1,1.2),(.13,.15,.35),gold)
 if name=="cryo":
  frost=mat("Frosted ceramic",(.44,.65,.71),.42)
  cyan=glow("Refrigerant",(.10,.52,.74))
  part("Cryostat",(0,.39,.67),(.28,.22,.40),frost,'facet')
  for side in [-1,1]:
   shard=part("Shoulder ice shield",(side*.52,-.01,1.0),(.172,.186,.39),frost,'crystal')
   shard.rotation_euler.y=side*.48
   part("Coolant gauge",(side*.39,-.338,.68),(.085,.040,.107),cyan,'facet')
 if name=="ghost":
  part("Crest",(0,0,1.2),(.18,.35,.2),shell)
 if name=="cyborg":
  part("Antenna",(.35,0,1.35),(.05,.05,.25),gold)
 hero_details(name,shell)
 save(name)
reset()
sensor=glow("Enemy sensor",(1,.13,.055))
enemy_edge=mat("Iron oxide armor",(.32,.058,.048),.55)
part("Chassis",(0,.03,.32),(.42,.57,.22),dark,'facet')
part("Carapace",(0,.14,.55),(.44,.47,.29),red,'facet')
part("Sensor housing",(0,-.33,.42),(.31,.31,.21),enemy_edge,'facet')
part("Sensor slit",(0,-.57,.47),(.19,.057,.041),sensor,'cube')
for side in [-1,1]:
 for row in [-1,1]:
  strut=part("Leg strut",(side*.43,row*.25,.21),(.105,.26,.105),enemy_edge,'cube')
  strut.rotation_euler.z=side*row*.57
  part("Foot plate",(side*.57,row*.37,.11),(.13,.17,.11),dark,'facet')
 part("Luminous carapace vent",(side*.20,.29,.78),(.034,.11,.027),sensor,'cube')
save("enemy")
reset()
crate_shell=mat("Crate ceramic alloy",(.073,.15,.17),.38)
crate_trim=mat("Crate edge alloy",(.27,.38,.37),.68)
crate_corner=mat("Weathered brass",(.49,.25,.074),.72)
crate_lock=glow("Crate charge indicator",(1,.48,.07))
part("Recessed core",(0,0,.44),(.48,.45,.40),dark,'cube')
part("Bolted base",(0,0,.10),(.56,.52,.10),crate_trim,'cube')
part("Raised lid",(0,0,.84),(.48,.47,.095),crate_shell,'cube')
for side in [-1,1]:
 part("Side casing",(side*.46,0,.45),(.095,.40,.29),crate_shell,'cube')
 part("Lid hinge",(side*.31,.46,.83),(.11,.082,.085),crate_trim,'cube')
 for end in [-1,1]:
  foot=part("Impact corner",(side*.47,end*.43,.46),(.13,.13,.33),crate_corner,'cube')
  foot.rotation_euler.z=side*end*.20
  part("Corner rivet",(side*.48,end*.45,.79),(.039,.039,.024),crate_trim)
 part("Live charge bar",(side*.12,0,.942),(.04,.24,.025),crate_lock,'cube')
for end in [-1,1]:
 part("Handle recess",(0,end*.456,.33),(.18,.038,.075),crate_trim,'cube')
part("Latch housing",(0,-.48,.66),(.22,.09,.12),crate_trim,'cube')
part("Latch indicator",(0,-.565,.66),(.095,.024,.043),crate_lock,'cube')
save("crate")

# Environment and vehicle assets
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
 else:
  part("Base",(0,0,.12),(1.2,1.2,.12),dark,'cube')
  for i in range(3):
   part("Formation "+str(i),((i-1)*.65,0,.55+i*.15),(.3,.38,.45+i*.15),surface,'cube' if name=="city" else 'sphere')
 save(name)
reset()
part("Chassis",(0,0,.5),(.65,1,.25),gold,'cube')
part("Cabin",(0,.1,.85),(.45,.5,.3),dark,'cube')
for x in [-.7,.7]:
 for y in [-.65,.65]:
  part("Wheel",(x,y,.3),(.22,.32,.32),dark)
buggy_light=glow("Buggy headlights",(.65,.85,1))
for x in [-.48,.48]:
 part("Headlight",(x,-1.02,.52),(.12,.06,.10),buggy_light,'cube')
 part("Suspension",(x,0,.33),(.10,.65,.10),dark,'cube')
 for y in [-.65,.65]:
  part("Wheel hub",(x*1.85,y,.3),(.06,.17,.17),gold)
part("Front bumper",(0,-1.04,.34),(.68,.09,.09),dark,'cube')
part("Rear engine",(0,.75,.83),(.36,.22,.15),dark,'cube')
save("buggy")


# Additional original modular assets.
for name,c,size in [
 ("enemy_fast",(.64,.22,.078),.65),("enemy_armored",(.42,.077,.064),1.2),
 ("boss_overlord",(.65,.08,.2),2.0),("boss_crystal",(.12,.65,.95),1.8),("boss_inferno",(.95,.24,.04),1.9)]:
 reset()
 shell=mat(name,c,.45)
 core_shape='facet' if name in {"enemy_fast","enemy_armored","boss_crystal"} else 'cube'
 part("Core",(0,0,.65*size),(.55*size,.48*size,.55*size),shell,core_shape)
 part("Visor",(0,-.48*size,.8*size),(.38*size,.12*size,.15*size),dark,'cube')
 for x in [-1,1]:
  armor=part("Armor",(x*.61*size,0,.63*size),(.28*size,.38*size,.37*size),shell,core_shape)
  armor.rotation_euler.y=x*.36
  part("Emitter",(x*.65*size,-.32*size,.65*size),(.12*size,.18*size,.12*size),gold)
 sensor=glow(name+" sensor",(1,.12,.04) if name!="boss_crystal" else (.1,.8,1))
 part("Sensor",(0,-.60*size,.8*size),(.24*size,.04*size,.055*size),sensor,'cube')
 for x in [-1,1]:
  part("Armor trim",(x*.65*size,-.35*size,.88*size),(.13*size,.07*size,.045*size),sensor,'cube')
 trim=mat(name+" armor trim",(.22,.26,.31),.8)
 for x in [-1,1]:
  part("Joint housing",(x*.48*size,0,.25*size),(.19*size,.24*size,.19*size),dark)
  part("Armor cap",(x*.65*size,0,1.02*size),(.20*size,.29*size,.07*size),trim,'cube')
 if name=="enemy_fast":
  for x in [-1,1]:
   fin=part("Speed fin",(x*.48*size,.32*size,.85*size),(.08*size,.34*size,.16*size),shell,'cube')
   fin.rotation_euler.z=x*.28
 elif name=="enemy_armored":
  for side in [-1,1]:
   plate=part("Segmented dorsal armor",(side*.28*size,.19*size,1.01*size),(.23*size,.28*size,.083*size),trim,'facet')
   plate.rotation_euler.y=side*.35
   shield=part("Angled shield",(side*.24*size,-.48*size,.40*size),(.24*size,.14*size,.24*size),trim,'cube')
   shield.rotation_euler.z=side*.36
   part("Ground stabilizer",(side*.62*size,-.15*size,.15*size),(.21*size,.39*size,.14*size),dark,'facet')
 elif name=="boss_overlord":
  for x in [-1,1]:
   part("Command horn",(x*.38*size,.04*size,1.32*size),(.11*size,.13*size,.29*size),gold)
   part("Heavy gauntlet",(x*.83*size,-.12*size,.43*size),(.22*size,.31*size,.24*size),trim,'cube')
 elif name=="boss_crystal":
  for i in range(5):
   a=i*math.tau/5
   crystal=part("Crystal crown",(math.cos(a)*.36*size,math.sin(a)*.36*size,1.18*size),(.14*size,.14*size,(.31+.056*i)*size),sensor,'crystal')
   crystal.rotation_euler.y=.39*math.cos(a)
   crystal.rotation_euler.x=-.39*math.sin(a)
 elif name=="boss_inferno":
  for x in [-1,1]:
   for i in range(3):
    part("Thermal vent",(x*.44*size,(i-1)*.19*size,1.18*size),(.08*size,.06*size,.18*size),sensor,'cube')
 save(name)
for name,c in [("hovercraft",(.1,.7,.8)),("tank",(.25,.42,.18)),("mech",(.5,.4,.65))]:
 reset()
 shell=mat(name,c,.5)
 part("Hull",(0,0,.45),(.8,1,.28),shell,'cube')
 part("Cabin",(0,.1,.9),(.45,.5,.3),dark,'cube')
 for x in [-.8,.8]:
  part("Drive",(x,0,.3),(.22,.85,.25),dark,'cube')
 if name=="tank": part("Cannon",(0,-.85,.9),(.13,.75,.13),shell,'cube')
 if name=="mech":
  for x in [-.7,.7]: part("Leg",(x,0,.2),(.2,.3,.6),shell,'cube')
 lamp=glow(name+" drive lights",(.12,.85,1) if name=="hovercraft" else (1,.56,.14))
 for x in [-1,1]:
  part("Headlight",(x*.57,-1.02,.51),(.12,.06,.08),lamp,'cube')
  part("Side armor",(x*.78,0,.59),(.09,.66,.12),shell,'cube')
  part("Rear exhaust",(x*.48,.94,.55),(.12,.09,.12),lamp)
 if name=="tank":
  for x in [-1,1]:
   for i in range(5):
    part("Track hub",(x*.99,(i-2)*.31,.30),(.055,.13,.13),shell)
 elif name=="hovercraft":
  for x in [-1,1]:
   part("Lift emitter",(x*.8,0,.15),(.16,.66,.06),lamp,'cube')
 elif name=="mech":
  for x in [-1,1]:
   part("Leg joint",(x*.7,-.28,.45),(.16,.10,.16),lamp)
 save(name)
for name,c in [("tree",(.15,.55,.24)),("rock",(.42,.43,.48)),("ruin",(.5,.47,.4)),("cactus",(.2,.58,.25)),("ice_spire",(.2,.8,.95)),("lava_vent",(.9,.22,.04))]:
 reset()
 shell=mat(name,c)
 if name not in ("tree","rock","ruin"):
  part("Base",(0,0,.12),(.75,.75,.12),dark,'cube')
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
  part("Stem",(0,0,.8),(.23,.23,.8),shell)
  for x in [-1,1]:
   part("Branch",(x*.29,0,.65),(.32,.13,.13),shell)
   part("Branch tip",(x*.52,0,.85),(.13,.13,.32),shell)
 elif name=="lava_vent":
  ember=glow("Molten core",(1,.18,.015))
  part("Molten core",(0,0,.27),(.38,.38,.15),ember)
  for i in range(5):
   angle=i*math.tau/5
   part("Basalt rim",(math.cos(angle)*.48,math.sin(angle)*.48,.38),(.23,.24,.34),dark,'cube')
 elif name=="ice_spire":
  frost=mat("Frost facets",(.58,.87,.96),.2)
  for i in range(3):
   obj=part("Ice facet",((i-1)*.35,0,.55+i*.24),(.22,.23,.55+i*.24),frost if i==1 else shell,'cube')
   obj.rotation_euler.y=(i-1)*.18
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

# Preview rendering is a separate optional invocation.
if "--preview" in __import__("sys").argv:
 preview=os.path.join(out,"previews")
 os.makedirs(preview,exist_ok=True)
 for name in ["hero","cyborg","inferno","ghost","titan","cryo","buggy","forest","city","desert","ice","volcano"]:
  bpy.ops.wm.open_mainfile(filepath=os.path.join(out,name+".blend"))
  scene=bpy.context.scene
  bpy.ops.object.camera_add(location=(4,-6,3.8))
  cam=bpy.context.object
  cam.rotation_euler=(Vector((0,0,.65))-cam.location).to_track_quat('-Z','Y').to_euler()
  cam.data.type='ORTHO';cam.data.ortho_scale=4.2
  scene.camera=cam
  for loc,energy in [((3,-4,6),900),((-3,2,4),650)]:
   bpy.ops.object.light_add(type='AREA',location=loc)
   lamp=bpy.context.object;lamp.data.energy=energy;lamp.data.shape='DISK';lamp.data.size=4
   lamp.rotation_euler=(Vector((0,0,.5))-lamp.location).to_track_quat('-Z','Y').to_euler()
  scene.render.engine='CYCLES';scene.cycles.samples=12
  scene.render.resolution_x=512;scene.render.resolution_y=512;scene.render.resolution_percentage=100
  scene.render.image_settings.file_format='PNG'
  scene.render.filepath=os.path.join(preview,name+".png")
  bpy.ops.render.render(write_still=True)
