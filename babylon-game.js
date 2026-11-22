(function(){
'use strict';
const B=window.BABYLON;
const canvas=document.getElementById('renderCanvas'),status=document.getElementById('status');
const engine=new B.Engine(canvas,true,{preserveDrawingBuffer:false,stencil:true,antialias:true,adaptToDeviceRatio:true});
engine.setHardwareScalingLevel(Math.max(1,Math.min(1.5,window.devicePixelRatio/1.5)));
const scene=new B.Scene(engine);scene.clearColor=new B.Color4(.55,.69,.77,1);
scene.collisionsEnabled=true;
const camera=new B.ArcRotateCamera('camera',-Math.PI/2,1.02,20,new B.Vector3(0,1,0),scene);camera.attachControl(canvas,false);camera.inputs.clear();camera.lowerRadiusLimit=14;camera.upperRadiusLimit=23;
const light=new B.HemisphericLight('ambient',new B.Vector3(0,1,0),scene);light.intensity=.9;
const sun=new B.DirectionalLight('sun',new B.Vector3(-.5,-1,.35),scene);sun.position=new B.Vector3(12,23,-10);sun.intensity=1.9;
const shadow=new B.ShadowGenerator(1024,sun);shadow.useBlurExponentialShadowMap=true;shadow.blurKernel=12;
function material(name,hex,rough=1){const m=new B.PBRMaterial(name,scene);m.albedoColor=B.Color3.FromHexString(hex);m.metallic=0;m.roughness=rough;return m}
const sand=material('sand','#b4a28b'),stone=material('stone','#d0b99b'),dark=material('dark','#454d50'),blue=material('blue','#334f5d'),enemyMat=material('enemy','#665044'),metal=material('metal','#3b4145',.55);
function box(name,w,h,d,x,y,z,mat,collision=false){const o=B.MeshBuilder.CreateBox(name,{width:w,height:h,depth:d},scene);o.position.set(x,y,z);o.material=mat;o.receiveShadows=true;o.checkCollisions=collision;if(collision)solid.push({x,z,w,d});return o}
const solid=[];
box('ground',42,.4,44,0,-.22,0,sand);
for(const z of [-21.7,21.7]){box('wall',42,6,.6,0,3,z,stone);for(let x=-17;x<19;x+=7){box('window',3,2,.07,x,3.4,z+(z>0?-.35:.35),dark)}}
for(const x of [-20.7,20.7]){box('wall',.6,6,44,x,3,0,stone);for(let z=-16;z<19;z+=8)box('alcove',.07,2.1,3,x+(x>0?-.35:.35),3.5,z,dark)}
for(let i=0;i<10;i++){const x=-14+i%5*7,z=-12+Math.floor(i/5)*20;box('cover',2.8,1.6,2.2,x,.8,z,stone,true);box('cover top',3,.16,2.4,x,1.65,z,dark)}
function agent(name,x,z,hostile=false){const root=new B.TransformNode(name,scene);root.position.set(x,0,z);const armor=hostile?enemyMat:blue;
const torso=B.MeshBuilder.CreateCapsule(name+' torso',{radius:.38,height:1.18,tessellation:12},scene);torso.parent=root;torso.position.y=1.23;torso.material=armor;shadow.addShadowCaster(torso);
const head=B.MeshBuilder.CreateSphere(name+' helmet',{diameter:.65,segments:12},scene);head.parent=root;head.position.y=2.12;head.scaling.y=.78;head.material=dark;shadow.addShadowCaster(head);
const visor=box(name+' visor',.5,.15,.12,0,0,0,metal);visor.parent=root;visor.position.set(0,2.1,-.31);
for(const side of [-1,1]){const leg=box(name+' leg',.26,.72,.29,0,0,0,armor);leg.parent=root;leg.position.set(side*.22,.4,0);const arm=box(name+' arm',.23,.75,.26,0,0,0,armor);arm.parent=root;arm.position.set(side*.49,1.34,-.1)}
const rifle=box(name+' rifle',.18,.18,1.15,0,0,0,metal);rifle.parent=root;rifle.position.set(.42,1.42,-.63);
return {root,hp:hostile?3:100,cool:0}}
const player=agent('operator',0,12);const enemies=[];let kills=0,stage=Number(localStorage.getItem('babylon_stage')||1),mode=localStorage.getItem('babylon_mode')||'campaign',playing=false,over=false;
const objective=()=>mode==='endless'?Infinity:12+(stage-1)*6;
const killsEl=document.getElementById('kills'),healthEl=document.getElementById('health'),objectiveEl=document.getElementById('objective');
function updateHUD(){killsEl.textContent=kills+' / '+(Number.isFinite(objective())?objective():'∞');healthEl.textContent=Math.ceil(player.hp);objectiveEl.textContent='ОПЕРАЦИЯ '+stage+' · '+(mode==='endless'?'БЕСКОНЕЧНЫЙ РЕЖИМ':'ЗАЧИСТКА СЕКТОРА')}
function canMove(x,z){return Math.abs(x)<19.8&&Math.abs(z)<20.8&&!solid.some(o=>Math.abs(x-o.x)<o.w/2+.6&&Math.abs(z-o.z)<o.d/2+.6)}
function spawn(){for(let t=0;t<60;t++){const x=(Math.random()-.5)*34,z=(Math.random()-.5)*28-4;if(canMove(x,z)&&Math.hypot(x-player.root.position.x,z-player.root.position.z)>9){enemies.push(agent('hostile',x,z,true));return}}}
for(let i=0;i<5;i++)spawn();
const overlay=document.getElementById('overlay'),panel=document.getElementById('panel');
function button(text,fn,primary=false){const b=document.createElement('button');b.textContent=text;b.className=primary?'primary':'';b.onclick=fn;panel.append(b)}
function menu(){playing=false;overlay.hidden=false;panel.replaceChildren();const h=document.createElement('h1');h.textContent='ОТПУСК / TACTICAL';panel.append(h);const p=document.createElement('p');p.textContent='BABYLON.JS · ОПЕРАЦИЯ '+stage+' · ТАКТИЧЕСКИЙ ШУТЕР';panel.append(p);
button('▶ ПРОДОЛЖИТЬ КАМПАНИЮ',()=>{localStorage.setItem('babylon_mode','campaign');if(mode!=='campaign')location.reload();start()},true);
button('∞ БЕСКОНЕЧНЫЙ РЕЖИМ',()=>{localStorage.setItem('babylon_mode','endless');if(mode!=='endless')location.reload();start()});
button('↻ НОВАЯ КАМПАНИЯ',()=>{localStorage.setItem('babylon_stage','1');localStorage.setItem('babylon_mode','campaign');location.reload()});
const note=document.createElement('p');note.textContent='Брифинг: сектор захвачен. Зачистите территорию и переходите к следующей операции. Управление: левый виртуальный джойстик, автоматический огонь.';panel.append(note)}
function start(){overlay.hidden=true;playing=true;status.textContent='ОПЕРАЦИЯ НАЧАТА'}
function result(win){over=true;playing=false;overlay.hidden=false;panel.replaceChildren();const h=document.createElement('h1');h.textContent=win?'МИССИЯ ВЫПОЛНЕНА':'ОПЕРАЦИЯ ПРОВАЛЕНА';panel.append(h);const p=document.createElement('p');p.textContent='УСТРАНЕНО: '+kills+' · ЭТАП '+stage;panel.append(p);if(win&&mode!=='endless')button('СЛЕДУЮЩАЯ ОПЕРАЦИЯ →',()=>{localStorage.setItem('babylon_stage',String(stage+1));location.reload()},true);button('ПОВТОРИТЬ',()=>location.reload());button('ГЛАВНОЕ МЕНЮ',()=>{localStorage.setItem('babylon_showmenu','1');location.reload()})}
document.getElementById('pause').onclick=()=>{if(over)return;if(playing)menu();else start()};
const stick=document.getElementById('stick'),knob=document.getElementById('knob'),move={x:0,z:0};let pointer=null;
function drag(e){const r=stick.getBoundingClientRect(),x=e.clientX-r.left-r.width/2,y=e.clientY-r.top-r.height/2,l=Math.max(1,Math.hypot(x,y)),m=Math.min(1,l/(r.width*.37));move.x=x/l*m;move.z=y/l*m;knob.style.transform='translate('+move.x*38+'px,'+move.z*38+'px)'}
stick.onpointerdown=e=>{if(!playing)return;pointer=e.pointerId;stick.setPointerCapture(pointer);drag(e)};stick.onpointermove=e=>{if(e.pointerId===pointer)drag(e)};function release(e){if(e.pointerId!==pointer)return;pointer=null;move.x=move.z=0;knob.style.transform=''}stick.onpointerup=release;stick.onpointercancel=release;
const keys=new Set();window.onkeydown=e=>keys.add(e.key.toLowerCase());window.onkeyup=e=>keys.delete(e.key.toLowerCase());
let last=performance.now(),shot=0;const projectiles=[];
function fire(from,to){const mesh=B.MeshBuilder.CreateSphere('shot',{diameter:.12,segments:6},scene);mesh.material=material('tracer','#f5b75c');mesh.position.copyFrom(from);const v=to.subtract(from).normalize();projectiles.push({mesh,v,ttl:1})}
engine.runRenderLoop(()=>{const now=performance.now(),dt=Math.min(.05,(now-last)/1000);last=now;
if(playing){let x=move.x+(keys.has('d')?1:0)-(keys.has('a')?1:0),z=move.z+(keys.has('s')?1:0)-(keys.has('w')?1:0),len=Math.hypot(x,z);if(len>1){x/=len;z/=len}
const p=player.root.position;if(canMove(p.x+x*dt*5,p.z))p.x+=x*dt*5;if(canMove(p.x,p.z+z*dt*5))p.z+=z*dt*5;
let closest=null,dist=100;for(const e of enemies){const ep=e.root.position,d=Math.hypot(ep.x-p.x,ep.z-p.z);if(d<dist){dist=d;closest=e}if(d>1.8){const vx=(p.x-ep.x)/d,vz=(p.z-ep.z)/d;if(canMove(ep.x+vx*dt*1.65,ep.z+vz*dt*1.65))ep.x+=vx*dt*1.65;if(canMove(ep.x,ep.z+vz*dt*1.65))ep.z+=vz*dt*1.65}e.root.rotation.y=Math.atan2(p.x-ep.x,-(p.z-ep.z));e.cool-=dt;if(d<2&&e.cool<=0){player.hp-=8;e.cool=1.4;updateHUD();if(player.hp<=0)result(false)}}
shot-=dt;if(closest&&dist<22&&shot<=0){shot=.3;player.root.rotation.y=Math.atan2(closest.root.position.x-p.x,-(closest.root.position.z-p.z));fire(p.add(new B.Vector3(0,1.4,0)),closest.root.position.add(new B.Vector3(0,1.3,0)))}
for(let i=projectiles.length-1;i>=0;i--){const b=projectiles[i],prev=b.mesh.position.clone();b.mesh.position.addInPlace(b.v.scale(dt*27));b.ttl-=dt;const hit=enemies.find(e=>B.Vector3.DistanceSquared(e.root.position.add(new B.Vector3(0,1.3,0)),b.mesh.position)<1.1);if(hit){hit.hp--;b.ttl=0;if(hit.hp<=0){hit.root.getChildMeshes().forEach(m=>m.dispose());hit.root.dispose();enemies.splice(enemies.indexOf(hit),1);kills++;updateHUD();if(kills>=objective())result(true);else if(enemies.length<5)spawn()}}if(b.ttl<=0){b.mesh.dispose();projectiles.splice(i,1)}}
camera.target=B.Vector3.Lerp(camera.target,p.add(new B.Vector3(0,1,0)),Math.min(1,dt*5));camera.alpha=-Math.PI/2;camera.beta=1.02}
scene.render()});
window.addEventListener('resize',()=>engine.resize());updateHUD();menu();status.textContent='BABYLON.JS · ГОТОВО';
})();