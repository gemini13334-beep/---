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
 else: bpy.ops.mesh.primitive_cube_add(size=2,location=loc)
 o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(m)
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if kind=='cube':
  mod=o.modifiers.new("Rounded armor","BEVEL");mod.width=.045;mod.segments=3
  normal=o.modifiers.new("Weighted armor normals","WEIGHTED_NORMAL");normal.keep_sharp=True
 else:
  for face in o.data.polygons: face.use_smooth=True
 return o
def save(name):
 bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out,name+".blend"))
 bpy.ops.export_scene.gltf(filepath=os.path.join(out,name+".glb"),export_format='GLB')
mint=mat("Mint shell",(.04,.75,.48),.25);dark=mat("Graphite",(.025,.045,.065),.5);gold=mat("Amber",(.95,.48,.06),.3);red=mat("Coral",(.85,.08,.09),.2)
reset()
part("Body",(0,0,.65),(.64,.48,.62),mint)
part("Visor",(0,-.43,.83),(.43,.13,.24),dark)
for x in [-.19,.19]: part("Eye",(x,-.55,.86),(.08,.035,.075),gold)
for x in [-.65,.65]: part("Arm",(x,0,.56),(.19,.22,.33),dark)
for x in [-.25,.25]: part("Boot",(x,-.08,.12),(.23,.32,.13),dark,'cube')
hero_details("hero",mint)
save("hero")
for name,color,shape in [
 ("cyborg",(.25,.45,.8),"cube"),
 ("inferno",(.95,.18,.035),"sphere"),
 ("ghost",(.48,.25,.85),"sphere"),
 ("titan",(.65,.42,.12),"cube"),
 ("cryo",(.08,.7,.95),"cube")]:
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
  part("Cooling core",(0,.43,.65),(.32,.2,.4),gold,'cube')
 if name=="ghost":
  part("Crest",(0,0,1.2),(.18,.35,.2),shell)
 if name=="cyborg":
  part("Antenna",(.35,0,1.35),(.05,.05,.25),gold)
 hero_details(name,shell)
 save(name)
reset()
part("Core",(0,0,.48),(.46,.43,.45),red,'cube')
part("Visor",(0,-.43,.55),(.32,.08,.12),dark,'cube')
for x in [-.48,.48]: part("Claw",(x,0,.25),(.15,.23,.25),gold)
part("Sensor",(0,-.51,.55),(.19,.035,.055),glow("Enemy sensor",(1,.12,.04)))
part("Rear armor",(0,.40,.48),(.34,.12,.32),dark,'cube')
save("enemy")
reset()
part("Crate",(0,0,.45),(.48,.48,.45),dark,'cube')
for x in [-.38,.38]: part("Armor",(x,0,.46),(.08,.5,.46),gold,'cube')
save("crate")

# Environment and vehicle assets
for name,c in [("forest",(.18,.48,.22)),("city",(.35,.4,.48)),("desert",(.72,.45,.18)),("ice",(.3,.72,.88)),("volcano",(.35,.09,.05))]:
 reset()
 surface=mat(name+" surface",c)
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
save("buggy")


# Additional original modular assets.
for name,c,size in [
 ("enemy_fast",(.95,.32,.12),.65),("enemy_armored",(.48,.12,.15),1.2),
 ("boss_overlord",(.65,.08,.2),2.0),("boss_crystal",(.12,.65,.95),1.8),("boss_inferno",(.95,.24,.04),1.9)]:
 reset()
 shell=mat(name,c,.45)
 part("Core",(0,0,.65*size),(.55*size,.48*size,.55*size),shell,'cube')
 part("Visor",(0,-.48*size,.8*size),(.38*size,.12*size,.15*size),dark,'cube')
 for x in [-1,1]:
  part("Armor",(x*.65*size,0,.65*size),(.23*size,.35*size,.4*size),shell,'cube')
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
  part("Front shield",(0,-.48*size,.40*size),(.44*size,.12*size,.25*size),trim,'cube')
 elif name=="boss_overlord":
  for x in [-1,1]:
   part("Command horn",(x*.38*size,.04*size,1.32*size),(.11*size,.13*size,.29*size),gold)
   part("Heavy gauntlet",(x*.83*size,-.12*size,.43*size),(.22*size,.31*size,.24*size),trim,'cube')
 elif name=="boss_crystal":
  for i in range(5):
   a=i*math.tau/5
   crystal=part("Crystal crown",(math.cos(a)*.37*size,math.sin(a)*.37*size,1.18*size),(.10*size,.10*size,.28*size),sensor,'cube')
   crystal.rotation_euler.y=.25*math.cos(a)
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
 save(name)
for name,c in [("tree",(.15,.55,.24)),("rock",(.42,.43,.48)),("ruin",(.5,.47,.4)),("cactus",(.2,.58,.25)),("ice_spire",(.2,.8,.95)),("lava_vent",(.9,.22,.04))]:
 reset()
 shell=mat(name,c)
 part("Base",(0,0,.12),(.75,.75,.12),dark,'cube')
 if name=="tree":
  part("Trunk",(0,0,.65),(.16,.16,.65),dark,'cube')
  part("Crown",(0,0,1.4),(.7,.65,.75),shell)
 else:
  for i in range(3):
   obj=part("Detail "+str(i),((i-1)*.38,0,.4+i*.22),(.26,.35,.4+i*.2),shell,'cube' if name in ["ruin","ice_spire"] else 'sphere')
   obj.rotation_euler.z=i*.3
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
