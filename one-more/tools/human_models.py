"""Original reference-inspired operators and their mobile rigs."""
from functools import lru_cache
from math import atan2, cos, exp, pi, sin, sqrt, tau
from pathlib import Path

import bpy
from mathutils import Vector

from combat_models import lens, material, mesh, shaft, shell, slab


OPERATORS = {
    "vega": ("Vega", (.38, .42, .49), (.62, .213, .067), (.072, .093, .127), 1.0, True),
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


def sleeve(name, start, end, profile, paint):
    """Smooth cross-sections perpendicular to the arm, with elbow and cuff folds."""
    start, end = Vector(start), Vector(end)
    axis = (end-start).normalized()
    width = axis.cross(Vector((1,0,0))).normalized()
    depth = axis.cross(width)
    vertices = [start.lerp(end,t)+rx*u*width+ry*v*depth for t,rx,ry in profile for u,v in ROUND]
    sides = len(ROUND)
    faces = [tuple(reversed(range(sides)))]
    for offset in range(0,len(vertices)-sides,sides):
        for i in range(sides):
            a, b = offset+i, offset+(i+1)%sides
            faces.append((a,b,b+sides,a+sides))
    faces.append(tuple(range(len(vertices)-sides,len(vertices))))
    obj = mesh(name,vertices,faces,paint)
    for face in list(obj.data.polygons)[1:-1]:
        face.use_smooth = True
    return obj


@lru_cache(maxsize=1)
def face_topology():
    points, texcoords, faces = [], [], []
    source = Path(__file__).parent / "model_source" / "operator_head.obj"
    for line in source.read_text().splitlines():
        kind, *values = line.split()
        if kind == "v":
            points.append(tuple(map(float,values)))
        elif kind == "vt":
            texcoords.append(tuple(map(float,values)))
        elif kind == "f":
            faces.append(tuple(tuple(int(index)-1 for index in corner.split("/")) for corner in values))
    return points, texcoords, faces


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
    tint = {"vega": (.57,.32,.235), "fox": (.62,.337,.215),
            "amber": (.48,.267,.163), "north": (.39,.21,.128)}[key]
    return {
        "fabric": material("Ripstop jumpsuit", uniform, 0, .90),
        "elastic": material("Graphite webbing", (.036,.043,.048), 0, .78),
        "armor": material("Matte composite inserts", (.108,.130,.148), .28, .63),
        "edge": material("Brushed buckles", (.36,.40,.42), .62, .32),
        "accent": material("Dyed scarf and ceramic accents", accent, .08, .64),
        "signal": material("Status lamps", (1.0,.37,.056), .12, .32, 1.5),
        "skin": material("Warm skin", tint, 0.0, .65),
        "lips": material("Lip tint", (tint[0]*.74,tint[1]*.57,tint[2]*.65), 0, .68),
        "beard": material("Dark beard stubble", (.12,.071,.051), 0, .82),
        "hair": material("Hair base", hair, .04, .60),
        "strands": material("Hair strands", tuple(min(.92,c*1.14+.011) for c in hair), 0, .59),
        "eyes": material("Iris", (.084,.182,.22) if key in ("vega","amber") else (.095,.103,.039), 0, .32),
        "white": material("Sclera", (.52,.49,.45), 0, .51),
        "black": material("Pupils and lining", (.011,.018,.025), 0, .7),
    }


class Operator:
    def __init__(self,key):
        self.key = key
        self.name,hair,accent,uniform,self.width,self.ponytail = OPERATORS[key]
        self.paint = paint_set(key,hair,accent,uniform)
        self.pieces = []
        self.blends = {}

    def add(self, bone, obj):
        self.pieces.append((bone,obj))
        return obj

    def blend(self, obj, secondary, center, axis, half_width):
        self.blends[obj] = (secondary,Vector(center),Vector(axis).normalized(),half_width)

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
            leg = (bone("Thigh"+side,hip,knee,"Hips"),
                   bone("Shin"+side,knee,ankle,"Thigh"+side),
                   bone("Foot"+side,ankle,(sign*.137*w,-.142,.055),"Shin"+side))
            for joint in leg:
                joint.align_roll(Vector((0,1,0)))
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
        waist = .132 if self.ponytail else .147
        jacket = self.add("Hips",taper("Fitted field jacket and seat",[
            (.798,.147*w,.108,0,.012),(.850,.171*w,.116,0,.017),(.917,.168*w,.111,0,.014),
            (.965,.157*w,.109,0,.010),(1.014,(waist+.01)*w,.104,0,.009),
            (1.060,waist*w,.097,0,.011),(1.101,(waist+.006)*w,.099,0,.008),
            (1.151,.164*w,.111,0,.005),(1.218,.179*w,.127,0,.003),(1.290,.191*w,.123,0,.008),
            (1.347,.207*w,.105,0,.014),(1.382,.187*w,.093,0,.017),
            (1.410,.136*w,.078,0,.015),(1.435,.081*w,.058,0,.022),
        ],p["fabric"]))
        self.blend(jacket,"Torso",(0,0,1.061),(0,0,1),.073)
        self.add("Torso",taper("Folded scarf wrap",[
            (1.374,.097*w,.086,.007,-.009),(1.396,.107*w,.093,.005,-.010),
            (1.410,.093*w,.085,.002,-.003),(1.424,.104*w,.085,0,.001),
            (1.445,.089*w,.073,-.001,.009),(1.457,.080*w,.067,-.003,.015),
        ],p["accent"]))
        self.add("Hips",taper("Webbing belt",[
            (.947,.160*w,.112,0,.008),(.956,.162*w,.116,0,.008),(.988,.157*w,.114,0,.008),(.995,.155*w,.109,0,.008),
        ],p["elastic"]))
        self.add("Hips",slab("Adjustable buckle",(.008,-.111,.970),(.033,.012,.018),p["edge"],.007))
        self.add("Torso",strand("Scarf tail",[
            ((.056,-.070,1.434),.030),((.094,-.092,1.395),.036),((.102,-.125,1.350),.028),
            ((.076,-.136,1.310 if self.key == "north" else 1.330),.008),
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
            self.add("Torso",strand("Contoured harness",[
                ((sign*.157*w,.058,1.405),.022),((sign*.154*w,-.044,1.380),.024),
                ((sign*.120*w,-.111,1.298),.023),((sign*.108*w,-.107,1.202),.021),
                ((sign*.137*w,-.078,1.126),.018),
            ],p["elastic"]))
            self.add("Torso",slab("Harness buckle",(sign*.120*w,-.126,1.300),(.021,.008,.014),p["edge"],.004))
            if side == "L" or not self.ponytail:
                self.add("Hips",taper("Rounded canvas belt pouch",[
                    (.865,.025,.044,sign*.165*w,-.019),(.886,.043,.060,sign*.174*w,-.022),
                    (.950,.043,.064,sign*.174*w,-.023),(.978,.033,.052,sign*.168*w,-.023),
                ],p["elastic"]))

            shoulder_center = (shoulder*.89,.002,1.377)
            elbow = (sign*.285*w,-.050,1.153)
            forearm_end = (wrist,-.255,1.179)
            arm = self.add("Upper"+side,sleeve("Folded fabric sleeve",shoulder_center,elbow,[
                (-.12,.034,.046),(.08,.057,.066),(.24,.064,.061),(.53,.053,.055),(.74,.045,.048),
                (.83,.048,.052),(.91,.044,.046),(1.00,.047,.047),(1.08,.041,.042),
            ],p["fabric"]))
            self.blend(arm,"Lower"+side,elbow,Vector(elbow)-Vector(shoulder_center),.065)
            if side == "L" and self.key != "fox":
                self.add("Upper"+side,lens("Curved shoulder insert",(shoulder*1.025,-.007,1.385),(.060,.065,.027),p["armor"]))
            self.add("Upper"+side,strand("Sleeve identification tape",[
                ((shoulder*.94,-.052,1.355),.010),((shoulder*1.05,-.061,1.345),.012),
                ((shoulder*1.16,-.046,1.330),.010),
            ],p["accent"]))
            self.add("Lower"+side,sleeve("Tapered forearm",elbow,forearm_end,[
                (-.10,.040,.039),(.13,.046,.042),(.32,.043,.038),(.58,.037,.035),(1.0,.029,.029),
            ],p["skin"]))
            self.add("Lower"+side,sleeve("Fabric gauntlet",elbow,forearm_end,[
                (.60,.040,.037),(.69,.040,.037),(.90,.034,.034),(1.00,.034,.034),
            ],p["elastic"]))
            self.add("Hand"+side,lens("Gloved palm",(wrist,-.274,1.171),(.037,.048,.028),p["elastic"]))
            self.add("Hand"+side,lens("Thumb grip",(wrist-sign*.026,-.274,1.158),(.014,.025,.016),p["elastic"],segments=10,rings=6))
            for i in range(4):
                self.add("Hand"+side,lens("Curled finger",(wrist-.024+i*.0155,-.299,1.157+abs(i-1.7)*.003),(.008,.020,.013),p["elastic"],segments=10,rings=6))

            trousers = self.add("Thigh"+side,taper("Continuous cloth trousers",[
                (.090,.053,.058,foot,.013),(.194,.063,.063,foot,.012),(.238,.064,.067,foot,.015),
                (.318,.073,.077,knee,.020),(.375,.075,.071,knee,.012),(.413,.070,.074,knee,-.010),
                (.448,.073,.075,knee,-.024),(.480,.074,.077,knee,-.021),(.519,.078,.084,knee,-.003),
                (.571,.087,.091,knee,.010),(.654,.094*w,.102,hip,.014),(.754,.099*w,.106,hip,.024),
                (.828,.101*w,.104,hip,.022),(.877,.093*w,.096,hip,.015),
            ],p["fabric"]))
            self.blend(trousers,"Shin"+side,(0,0,.455),(0,0,-1),.068)
            if side == "R" or self.key == "fox":
                self.add("Thigh"+side,taper("Contoured cargo pocket",[
                    (.631,.020,.038,sign*.168*w,-.021),(.652,.033,.056,sign*.179*w,-.025),
                    (.726,.032,.062,sign*.176*w,-.027),(.747,.023,.053,sign*.168*w,-.025),
                ],p["elastic"]))
            for z,center in ((.761,hip),(.648,knee),(.566,knee)):
                self.add("Thigh"+side,strand("Tailored seam",[
                    ((center+sign*.071*w,-.039,z+.034),.0025),
                    ((center+sign*.086*w,-.041,z),.004),
                    ((center+sign*.075*w,-.035,z-.019),.0025),
                ],p["elastic"]))
            knee_pad = self.add("Thigh"+side,lens("Soft-shell knee reinforcement",(knee,-.082,.437),(.046,.026,.061),p["armor"]))
            self.blend(knee_pad,"Shin"+side,(0,0,.455),(0,0,-1),.068)
            self.add("Foot"+side,taper("Boot traction sole",[
                (.012,.053,.110,foot,-.039),(.021,.059,.118,foot,-.044),(.044,.060,.119,foot,-.045),(.050,.058,.114,foot,-.042),
            ],p["elastic"]))
            self.add("Foot"+side,taper("Leather boot upper",[
                (.045,.058,.116,foot,-.043),(.069,.057,.115,foot,-.042),(.093,.054,.100,foot,-.029),
                (.123,.049,.078,foot,-.012),(.163,.049,.061,foot,.006),(.182,.050,.058,foot,.010),
            ],p["fabric"]))
            for z in (.107,.124,.142):
                self.add("Foot"+side,strand("Boot lacing",[
                    ((foot-.021,-.092+(z-.107)*.50,z-.007),.0038),
                    ((foot+.001,-.107+(z-.107)*.53,z),.0042),
                    ((foot+.021,-.092+(z-.107)*.50,z+.008),.0038),
                ],p["accent"]))

    def face(self):
        p = self.paint
        points, texcoords, faces = face_topology()
        width, jaw, nose = {
            "vega": (.99,-.10,-.045), "fox": (.965,-.045,.025),
            "amber": (1.035,.085,.055), "north": (1.07,.13,.090),
        }[self.key]

        def head_shape(point):
            x, y, z = point
            jaw_shape = exp(-((y-6.54)/.43)**2) * min(1,max(0,z-.50))
            bridge = exp(-(x/.19)**2-((y-7.00)/.35)**2) * min(1,max(0,z-1.05))
            lid = exp(-((abs(x)-.31)/.13)**2-((y-7.29)/.11)**2-((z-1.40)/.13)**2)
            height = 1.719+(y-8.491)*.102 - max(0,6.22-y)*.095 + .038*(y-7.29)*lid
            return (x*.101*width*(1+jaw*jaw_shape),-(z-.48+nose*bridge)*.100,height)

        head = self.add("Head",mesh("Anatomical head and neck",
            [head_shape(point) for point in points], [tuple(index for index,_ in face) for face in faces],p["skin"]))
        for paint in (p["lips"],p["beard"],p["hair"]):
            head.data.materials.append(paint)
        uv = head.data.uv_layers.active
        for face, source_face in zip(head.data.polygons,faces):
            face.use_smooth = True
            for loop, (_, uv_index) in zip(face.loop_indices,source_face):
                uv.data[loop].uv = texcoords[uv_index]
            x, y, z = (sum(points[index][axis] for index,_ in source_face)/len(source_face) for axis in range(3))
            if abs(x) < .252 and ((y-6.615)/.12)**2+(x/.29)**2 < 1 and z > 1.45:
                face.material_index = 1
            elif self.key == "north" and 6.18+(1.2-z)*.25 < y < 6.465+abs(x)*.80 and z > .59:
                face.material_index = 2
            elif y > 7.83+max(0,z-.85)*.33-max(0,.44-z)*1.10:
                face.material_index = 3

        for sign in (-1,1):
            x, y, z = head_shape((sign*.322,7.29,1.249))
            self.add("Head",lens("Eyeball",(x,y,z),(.0144,.0139,.0130),p["white"],segments=16,rings=8))
            self.add("Head",lens("Iris",(x-sign*.001,y-.0133,z),(.0053,.0014,.0050),p["eyes"],segments=12,rings=6))
            self.add("Head",lens("Pupil",(x-sign*.001,y-.0146,z),(.0024,.0006,.0025),p["black"],segments=10,rings=6))
            self.add("Head",strand("Eyebrow",[
                (head_shape((sign*.147,7.455,1.510)),.0029),
                (head_shape((sign*.303,7.500,1.458)),.0040 if not self.ponytail else .0032),
                (head_shape((sign*.496,7.427,1.323)),.0014),
            ],p["hair"]))
        self.add("Head",lens("Shaped roots",(0,.032,1.670),(.078*width,.090,.064),p["hair"]))
        side_part = {"vega": .037,"fox": -.015,"amber": -.053,"north": .047}[self.key]
        for i in range(11):
            x = -.074+i*.0147
            sweep = (-.051 if self.ponytail else -.039) if x < side_part else .035
            sway = sin(i*2.19)*.008
            height = 1.738-abs(x)*.31+sin(i*.82)*.009
            temple = x*.76+sweep+sway
            tail = 1.655-max(0,abs(temple)-.03)*(.78 if self.ponytail else .34)
            self.add("Head",strand("Swept lock",[
                ((x*.63,.067,1.698-abs(x)*.28),.014),
                ((x*.78+.23*sweep,.018,height),.021+sway*.38),
                ((x*.84+.53*sweep,-.036,height-.015),.018),
                ((temple+.013*sin(i),-.066+abs(temple)*.19,tail+.017),.010),
                ((temple,-.072+abs(temple)*.28,tail),.0011),
            ],p["strands"] if i%4==0 else p["hair"]))
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
            if source in self.blends:
                secondary, midpoint, axis, falloff = self.blends[source]
                other = source.vertex_groups.new(name=secondary)
                for vertex in baked.vertices:
                    distance = (vertex.co-midpoint).dot(axis)
                    bend = max(0.0,min(1.0,.5+distance/(2*falloff)))
                    bend = bend*bend*(3-2*bend)
                    if bend < 1:
                        group.add([vertex.index],1-bend,"REPLACE")
                    if bend > 0:
                        other.add([vertex.index],bend,"REPLACE")
            else:
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
            breath = sin(t)
            return {"Hips":(0,.06,-.032),"Torso":(.015+.028*breath,-.11+.030*breath,-.016*cos(t)),
                    "Head":(-.013-.019*breath,.025-.052*breath,.019*cos(t)),
                    "UpperL":(-.09,.095,.07),"LowerL":(.44+.018*breath,0,-.04),
                    "UpperR":(.012+.02*breath,0,-.02),"LowerR":(-.018*breath,0,0),
                    "Tail":(.047*breath,0,.045*cos(t))},(0,.006*breath,0)

        def stride(t,running):
            phase = t/tau
            wave = sin(t)
            chest = .107 if running else .040
            pelvis = (-.074 if running else -.029)+(.018 if running else .010)*cos(t*2)
            rotation = {
                "Torso":(chest,-.055+.086*wave,.042*cos(t)), "Head":(-chest*.76,.038-.065*wave,-.030*cos(t)),
                "UpperL":(-.08-(.40 if running else .22)*wave,-.045,.056), "UpperR":(.044*wave,0,-.025),
                "LowerL":(.34+.23*sin(t+.40),0,-.025), "LowerR":(-.035*wave,0,0),
                "Tail":(.102+.22*cos(t-.30),0,.112*sin(t-.44)),
            }
            for side,start in [("L",phase),("R",phase+.5)]:
                thigh,shin,foot = self.leg_pose(side,start%1.0,pelvis,running)
                rotation["Thigh"+side] = (thigh,0,0)
                rotation["Shin"+side] = (shin,0,0)
                rotation["Foot"+side] = (foot,0,0)
            return rotation,(0,pelvis,0)

        def fire(t):
            return {"Torso":(-.056*t,0,-.033*t),"UpperR":(-.12*t,0,0),
                    "LowerR":(.10*t,0,.024*t),"Carbine":(.051*t,0,0),"Head":(.021*t,0,0)},(0,0,0)

        def impact(t):
            return {"Torso":(.18*t,-.14*t,-.15*t),"Head":(.19*t,0,.19*t),
                    "UpperR":(.28*t,0,.12*t),"UpperL":(.23*t,.1*t,-.19*t),"Tail":(.24*t,0,.08*t)},(0,-.013*t,0)

        def fall(t):
            return {"Hips":(-1.14*t,0,.23*t),"Torso":(-.18*t,0,.17*t),
                    "ThighL":(.55*t,0,.10*t),"ThighR":(.30*t,0,-.12*t),
                    "ShinL":(.60*t,0,0),"ShinR":(.40*t,0,0),
                    "UpperL":(.51*t,0,-.27*t),"UpperR":(.31*t,0,.31*t),"Head":(.28*t,0,0)},(0,-.69*t,.16*t)

        self.idle_action = self.action("Idle",[(1+i*18,i*tau/4) for i in range(5)],idle)
        self.walk_action = self.action("Walk",[(1+i*2,i*tau/16) for i in range(17)],lambda t: stride(t,False))
        self.run_action = self.action("Run",[(1+i,i*tau/24) for i in range(25)],lambda t: stride(t,True))
        self.action("Fire",[(1,0),(3,1),(6,.27),(10,0)],fire)
        self.action("Hit",[(1,0),(4,1),(9,.36),(15,0)],impact)
        self.action("Fall",[(1,0),(7,.22),(15,.68),(25,1),(30,1)],fall)

    def leg_pose(self,side,phase,pelvis,running):
        thigh = self.rig.data.bones["Thigh"+side]
        shin = self.rig.data.bones["Shin"+side]
        hip = Vector((thigh.head_local.y,thigh.head_local.z+pelvis))
        knee_rest = thigh.tail_local-thigh.head_local
        shin_rest = shin.tail_local-shin.head_local
        upper = Vector((knee_rest.y,knee_rest.z)).length
        lower = Vector((shin_rest.y,shin_rest.z)).length
        contact = .50 if running else .64
        reach = .28 if running else .182
        if phase < contact:
            advance = phase/contact
            y = -reach+2*reach*advance
            z = .109+.042*max(0.0,(advance-.70)/.30)**2
            pitch = .29*max(0.0,(advance-.59)/.41)**2
        else:
            swing = (phase-contact)/(1-contact)
            travel = swing*swing*(3-2*swing)
            y = reach-2*reach*travel
            z = .111+(.205 if running else .120)*sin(pi*swing)
            pitch = (.26*cos(swing*pi)) * sin(swing*pi)
        delta = Vector((y,z))-hip
        direction = delta.normalized()
        distance = min(delta.length,upper+lower-.002)
        forward = Vector((direction.y,-direction.x))
        projection = (upper*upper-lower*lower+distance*distance)/(2*distance)
        knee = direction*projection+forward*sqrt(max(0.000001,upper*upper-projection*projection))
        calf = direction*distance-knee
        thigh_angle = atan2(knee.x,-knee.y)-atan2(knee_rest.y,-knee_rest.z)
        shin_angle = atan2(calf.x,-calf.y)-atan2(shin_rest.y,-shin_rest.z)
        return thigh_angle,shin_angle-thigh_angle,pitch-shin_angle

    def validate_stride(self):
        animation = self.rig.animation_data
        for action,last in [(self.walk_action,33),(self.run_action,25)]:
            animation.action = action
            for frame in range(1,last+1):
                bpy.context.scene.frame_set(frame)
                lowest = 10.0
                for side in ("L","R"):
                    thigh = self.rig.pose.bones["Thigh"+side]
                    shin = self.rig.pose.bones["Shin"+side]
                    foot = self.rig.pose.bones["Foot"+side]
                    hip = Vector((thigh.head.y,thigh.head.z))
                    knee = Vector((shin.head.y,shin.head.z))
                    ankle = Vector((foot.head.y,foot.head.z))
                    direction = (ankle-hip).normalized()
                    assert (knee-hip).dot(Vector((direction.y,-direction.x))) > .008, (self.name,action.name,frame,side)
                    toe = Vector((foot.bone.head_local.x,-.169,.013))
                    sole = foot.matrix @ foot.bone.matrix_local.inverted() @ toe
                    lowest = min(lowest,sole.z)
                assert -.075 < lowest < .105, (self.name,action.name,frame,lowest)
        animation.action = None
        print(f"{self.name}: validated knee bend and foot height across walk and run")

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
        self.validate_stride()
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
        for action in list(bpy.data.actions):
            if action.users == 0:
                bpy.data.actions.remove(action)
        Operator(key).export(Path(directory))
