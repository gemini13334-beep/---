import bpy, math, os
from mathutils import Vector
out=os.path.abspath(os.path.join(os.path.dirname(__file__),"../assets/models"))
os.makedirs(out,exist_ok=True)
def mat(name,c,metal=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True
 p=m.node_tree.nodes.get("Principled BSDF");p.inputs["Base Color"].default_value=(*c,1);p.inputs["Metallic"].default_value=metal;p.inputs["Roughness"].default_value=.36
 return m
def reset():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def part(name,loc,scale,m,kind='sphere'):
 if kind=='sphere': bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=loc)
 else: bpy.ops.mesh.primitive_cube_add(size=2,location=loc)
 o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(m)
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if kind=='cube':
  mod=o.modifiers.new("Rounded armor","BEVEL");mod.width=.08;mod.segments=2
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
 save(name)
reset()
part("Core",(0,0,.48),(.46,.43,.45),red,'cube')
part("Visor",(0,-.43,.55),(.32,.08,.12),dark,'cube')
for x in [-.48,.48]: part("Claw",(x,0,.25),(.15,.23,.25),gold)
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
