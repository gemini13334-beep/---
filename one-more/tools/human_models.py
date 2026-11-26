"""Original reference-inspired operators and their mobile rigs."""
from math import cos, pi, sin, tau
from pathlib import Path

import bpy
from mathutils import Vector

from combat_models import lens, material, mesh, shaft, shell, slab


OPERATORS = {
    "vega": ("Vega", (.72, .73, .77), (.71, .23, .047), (.059, .077, .108), 1.0, True),
    "fox": ("Fox", (.115, .043, .023), (.48, .12, .056), (.106, .091, .054), 1.0, True),
    "amber": ("Amber", (.079, .047, .034), (.73, .29, .038), (.067, .080, .083), 1.12, False),
    "north": ("North", (.108, .054, .028), (.27, .039, .048), (.109, .116, .080), 1.10, False),
}
ROUND = [(cos(i*tau/20), sin(i*tau/20)) for i in range(20)]


def taper(name, rings, paint):
    obj = shell(name, rings, paint, 0.0, ROUND)
    for face in list(obj.data.polygons)[1:-1]:
        face.use_smooth = True
    return obj


def strand(name, points, paint):
    """A set of tapering swept ribbons with elliptical, closed sections."""
    def smooth(i, fraction):
        samples = [Vector((*points[min(max(0,k),len(points)-1)][0],points[min(max(0,k),len(points)-1)][1]))
                   for k in (i-1,i,i+1,i+2)]
        a,b,c,d = samples
        f = fraction
        v = (2*b+(c-a)*f+(2*a-5*b+4*c-d)*f*f+(d-a+3*b-3*c)*f*f*f)*.5
        return (v.xyz,max(.001,v.w))

    points = [smooth(i,t/4) for i in range(len(points)-1) for t in range(4)]+[points[-1]]
    vertices = []
    faces = []
    width = 8
    for i, (point, radius) in enumerate(points):
        before = Vector(points[max(0, i-1)][0])
        after = Vector(points[min(len(points)-1, i+1)][0])
        axis = (after-before).normalized()
        across = axis.cross(Vector((0, 1, 0))).normalized()
        normal = across.cross(axis).normalized()
        for j in range(width):
            angle = j*tau/width
            vertices.append(Vector(point)+radius*(cos(angle)*across+.53*sin(angle)*normal))
    faces.append(tuple(reversed(range(width))))
    for i in range(len(points)-1):
        for j in range(width):
            a = i*width+j
            b = i*width+(j+1)%width
            faces.append((a,b,b+width,a+width))
    faces.append(tuple(range(len(vertices)-width,len(vertices))))
    obj = mesh(name,vertices,faces,paint)
    for face in obj.data.polygons:
        face.use_smooth = True
    return obj


def paint_set(key, hair, accent, uniform):
    tint = (.51, .27, .17) if key == "north" else (.69, .38, .26)
    return {
        "fabric": material("Ripstop jumpsuit", uniform, 0, .90),
        "elastic": material("Graphite webbing", (.036,.043,.048), 0, .78),
        "armor": material("Satin titanium", (.19,.215,.242), .68, .36),
        "edge": material("Brushed buckles", (.36,.40,.42), .62, .32),
        "accent": material("Dyed scarf and ceramic accents", accent, .08, .64),
        "signal": material("Status lamps", (1.0,.37,.056), .12, .32, 1.5),
        "skin": material("Warm skin", tint, 0.0, .57),
        "lips": material("Lip and ear tint", (.39,.133,.102), 0, .72),
        "hair": material("Hair base", hair, .04, .60),
        "strands": material("Hair strands", tuple(min(.92,c*1.27+.017) for c in hair), 0, .47),
        "eyes": material("Cool blue iris", (.10,.29,.46), .04, .32),
        "white": material("Eye whites", (.76,.74,.68), 0, .61),
        "black": material("Pupils and lining", (.011,.018,.025), 0, .7),
    }


