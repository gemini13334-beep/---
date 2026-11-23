extends "res://scripts/registry.gd"

const ARCHIVE := 2
const HQ := 3
const OFFICE := 4
const ARCHIVE_FILE := Vector3(-4.25,1.12,-8.15)
const RADIOS := [Vector3(-5.1,1.34,2.8),Vector3(5.0,1.34,-7.0)]
const REPORT := Vector3(-5.5,1.10,4.1)
const SIGNATURE := Vector3(0.6,1.24,-9.45)
var stage_id: int
var stamped := false
var collected := 0
var iron: StandardMaterial3D
var timber: StandardMaterial3D
var brass: StandardMaterial3D
var lamp_glass: StandardMaterial3D

func _init(stage: int) -> void:
 stage_id = stage

func picture(texture: String, pos: Vector3, width: float, height: float, yaw := 0.0) -> void:
 var plane := QuadMesh.new()
 plane.size = Vector2(width,height)
 var image := MeshInstance3D.new()
 image.mesh = plane
 image.position = pos
 image.rotation.y = yaw
 image.material_override = material(Color.WHITE,"res://assets/wing/"+texture+".webp")
 image.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(image)

func build() -> void:
 iron = material(Color("#515653"),"res://assets/courtyard/surface-3.webp",0.62)
 timber = material(Color("#a88b69"),"res://assets/courtyard/surface-2.webp",0.40)
 brass = material(Color("#aa7545"))
 lamp_glass = material(Color("#ffe7ad"),"",0,true)
 var wall_color: Color = [Color("#9c947b"),Color("#707e75"),Color("#bbad95")][stage_id-2]
 var walls := material(wall_color,"res://assets/registry/office-3.webp",0.28)
 var floor_mat := timber if stage_id==OFFICE else material(Color("#a9a393"),"res://assets/registry/office-2.webp",0.30)
 box(self,Vector3(0,-0.15,0),Vector3(22,0.30,31),floor_mat,true)
 box(self,Vector3(0,5.52,0),Vector3(22,0.18,31),walls)
 for side in [-1,1]:
  box(self,Vector3(side*11,2.75,0),Vector3(.35,5.5,31),walls,true)
  box(self,Vector3(0,2.75,side*15.45),Vector3(22,5.5,.36),walls,true)
  for z in [-10,0,10]:
   box(self,Vector3(side*10.72,2.7,z),Vector3(.40,5.4,.55),timber if stage_id==OFFICE else iron)
  for z in [-11,-4,3,10]:
   if stage_id==OFFICE:
    picture("walnut",Vector3(side*10.78,1.0,z),6.96,2.0,-side*PI/2)
   picture("window" if stage_id!=HQ else "iron",Vector3(side*10.76,3.50,z),4.8,2.45,-side*PI/2)
 for z in [-10,-2,6,13]:
  box(self,Vector3(0,5.26,z),Vector3(21.85,.27,.43),timber if stage_id==OFFICE else iron)
  for x in [-3.4,3.4]:
   box(self,Vector3(x,4.97,z),Vector3(2.38,.30,.50),iron)
   box(self,Vector3(x,4.81,z),Vector3(2.18,.03,.36),lamp_glass)
 match stage_id:
  ARCHIVE: _archive()
  HQ: _headquarters()
  OFFICE: _office()
 _light_room()

func _light_room() -> void:
 var env := Environment.new()
 env.background_mode = Environment.BG_COLOR
 env.background_color = Color("#5c594c")
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color = Color("#eeceaa") if stage_id==OFFICE else Color("#c7d1c7")
 env.ambient_light_energy = .76
 var world := WorldEnvironment.new()
 world.environment = env
 add_child(world)
 for z in [-9,1,10]:
  var light := OmniLight3D.new()
  light.position = Vector3(-2 if z==1 else 2,4.5,z)
  light.light_color = Color("#f6c98c") if stage_id!=HQ or z!=1 else Color("#b9d9da")
  light.light_energy = 2.25
  light.omni_range = 14.0
  add_child(light)
 # One shadowed practical light keeps machinery and furniture grounded on mobile.
 var key := SpotLight3D.new()
 key.position = Vector3(-6.9,4.86,-4)
 key.light_color = Color("#ffdda5")
 key.light_energy = 3.6
 key.spot_range = 17
 key.spot_angle = 59
 key.shadow_enabled = true
 add_child(key)
 key.look_at(Vector3(1.6,.4,-9.8))

func rack(x: float, z: float, width: float, height: float) -> void:
 box(self,Vector3(x,height/2,z),Vector3(width,height,1.10),iron,true)
 for side in [-1,1]:
  picture("shelves",Vector3(x,height/2,z+side*.558),width-.08,height-.08,0 if side==1 else PI)
 for side in [-1,1]:
  var end:=box(self,Vector3(x+side*(width/2+.011),height/2,z),Vector3(.018,height,1.02),timber)
  for y in [.2,height*.48,height-.16]:
   box(self,end.position+Vector3(side*.016,y-height/2,0),Vector3(.035,.065,1.01),brass)
 for edge in [-1,1]:
  box(self,Vector3(x+edge*(width/2-.04),height/2,z+.59),Vector3(.08,height,.085),brass)

func _archive() -> void:
 for z in [-9.2,-2.3,4.8]:
  for x in [-5.3,5.3]:
   rack(x,z,4.8,3.30)
 for x in [-7.2,-2.4,2.4,7.2]:
  rack(x,-14.3,4.74,3.86)
 for x in [-1.2,1.2]:
  box(self,Vector3(x,.012,0),Vector3(.08,.024,29.5),brass)
 for n in 3:
  var plate_z:=5.39-n*7
  box(self,Vector3(-5.3,3.46,plate_z),Vector3(2.46,.46,.10),iron)
  lettering("ФОНД  %02d"%(n+1),Vector3(-5.3,3.46,plate_z+.057),.0044,Color("#ffe3aa"))
 for i in 3:
  var stack:=Vector3(8.7,.40,-2.5+i*1.05)
  box(self,stack,Vector3(.88,.80,.91),timber,true)
  box(self,stack+Vector3(0,.05,.46),Vector3(.39,.16,.012),material(Color("#d8cdaa")))
 lettering("АРХИВ ЛИЧНОГО СОСТАВА",Vector3(0,4.61,-14.52),.008,Color("#ffe3b8"))
 box(self,Vector3(ARCHIVE_FILE.x,.53,ARCHIVE_FILE.z-.34),Vector3(1.6,1.06,.72),timber,true)

func console(at: Vector3) -> void:
 box(self,at+Vector3(0,.64,-.40),Vector3(2.48,1.28,1.2),iron,true)
 box(self,at+Vector3(0,1.31,-.38),Vector3(2.60,.08,1.26),brass)
 for x in [-.58,.58]:
  box(self,at+Vector3(x,1.68,-.71),Vector3(.94,.63,.24),iron)
  box(self,at+Vector3(x,1.68,-.58),Vector3(.78,.42,.02),material(Color("#619487"),"",0,true))
  for j in 3:
   box(self,at+Vector3(x-.23+j*.23,1.37,-.04),Vector3(.12,.045,.12),brass)

func _headquarters() -> void:
 var green := material(Color("#3f584f"))
 box(self,Vector3(0,2.68,-14.95),Vector3(10,4.75,.42),iron,true)
 picture("situation",Vector3(0,2.7,-14.72),9.70,4.50)
 for x in [-8.35,8.35]:
  for z in [-8.1,-5.9,4.7,6.9]:
   box(self,Vector3(x,1.51,z),Vector3(1.35,3.02,1.65),iron,true)
   for j in 5:
    box(self,Vector3(x,0.52+j*.47,z+.837),Vector3(1.06,.17,.025),green)
    box(self,Vector3(x-.43,.52+j*.47,z+.856),Vector3(.072,.08,.02),lamp_glass)
 for pos: Vector3 in RADIOS: console(Vector3(pos.x,0,pos.z))
 for side in [-1,1]:
  for x in [5.65,7.18,8.71]:
   var location:=Vector3(side*x,2.8,-15.10)
   box(self,location,Vector3(1.42,3.4,.24),iron)
   for j in 4:
    box(self,location+Vector3(0,1.13-j*.69,.127),Vector3(1.12,.48,.028),green)
    box(self,location+Vector3(-.32,1.2-j*.69,.151),Vector3(.09,.07,.017),lamp_glass)
  for h in [4.48,4.72]:
   box(self,Vector3(side*10.53,h,0),Vector3(.13,.13,29.7),brass)

 # A waist-high plotting table splits the command bay into two passages.
 box(self,Vector3(0,.58,-3.3),Vector3(3.80,1.16,2.25),iron,true)
 box(self,Vector3(0,1.20,-3.3),Vector3(4.02,.12,2.45),green)
 var map := MeshInstance3D.new()
 var sheet := PlaneMesh.new()
 sheet.size = Vector2(3.78,2.22)
 map.mesh = sheet
 map.position = Vector3(0,1.267,-3.3)
 map.material_override = material(Color.WHITE,"res://assets/wing/situation.webp")
 add_child(map)
 lettering("УЗЕЛ СВЯЗИ",Vector3(0,5.0,-14.58),.0067,Color("#ffe1a5"))

func desk(center: Vector3, width: float, height: float) -> void:
 box(self,center+Vector3.UP*(height/2),Vector3(width-.18,height,1.48),timber,true)
 box(self,center+Vector3.UP*(height+.045),Vector3(width,.09,1.66),timber)
 picture("walnut",center+Vector3(0,height/2,.752),width-.25,height-.09)
 box(self,center+Vector3(-width*.31,height+.18,.13),Vector3(.42,.16,.31),iron)
 box(self,center+Vector3(-width*.31,height+.39,.13),Vector3(.046,.43,.046),brass)
 box(self,center+Vector3(-width*.31,height+.61,.13),Vector3(.53,.13,.30),lamp_glass)