class Operator:
    def __init__(self,key):
        self.key = key
        self.name,hair,accent,uniform,self.width,self.ponytail = OPERATORS[key]
        self.paint = paint_set(key,hair,accent,uniform)
        self.pieces = []

    def add(self, bone, obj):
        self.pieces.append((bone,obj))
        return obj

    def make_rig(self):
        data = bpy.data.armatures.new(self.name+" joints")
        rig = bpy.data.objects.new(self.name+" Rig",data)
        bpy.context.collection.objects.link(rig)
        bpy.context.view_layer.objects.active = rig
        rig.select_set(True)
        rig.show_in_front = True
        bpy.ops.object.mode_set(mode="EDIT")

        def bone(name,head,tail,parent=None):
            joint = data.edit_bones.new(name)
            joint.head,joint.tail = head,tail
            if parent:
                joint.parent = data.edit_bones[parent]
            return joint

        w = self.width
        bone("Root",(0,0,0),(0,0,.18))
        bone("Hips",(0,0,.88),(0,0,1.06),"Root")
        bone("Torso",(0,0,1.06),(0,0,1.42),"Hips")
        bone("Head",(0,0,1.44),(0,0,1.70),"Torso")
        for sign,side in [(-1,"L"),(1,"R")]:
            shoulder = (sign*.226*w,0,1.38)
            elbow = (sign*.287*w,-.048,1.145)
            wrist = (sign*.238*w,-.26,1.18)
            hip = (sign*.109*w,0,.87)
            knee = (sign*.122*w,-.022,.465)
            ankle = (sign*.137*w,.012,.103)
            bone("Upper"+side,shoulder,elbow,"Torso")
            bone("Lower"+side,elbow,wrist,"Upper"+side)
            bone("Hand"+side,wrist,(sign*.213*w,-.304,1.17),"Lower"+side)
            bone("Thigh"+side,hip,knee,"Hips")
            bone("Shin"+side,knee,ankle,"Thigh"+side)
            bone("Foot"+side,ankle,(sign*.137*w,-.142,.055),"Shin"+side)
        bone("Carbine",(.238*w,-.264,1.17),(.238*w,-.601,1.17),"HandR")
        bone("Muzzle",(.238*w,-.613,1.172),(.238*w,-.671,1.172),"Carbine")
        if self.ponytail:
            bone("Tail",(.024,.128,1.684),(.046,.192,1.433),"Head")
        bpy.ops.object.mode_set(mode="OBJECT")
        for joint in rig.pose.bones:
            joint.rotation_mode = "XYZ"
        self.rig = rig

    def gear(self):
        p = self.paint
        w = self.width
        for name,bone,rings,tint in [
            ("Fitted utility trousers","Hips",[(.79,.136*w,.100,0,.004),(.89,.179*w,.124,0,.014),(1.01,.150*w,.102,0,0)],"fabric"),
            ("Woven underlayer","Torso",[(.97,.141*w,.097,0,0),(1.07,.139*w,.094,0,.005),(1.22,.181*w,.112,0,.009),(1.37,.215*w,.108,0,.015),(1.439,.106*w,.080,0,.019)],"fabric"),
            ("Collar scarf low fold","Torso",[(1.383,.117*w,.100,0,.004),(1.413,.141*w,.112,0,.001),(1.46,.119*w,.092,0,.010)],"accent"),
            ("Utility webbing","Hips",[(.945,.161*w,.113,0,.006),(.999,.154*w,.109,0,.005)],"elastic"),
        ]:
            self.add(bone,taper(name,rings,p[tint]))
        self.add("Head",shaft("Neck",(0,.012,1.42),(0,.009,1.519),.057,p["skin"],.054,16))
        self.add("Torso",taper("Armored sternum",[(1.12,.081,.021,0,-.105),(1.20,.146*w,.033,0,-.101),(1.33,.172*w,.041,0,-.098),(1.378,.121*w,.025,0,-.086)],p["armor"]))
        for z in (1.096,1.13,1.163):
            self.add("Torso",slab("Flexible abdominal panel",(0,-.117,z),(.093*w,.023,.017),p["armor"],.006))
        self.add("Torso",slab("Chest IFF marker",(0,-.143,1.295),(.044,.010,.012),p["signal"],.004))
        self.add("Hips",slab("Adjustable buckle",(0,-.119,.971),(.044,.015,.026),p["edge"],.005))
        self.add("Hips",slab("Buckle center",(0,-.135,.971),(.026,.004,.013),p["elastic"],.003))
        self.add("Torso",strand("Draped scarf corner",[
            ((.076,-.083,1.437),.049),((.101,-.121,1.379),.059),((.063,-.148,1.326),.026),
        ],p["accent"]))
        if self.key in ("amber","north"):
            self.add("Torso",slab("Field pack",(0,.139,1.221),(.152*w,.063,.178),p["fabric"],.024))
            self.add("Torso",slab("Upper pack lid",(0,.201,1.310),(.144*w,.024,.068),p["elastic"],.016))
            self.add("Torso",slab("Pack pouch",(0,.212,1.153),(.103,.034,.070),p["fabric"],.013))
            self.add("Torso",slab("Rear marker lamp",(0,.236,1.308),(.053,.007,.014),p["signal"],.004))
        for sign,side in [(-1,"L"),(1,"R")]:
            shoulder = sign*.226*w
            hip = sign*.109*w
            knee = sign*.122*w
            foot = sign*.137*w
            wrist = sign*.238*w
            self.add("Torso",slab("Shoulder harness",(sign*.118*w,-.103,1.274),(.026,.024,.132),p["elastic"],.008))
            self.add("Torso",slab("Harness cam buckle",(sign*.119*w,-.134,1.313),(.026,.009,.020),p["edge"],.004))
            self.add("Hips",slab("Field utility pouch",(sign*.162*w,-.016,.94),(.046,.071,.075),p["fabric"],.012))
            self.add("Hips",slab("Pouch flap",(sign*.168*w,-.080,.966),(.043,.013,.039),p["elastic"],.009))
            self.add("Hips",slab("Pouch stud",(sign*.169*w,-.096,.945),(.013,.005,.010),p["edge"],.003))
            self.add("Upper"+side,shaft("Bound sleeve",(shoulder,0,1.375),(sign*.285*w,-.045,1.157),.069,p["fabric"],.046,16))
            pauldron = self.add("Upper"+side,shell("Beveled shoulder armor",[
                (1.33,.088,.096,shoulder,.000),(1.387,.093,.095,shoulder,.003),(1.433,.055,.061,shoulder*.96,.015),
            ],p["armor"],.010))
            pauldron.data.materials.append(p["edge"])
            pauldron.data.polygons[-1].material_index = 1
            self.add("Upper"+side,slab("Ceramic shoulder stripe",(shoulder,-.093,1.361),(.067,.012,.022),p["accent"],.008))
            self.add("Lower"+side,lens("Elbow pad",(sign*.282*w,-.046,1.152),(.052,.054,.050),p["elastic"]))
            self.add("Lower"+side,shaft("Forearm liner",(sign*.282*w,-.050,1.151),(wrist,-.254,1.181),.049,p["skin"],.031,16))
            self.add("Lower"+side,shaft("Wrist guard",(sign*.260*w,-.158,1.168),(wrist,-.253,1.180),.051,p["armor"],.043,8))
            self.add("Lower"+side,shaft("Wrist guard collar",(wrist,-.235,1.178),(wrist,-.253,1.179),.045,p["accent"],.043,12))
            self.add("Hand"+side,lens("Padded glove",(wrist,-.274,1.174),(.042,.055,.037),p["elastic"]))
            for i in range(4):
                self.add("Hand"+side,lens("Glove knuckle",(wrist-.027+i*.017,-.303,1.164),(.010,.025,.014),p["armor"]))
            self.add("Thigh"+side,taper("Trouser upper leg",[
                (.44,.070,.072,knee,-.022),(.54,.085,.085,knee,-.005),(.68,.096*w,.096,hip,.004),(.881,.104*w,.108,hip,.016),
            ],p["fabric"]))
            self.add("Thigh"+side,slab("Cargo pocket",(sign*.172*w,-.021,.698),(.050,.072,.091),p["elastic"],.013))
            self.add("Thigh"+side,slab("Cargo stripe",(sign*.164*w,-.094,.717),(.050,.017,.028),p["accent"],.006))
            self.add("Shin"+side,taper("Tapered boot shaft",[
                (.096,.065,.067,foot,.013),(.203,.072,.072,foot,.009),(.354,.082,.082,knee,.018),(.466,.071,.072,knee,-.015),
            ],p["fabric"]))
            self.add("Shin"+side,shell("Floating armor knee",[
                (.362,.058,.024,knee,-.063),(.425,.083,.044,knee,-.082),(.494,.071,.024,knee,-.073),
            ],p["armor"],.009))
            self.add("Shin"+side,slab("Knee accent",(knee,-.112,.428),(.045,.010,.012),p["accent"],.006))
            self.add("Shin"+side,slab("Shin greave",(foot,-.061,.268),(.052,.031,.105),p["armor"],.009))
            self.add("Foot"+side,slab("Boot traction sole",(foot,-.055,.032),(.082,.145,.028),p["elastic"],.009))
            self.add("Foot"+side,taper("Boot body",[(.057,.081,.143,foot,-.05),(.103,.076,.131,foot,-.05),(.181,.059,.068,foot,.012)],p["fabric"]))
            self.add("Foot"+side,slab("Reinforced toe",(foot,-.152,.086),(.070,.052,.035),p["armor"],.012))
            self.add("Foot"+side,slab("Toe signal",(foot,-.202,.079),(.034,.006,.009),p["accent"],.003))

    def face(self):
        p = self.paint
        w = self.width
        self.add("Head",taper("Sculpted facial planes",[
            (1.482,.028,.024,0,-.044),(1.510,.055*w,.055,0,-.031),(1.548,.075*w,.077,0,-.006),
            (1.598,.079*w,.082,0,0),(1.654,.078*w,.084,0,.009),(1.698,.062*w,.068,0,.019),(1.720,.024,.031,0,.023),
        ],p["skin"]))
        self.add("Head",lens("Nose bridge",(0,-.081,1.578),(.016,.026,.034),p["skin"]))
        self.add("Head",lens("Nose tip",(0,-.102,1.556),(.018,.015,.012),p["skin"]))
        self.add("Head",lens("Lower lip",(0,-.082,1.525),(.028,.012,.006),p["lips"]))
        self.add("Head",lens("Mouth line",(0,-.091,1.529),(.025,.005,.0024),p["lips"]))
        for sign in (-1,1):
            x = sign*.037
            self.add("Head",lens("Outer ear",(sign*.077*w,.015,1.583),(.013,.024,.032),p["skin"]))
            self.add("Head",lens("Upper eye lining",(x,-.073,1.592),(.023,.009,.010),p["black"]))
            self.add("Head",lens("Eye white",(x,-.080,1.591),(.020,.006,.007),p["white"]))
            self.add("Head",lens("Iris",(x,-.086,1.591),(.008,.004,.007),p["eyes"]))
            self.add("Head",lens("Pupil",(x,-.089,1.592),(.0035,.0015,.0045),p["black"]))
            self.add("Head",strand("Sculpted brow",[
                ((x-sign*.018,-.077,1.613),.004),((x,-.084,1.620),.006),((x+sign*.018,-.071,1.613),.003),
            ],p["hair"]))
        if self.key == "north":
            self.add("Head",taper("Short beard",[(1.479,.025,.024,0,-.045),(1.502,.056,.051,0,-.037),(1.528,.066,.029,0,-.029)],p["hair"]))
            self.add("Head",lens("Mustache",(0,-.082,1.539),(.039,.011,.006),p["hair"]))
        self.add("Head",lens("Hair cap",(0,.031,1.669),(.088*w,.091,.074),p["hair"]))
        for i in range(8):
            x = -.081+i*.023
            left = x < .010
            self.add("Head",strand("Swept lock",[
                ((x,.074,1.690),.021),((x+.014,.019,1.741-abs(x)*.21),.031),
                ((x-.021 if left else x+.015,-.061,1.708),.025),
                ((x-.015 if left else x+.015,-.084,1.603+abs(x)*.95),.004),
            ],p["strands"] if i%3==0 else p["hair"]))
        if self.ponytail:
            self.add("Head",lens("Ponytail strap",(.022,.126,1.686),(.038,.037,.029),p["accent"]))
            for i in range(6):
                x = (.022 if self.key=="vega" else -.033)+(i-2.5)*.014
                self.add("Tail",strand("Ponytail sweep",[
                    ((.023,.134,1.692),.025),((x,.193,1.687),.032),((x+.012,.218,1.582),.027),
                    ((x-.012,.191,1.491),.019),((x+.003,.132,1.432+i*.010),.003),
                ],p["strands"] if i%2 else p["hair"]))
        elif self.key == "amber":
            self.add("Head",lens("Comms ear cup",(.091,.008,1.592),(.021,.038,.041),p["armor"]))
            self.add("Head",lens("Comms lamp",(.107,-.003,1.592),(.007,.021,.022),p["signal"]))

    def carbine(self):
        p = self.paint
        x = .238*self.width
        for name,center,size,tint in [
            ("Compact pulse chassis",(x,-.395,1.174),(.041,.115,.032),"armor"),
            ("Receiver and rail",(x,-.411,1.209),(.025,.083,.008),"edge"),
            ("Power cell",(x,-.419,1.13),(.031,.047,.036),"elastic"),
            ("Stock",(x,-.244,1.181),(.026,.035,.028),"fabric"),
            ("Pulse charge meter",(x+.039,-.414,1.184),(.006,.044,.011),"signal"),
        ]:
            self.add("Carbine",slab(name,center,size,p[tint],.006))
        self.add("Carbine",shaft("Shrouded emitter",(x,-.494,1.174),(x,-.611,1.174),.026,p["armor"],.018,10))
        self.add("Carbine",shaft("Emitter insulator",(x,-.571,1.174),(x,-.590,1.174),.023,p["accent"],.021,10))

    def skin_mesh(self):
        bpy.context.view_layer.update()
        graph = bpy.context.evaluated_depsgraph_get()
        bpy.ops.object.select_all(action="DESELECT")
        for joint,source in self.pieces:
            baked = bpy.data.meshes.new_from_object(source.evaluated_get(graph),depsgraph=graph)
            baked.transform(source.matrix_world)
            source.data = baked
            source.modifiers.clear()
            source.matrix_world.identity()
            group = source.vertex_groups.new(name=joint)
            group.add(list(range(len(baked.vertices))),1.0,"REPLACE")
            source.select_set(True)
        active = self.pieces[0][1]
        bpy.context.view_layer.objects.active = active
        bpy.ops.object.join()
        active.name = self.name+" skinned gear"
        active.parent = self.rig
        modifier = active.modifiers.new("Operator skeleton","ARMATURE")
        modifier.object = self.rig
        self.skin = active

    def action(self,name,frames,pose_at):
        action = bpy.data.actions.new(name)
        animation = self.rig.animation_data
        animation.action = action
        for frame,value in frames:
            rotations,translation = pose_at(value)
            for joint in self.rig.pose.bones:
                joint.rotation_euler = rotations.get(joint.name,(0,0,0))
                joint.location = translation if joint.name == "Hips" else (0,0,0)
                joint.keyframe_insert(data_path="rotation_euler",frame=frame,group=joint.name)
                if joint.name == "Hips":
                    joint.keyframe_insert(data_path="location",frame=frame,group=joint.name)
        track = animation.nla_tracks.new()
        track.name = name
        track.strips.new(name,1,action)
        track.mute = True
        animation.action = None
        return action

    def animate(self):
        self.rig.animation_data_create()

        def idle(t):
            return {"Torso":(.021*sin(t),.024*sin(t),-.012*cos(t)),
                    "Head":(-.015*sin(t),-.038*sin(t),.013*cos(t)),
                    "LowerR":(-.018*sin(t),0,0),"Tail":(.033*sin(t),0,.04*cos(t))},(0,.009*sin(t),0)

        def run(t):
            a = sin(t)
            b = cos(t)
            return {"Torso":(-.12,.10*a,.07*b),"Head":(.10,-.07*a,-.03*b),
                    "ThighL":(.62*a,0,.03),"ThighR":(-.62*a,0,-.03),
                    "ShinL":(-.10-.76*max(0,-a),0,0),"ShinR":(-.10-.76*max(0,a),0,0),
                    "FootL":(.30*b,0,0),"FootR":(-.30*b,0,0),
                    "UpperL":(-.31*a,-.11,.08),"UpperR":(.09*a,0,-.04),
                    "Tail":(.12+.22*b,0,.15*a)},(0,-.050+.052*abs(b),0)

        def fire(t):
            return {"Torso":(-.056*t,0,-.033*t),"UpperR":(-.12*t,0,0),
                    "LowerR":(.10*t,0,.024*t),"Carbine":(.051*t,0,0),"Head":(.021*t,0,0)},(0,0,0)

        def impact(t):
            return {"Torso":(.18*t,-.14*t,-.15*t),"Head":(.19*t,0,.19*t),
                    "UpperR":(.28*t,0,.12*t),"UpperL":(.23*t,.1*t,-.19*t),"Tail":(.24*t,0,.08*t)},(0,-.013*t,0)

        def fall(t):
            return {"Hips":(-1.14*t,0,.23*t),"Torso":(-.18*t,0,.17*t),
                    "ThighL":(.55*t,0,.10*t),"ThighR":(.30*t,0,-.12*t),
                    "ShinL":(-.60*t,0,0),"ShinR":(-.40*t,0,0),
                    "UpperL":(.51*t,0,-.27*t),"UpperR":(.31*t,0,.31*t),"Head":(.28*t,0,0)},(0,-.69*t,.16*t)

        self.idle_action = self.action("Idle",[(1+i*18,i*tau/4) for i in range(5)],idle)
        self.action("Run",[(1+i*3,i*tau/8) for i in range(9)],run)
        self.action("Fire",[(1,0),(3,1),(6,.27),(10,0)],fire)
        self.action("Hit",[(1,0),(4,1),(9,.36),(15,0)],impact)
        self.action("Fall",[(1,0),(7,.22),(15,.68),(25,1),(30,1)],fall)

    def export(self, directory):
        scene = bpy.context.scene
        scene.render.fps = 30
        scene.frame_start,scene.frame_end = 1,73
        self.make_rig()
        self.gear()
        self.face()
        self.carbine()
        self.skin_mesh()
        self.animate()
        self.rig.animation_data.action = self.idle_action
        scene.frame_set(1)
        bpy.ops.object.select_all(action="DESELECT")
        self.skin.select_set(True)
        self.rig.select_set(True)
        bpy.context.view_layer.objects.active = self.rig
        bpy.ops.wm.save_as_mainfile(filepath=str(directory/(self.key+".blend")))
        self.rig.animation_data.action = None
        for track in self.rig.animation_data.nla_tracks:
            track.mute = False
        if "FINISHED" not in bpy.ops.export_scene.gltf(
            filepath=str(directory/(self.key+".glb")),export_format="GLB",use_selection=True,
            export_animations=True,export_animation_mode="NLA_TRACKS",
        ):
            raise RuntimeError("Could not export "+self.name)


def generate(reset, directory):
    for key in OPERATORS:
        reset()
        Operator(key).export(Path(directory))