func _office() -> void:
 var leather := material(Color("#694539"))
 var carpet := ShaderMaterial.new()
 carpet.shader = preload("res://assets/wing/runner.gdshader")
 var textile := PlaneMesh.new()
 textile.size = Vector2(3.9,23)
 var runner := MeshInstance3D.new()
 runner.mesh=textile
 runner.position.y=.012
 runner.material_override=carpet
 add_child(runner)
 for x in [-1.86,1.86]:
  box(self,Vector3(x,.027,0),Vector3(.065,.012,22.8),brass)
 for side in [-1,1]:
  box(self,Vector3(side*7.35,1.32,.0),Vector3(7.3,2.64,.46),timber,true)
  picture("walnut",Vector3(side*7.35,1.32,.245),7.15,2.43)
  box(self,Vector3(side*3.80,2.52,0),Vector3(.45,5.04,.64),timber,true)
  picture("walnut",Vector3(side*5.45,1.15,-15.255),10.8,2.24)
  for j in 4:
   var x:float=side*(3.1+j*.42)
   box(self,Vector3(x,2.76,-14.97+(.09 if j%2 else 0.0)),Vector3(.44,5.18,.26),material(Color("#6a392d") if j%2 else Color("#834c39")))
  picture("window",Vector3(side*7.65,3.34,-15.24),4.2,2.52)
  box(self,Vector3(side*6.8,.59,-6.8),Vector3(2.40,.56,1.04),leather,true)
  box(self,Vector3(side*6.8,1.04,-7.27),Vector3(2.45,.77,.21),leather)
  for end in [-1,1]:
   box(self,Vector3(side*6.8+end*1.21,.85,-6.82),Vector3(.18,.34,1.06),timber)

 box(self,Vector3(0,3.36,-14.98),Vector3(3.16,3.52,.30),brass)
 picture("director",Vector3(0,3.36,-14.815),2.93,3.28)
 desk(Vector3(0,0,-10.12),4.42,1.14)
 desk(Vector3(REPORT.x,0,REPORT.z-.67),2.62,1.0)
 for i in 4:
  var sheet:=box(self,Vector3(-.25,1.239+i*.012,-10.05),Vector3(.49,.009,.35),material(Color("#ead7b8")))
  sheet.rotation.y=.06*i
 lettering("НАЧАЛЬНИК",Vector3(0,1.37,-9.54),.0028,Color("#ffdb99"))
 var stamp := preload("res://assets/models/registry-stamp.glb").instantiate() as Node3D
 stamp.position = Vector3(1.23,1.235,-9.9)
 add_child(stamp)
 box(self,Vector3(0,.68,-12.1),Vector3(1.08,.22,1.0),leather,true)
 box(self,Vector3(0,1.38,-12.52),Vector3(1.08,1.42,.21),leather)
 for x in [-.52,.52]:
  box(self,Vector3(x,.96,-12.1),Vector3(.12,.15,1.02),timber)
 lettering("ПРИЁМНАЯ",Vector3(-7.05,2.02,.27),.006,Color("#ffdf9f"))

func _marker(at: Vector3, title: String) -> void:
 var marker := Node3D.new()
 marker.position = at
 add_child(marker)
 if stage_id != HQ:
  box(marker,Vector3.ZERO,Vector3(.59,.05,.39),material(Color("#c38747")))
  box(marker,Vector3(.02,.035,0),Vector3(.48,.018,.33),material(Color("#f7e9c7")))
 var sign_label := lettering(title,at+Vector3.UP*.53,.0037,Color("#ffe0a2"))
 sign_label.reparent(marker)
 sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 sign_label.outline_size = 7
 files.append(marker)

func reset_files() -> void:
 for marker in files: marker.free()
 files.clear()
 collected = 0
 stamped = false
 match stage_id:
  ARCHIVE: _marker(ARCHIVE_FILE,"ЛИЧНОЕ ДЕЛО")
  HQ:
   for i in RADIOS.size(): _marker(RADIOS[i],"СВЯЗЬ  %02d"%(i+1))
  OFFICE: _marker(REPORT,"ЗАБРАТЬ РАПОРТ")

func collect_near(player: Vector3) -> bool:
 if not super.collect_near(player): return false
 collected += 1
 if stage_id == OFFICE:
  if collected == 1: _marker(SIGNATURE,"ПОЛУЧИТЬ ПОДПИСЬ")
  else: stamped = true
 return true

func objective_status() -> String:
 match stage_id:
  ARCHIVE: return "ЛИЧНОЕ ДЕЛО  %d / 1"%collected
  HQ: return "СВЯЗЬ  %d / 2"%collected
  OFFICE:
   if stamped: return "РАПОРТ ПОДПИСАН"
   return "ПОЛУЧИТЕ ПОДПИСЬ" if collected else "ЗАБЕРИТЕ РАПОРТ"
 return ""
