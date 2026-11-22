(function(){
'use strict';
const B=window.BABYLON;
const canvas=document.getElementById('renderCanvas'),status=document.getElementById('status');
const engine=new B.Engine(canvas,true,{preserveDrawingBuffer:false,stencil:true,antialias:true,adaptToDeviceRatio:true});
engine.setHardwareScalingLevel(Math.max(1,Math.min(1.5,window.devicePixelRatio/1.5)));
const scene=new B.Scene(engine);scene.clearColor=new B.Color4(.55,.69,.77,1);
scene.collisionsEnabled=true;
const camera=new B.ArcRotateCamera('camera',-Math.PI/2,1.02,18,new B.Vector3(0,1,0),scene);
camera.inputs.clear();camera.lowerRadiusLimit=11;camera.upperRadiusLimit=23;
let cameraZoom=18,cameraAngle=-Math.PI/2,cameraPitch=1.02;
const viewButton=document.getElementById('viewSwitch');
function changeView(){cameraZoom=cameraZoom===18?12:18;if(viewButton)viewButton.textContent=cameraZoom===12?'КАМЕРА: БЛИЖЕ':'КАМЕРА: ДАЛЬШЕ'}
if(viewButton)viewButton.onclick=changeView;
const light=new B.HemisphericLight('ambient',new B.Vector3(0,1,0),scene);light.intensity=.9;
const sun=new B.DirectionalLight('sun',new B.Vector3(-.5,-1,.35),scene);sun.position=new B.Vector3(12,23,-10);sun.intensity=1.9;
const shadow=new B.ShadowGenerator(1024,sun);shadow.useBlurExponentialShadowMap=true;shadow.blurKernel=12;
function material(name,hex,rough=1){const m=new B.PBRMaterial(name,scene);m.albedoColor=B.Color3.FromHexString(hex);m.metallic=0;m.roughness=rough;return m}
const sand=material('sand','#b4a28b'),stone=material('stone','#d0b99b'),dark=material('dark','#454d50'),blue=material('blue','#334f5d'),enemyMat=material('enemy','#665044'),metal=material('metal','#3b4145',.55);
function proceduralStone(){
 const tex=new B.DynamicTexture('concrete texture',{width:512,height:512},scene,false);
 const ctx=tex.getContext();ctx.fillStyle='#a89b86';ctx.fillRect(0,0,512,512);
 let seed=83721;function random(){seed=(seed*1664525+1013904223)>>>0;return seed/4294967296}
 for(let i=0;i<24000;i++){const c=Math.floor(90+random()*115);ctx.fillStyle='rgba('+c+','+(c-6)+','+(c-17)+','+(.04+random()*.17)+')';ctx.fillRect(random()*512,random()*512,1+random()*4,1+random()*4)}
 ctx.strokeStyle='rgba(58,53,45,.34)';ctx.lineWidth=2;for(let i=0;i<=512;i+=128){ctx.beginPath();ctx.moveTo(i,0);ctx.lineTo(i,512);ctx.stroke();ctx.beginPath();ctx.moveTo(0,i);ctx.lineTo(512,i);ctx.stroke()}
 tex.update(false);tex.wrapU=tex.wrapV=B.Texture.WRAP_ADDRESSMODE;tex.uScale=5;tex.vScale=5;return tex
}
sand.albedoTexture=proceduralStone();
const trim=material('limestone trim','#e0cbb0'),timber=material('timber','#735941'),windowMat=material('window','#273e48',.4);

function box(name,w,h,d,x,y,z,mat,collision=false){const o=B.MeshBuilder.CreateBox(name,{width:w,height:h,depth:d},scene);o.position.set(x,y,z);o.material=mat;o.receiveShadows=true;o.checkCollisions=collision;if(collision)solid.push({x,z,w,d});return o}
const solid=[];
box('ground',42,.4,44,0,-.22,0,sand);
for(const z of [-21.7,21.7]){box('wall',42,6,.6,0,3,z,stone);for(let x=-17;x<19;x+=7){box('window',3,2,.07,x,3.4,z+(z>0?-.35:.35),dark)}}
for(const x of [-20.7,20.7]){box('wall',.6,6,44,x,3,0,stone);for(let z=-16;z<19;z+=8)box('alcove',.07,2.1,3,x+(x>0?-.35:.35),3.5,z,dark)}
for(let i=0;i<10;i++){const x=-14+i%5*7,z=-12+Math.floor(i/5)*20;box('cover',2.8,1.6,2.2,x,.8,z,stone,true);box('cover top',3,.16,2.4,x,1.65,z,dark)}
for(const z of [-21.27,21.27])for(let x=-17;x<19;x+=7){box('window inset',2.7,1.75,.06,x,3.4,z,windowMat);box('stone sill',3.4,.15,.35,x,2.38,z,trim);box('window mullion',.12,1.8,.12,x,3.4,z,trim);box('window header',3.5,.16,.38,x,4.48,z,trim)}
for(let i=0;i<8;i++){const x=-17+(i%4)*11,z=-18+Math.floor(i/4)*36;const drum=B.MeshBuilder.CreateCylinder('metal barrel',{height:1,diameter:.83,tessellation:12},scene);drum.position.set(x,.5,z);drum.material=metal;drum.receiveShadows=true;shadow.addShadowCaster(drum);for(const y of [.23,.78]){const rim=B.MeshBuilder.CreateTorus('barrel rim',{diameter:.86,thickness:.07,tessellation:12},scene);rim.position.set(x,y,z);rim.material=dark}}
for(let i=0;i<6;i++){const x=-15+i*6;box('upper facade',4.5,.35,.55,x,5.75,-21.4,trim);box('column',.45,5.4,.6,x-2,2.7,-21.2,trim)}


const barricade=material('barricade','#827361'),warning=material('warning','#b98b48'),cargo=material('cargo','#56646a');
for(const side of [-1,1]){
 for(const z of [-5,4]){
  const x=side*8;
  box('tactical divider',.75,2.8,7,x,1.4,z,stone,true);
  box('divider cap',1,.2,7.3,x,2.86,z,trim);
 }
 for(const z of [-14,13]){
  const x=side*12;
  box('stacked cargo',2.3,1.7,2.4,x,.85,z,cargo,true);
  box('cargo stripe',2.4,.12,2.5,x,1.78,z,warning);
 }
}
for(const z of [-7,7]){
 box('central low wall',5.4,1.35,.8,0,.675,z,barricade,true);
 box('central wall trim',5.6,.13,1,0,1.41,z,trim);
}
function steerEnemy(ep,target,dt){
 const dx=target.x-ep.x,dz=target.z-ep.z,dist=Math.hypot(dx,dz);
 if(dist<1.8)return;
 const speed=1.65*dt,angle=Math.atan2(dz,dx);
 const choices=[0,.4,-.4,.85,-.85,1.4,-1.4,Math.PI];
 let best=null,bestScore=-Infinity;
 for(const delta of choices){
  const a=angle+delta,nx=ep.x+Math.cos(a)*speed,nz=ep.z+Math.sin(a)*speed;
  if(!canMove(nx,nz))continue;
  const score=-Math.hypot(target.x-nx,target.z-nz)-Math.abs(delta)*.035;
  if(score>bestScore){bestScore=score;best={nx,nz}}
 }
 if(best){ep.x=best.nx;ep.z=best.nz}
}
function hasLineOfSight(a,b){
 const dx=b.x-a.x,dz=b.z-a.z;
 return !solid.some(o=>{
  const left=o.x-o.w/2-.12,right=o.x+o.w/2+.12,top=o.z-o.d/2-.12,bottom=o.z+o.d/2+.12;
  let t0=0,t1=1;
  for(const [p,q] of [[-dx,a.x-left],[dx,right-a.x],[-dz,a.z-top],[dz,bottom-a.z]]){
   if(Math.abs(p)<1e-8){if(q<0)return false}
   else{const t=q/p;if(p<0){if(t>t1)return false;t0=Math.max(t0,t)}else{if(t<t0)return false;t1=Math.min(t1,t)}}
  }
  return t0<=t1&&t1>=0&&t0<=1;
 });
}

function agent(name,x,z,hostile=false){const root=new B.TransformNode(name,scene);root.position.set(x,0,z);const armor=hostile?enemyMat:blue;
const torso=B.MeshBuilder.CreateCapsule(name+' torso',{radius:.38,height:1.18,tessellation:12},scene);torso.parent=root;torso.position.y=1.23;torso.material=armor;shadow.addShadowCaster(torso);
const head=B.MeshBuilder.CreateSphere(name+' helmet',{diameter:.65,segments:12},scene);head.parent=root;head.position.y=2.12;head.scaling.y=.78;head.material=dark;shadow.addShadowCaster(head);
const visor=box(name+' visor',.5,.15,.12,0,0,0,metal);visor.parent=root;visor.position.set(0,2.1,-.31);
const legs=[],arms=[];for(const side of [-1,1]){const leg=box(name+' leg',.26,.72,.29,0,0,0,armor);leg.parent=root;leg.position.set(side*.22,.4,0);legs.push(leg);const arm=box(name+' arm',.23,.75,.26,0,0,0,armor);arm.parent=root;arm.position.set(side*.49,1.34,-.1);arms.push(arm)}
const vest=box(name+' ballistic vest',.79,.73,.38,0,0,0,dark);vest.parent=root;vest.position.set(0,1.4,-.16);
for(const side of [-1,1]){
 const pad=box(name+' shoulder armor',.33,.28,.4,0,0,0,armor);pad.parent=root;pad.position.set(side*.52,1.7,-.07);
 const strap=box(name+' webbing',.13,.68,.12,0,0,0,timber);strap.parent=root;strap.position.set(side*.26,1.43,-.4);
 const boot=box(name+' boot',.3,.18,.4,0,0,0,dark);boot.parent=root;boot.position.set(side*.22,.14,-.1);
 const earpiece=box(name+' headset',.11,.22,.2,0,0,0,dark);earpiece.parent=root;earpiece.position.set(side*.34,2.08,0);
}
for(let i=0;i<3;i++){const pouch=box(name+' magazine pouch',.2,.23,.15,0,0,0,timber);pouch.parent=root;pouch.position.set((i-1)*.23,1.18,-.43)}
const rifle=box(name+' rifle receiver',.2,.22,.73,0,0,0,metal);rifle.parent=root;rifle.position.set(.42,1.42,-.59);
const stock=box(name+' rifle stock',.24,.2,.38,0,0,0,dark);stock.parent=root;stock.position.set(.42,1.42,.03);
const barrel=box(name+' rifle barrel',.08,.08,.7,0,0,0,metal);barrel.parent=root;barrel.position.set(.42,1.44,-1.22);
const sight=box(name+' optic',.13,.14,.2,0,0,0,dark);sight.parent=root;sight.position.set(.42,1.62,-.63);
const magazine=box(name+' magazine',.15,.34,.18,0,0,0,dark);magazine.parent=root;magazine.position.set(.42,1.19,-.59);magazine.rotation.x=-.2;
return {root,hp:hostile?3:100,cool:0,legs,arms,walkPhase:0,lastX:x,lastZ:z,recoil:0}}
function animateAgent(a,dt){
 const p=a.root.position,travel=Math.hypot(p.x-a.lastX,p.z-a.lastZ);a.lastX=p.x;a.lastZ=p.z;
 const moving=Math.min(1,travel/Math.max(.001,dt*3));a.walkPhase+=travel*9;
 const stride=Math.sin(a.walkPhase)*.42*moving;
 a.legs[0].rotation.x=stride;a.legs[1].rotation.x=-stride;
 a.arms[0].rotation.x=-stride*.35;a.arms[1].rotation.x=stride*.35;
 a.recoil=Math.max(0,a.recoil-dt*5);
 a.root.position.y=Math.abs(Math.sin(a.walkPhase))*.035*moving;
}
const player=agent('operator',0,12);const enemies=[];let kills=0,stage=Number(localStorage.getItem('babylon_stage')||1),mode=localStorage.getItem('babylon_mode')||'campaign',playing=false,over=false;
const objective=()=>mode==='endless'?Infinity:12+(stage-1)*6;
const killsEl=document.getElementById('kills'),healthEl=document.getElementById('health'),objectiveEl=document.getElementById('objective');
function updateHUD(){killsEl.textContent=kills+' / '+(Number.isFinite(objective())?objective():'∞');healthEl.textContent=Math.ceil(player.hp);objectiveEl.textContent='ОПЕРАЦИЯ '+stage+' · '+(mode==='endless'?'БЕСКОНЕЧНЫЙ РЕЖИМ':'ЗАЧИСТКА СЕКТОРА')}
function canMove(x,z){return Math.abs(x)<19.8&&Math.abs(z)<20.8&&!solid.some(o=>Math.abs(x-o.x)<o.w/2+.6&&Math.abs(z-o.z)<o.d/2+.6)}
function coverBlocks(ax,az,bx,bz){
 const dx=bx-ax,dz=bz-az;
 for(const o of solid){
  let enter=0,exit=1;
  for(const [p,v,min,max] of [[ax,dx,o.x-o.w/2,o.x+o.w/2],[az,dz,o.z-o.d/2,o.z+o.d/2]]){
   if(Math.abs(v)<.00001){if(p<min||p>max){exit=-1;break}}else{const t1=(min-p)/v,t2=(max-p)/v;enter=Math.max(enter,Math.min(t1,t2));exit=Math.min(exit,Math.max(t1,t2))}
  }
  if(enter<=exit&&exit>0&&enter<1)return true;
 }
 return false
}
const medkits=[];
const medkitMaterial=material('medical kit','#d9e8db');
const medicalCross=material('medical red','#d94843');
function dropMedkit(x,z){
 if(medkits.length>=5)return;
 const root=new B.TransformNode('medical pickup',scene);root.position.set(x,.24,z);
 const body=box('medkit body',.65,.32,.53,0,0,0,medkitMaterial);body.parent=root;
 const horizontal=box('red cross horizontal',.32,.065,.12,0,0,0,medicalCross);horizontal.parent=root;horizontal.position.set(0,.17,0);
 const vertical=box('red cross vertical',.12,.065,.32,0,0,0,medicalCross);vertical.parent=root;vertical.position.set(0,.17,0);
 medkits.push({root,time:0})
}

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
let lookPointer=null,lookX=0,lookY=0;
canvas.addEventListener('pointerdown',e=>{if(!playing||lookPointer!==null)return;lookPointer=e.pointerId;lookX=e.clientX;lookY=e.clientY;canvas.setPointerCapture(e.pointerId)});
canvas.addEventListener('pointermove',e=>{if(e.pointerId!==lookPointer||!playing)return;const dx=e.clientX-lookX,dy=e.clientY-lookY;lookX=e.clientX;lookY=e.clientY;cameraAngle=Math.max(-Math.PI*1.25,Math.min(-Math.PI*.10,cameraAngle-dx*.004));cameraPitch=Math.max(.58,Math.min(1.33,cameraPitch+dy*.003))});
function releaseLook(e){if(e.pointerId===lookPointer)lookPointer=null}
canvas.addEventListener('pointerup',releaseLook);canvas.addEventListener('pointercancel',releaseLook);
const keys=new Set();window.onkeydown=e=>keys.add(e.key.toLowerCase());window.onkeyup=e=>keys.delete(e.key.toLowerCase());
let last=performance.now(),shot=0;const projectiles=[];const tracerMaterial=material('tracer','#f5b75c');tracerMaterial.emissiveColor=new B.Color3(1,.47,.12);
const hitMarker=document.getElementById('hitMarker'),damageFlash=document.getElementById('damageFlash');
let hitTimer=0,damageTimer=0;
function registerHit(){hitTimer=.15;if(hitMarker)hitMarker.style.opacity='1'}
function registerDamage(){damageTimer=.32;if(damageFlash)damageFlash.style.opacity='.65'}
const weaponTypes=[
 {id:'rifle',name:'MK-18 · АВТОМАТ',delay:.30,damage:1,range:22,speed:27},
 {id:'smg',name:'VECTOR · ПП',delay:.14,damage:1,range:15,speed:34},
 {id:'marksman',name:'DMR-7 · ВИНТОВКА',delay:.7,damage:3,range:32,speed:47}
];
let weaponIndex=Math.max(0,Math.min(2,Number(localStorage.getItem('babylon_weapon')||0)));
const weaponLabel=document.getElementById('weaponName');
function updateWeapon(){if(weaponLabel)weaponLabel.textContent=weaponTypes[weaponIndex].name;localStorage.setItem('babylon_weapon',String(weaponIndex))}
function cycleWeapon(){weaponIndex=(weaponIndex+1)%weaponTypes.length;updateWeapon();shot=0}
const weaponButton=document.getElementById('weaponSwitch');if(weaponButton)weaponButton.onclick=()=>{if(playing)cycleWeapon()};
updateWeapon();
const muzzleMaterial=material('muzzle flash','#ffb54d');muzzleMaterial.emissiveColor=new B.Color3(1,.57,.12);
const muzzle=B.MeshBuilder.CreateSphere('muzzle flash',{diameter:.34,segments:8},scene);muzzle.material=muzzleMaterial;muzzle.isVisible=false;
let flashTime=0;
function updateFlash(dt){flashTime=Math.max(0,flashTime-dt);muzzle.isVisible=flashTime>0}
function fire(from,to){player.recoil=.22;flashTime=.065;muzzle.position.copyFrom(from);muzzle.position.addInPlace(to.subtract(from).normalize().scale(.9));muzzle.isVisible=true;const mesh=B.MeshBuilder.CreateSphere('shot',{diameter:.12,segments:6},scene);mesh.material=tracerMaterial;mesh.position.copyFrom(from);const v=to.subtract(from).normalize();projectiles.push({mesh,v,ttl:1,damage:weaponTypes[weaponIndex].damage,speed:weaponTypes[weaponIndex].speed})}
engine.runRenderLoop(()=>{const now=performance.now(),dt=Math.min(.05,(now-last)/1000);last=now;updateFlash(dt);hitTimer=Math.max(0,hitTimer-dt);damageTimer=Math.max(0,damageTimer-dt);if(hitMarker)hitMarker.style.opacity=hitTimer>0?'1':'0';if(damageFlash)damageFlash.style.opacity=String(damageTimer*1.8);
if(playing){let x=move.x+(keys.has('d')?1:0)-(keys.has('a')?1:0),z=move.z+(keys.has('s')?1:0)-(keys.has('w')?1:0),len=Math.hypot(x,z);if(len>1){x/=len;z/=len}
const p=player.root.position;if(canMove(p.x+x*dt*5,p.z))p.x+=x*dt*5;if(canMove(p.x,p.z+z*dt*5))p.z+=z*dt*5;animateAgent(player,dt);
let closest=null,dist=100;for(const e of enemies){const ep=e.root.position,d=Math.hypot(ep.x-p.x,ep.z-p.z);if(d<dist){dist=d;closest=e}if(d>1.8)steerEnemy(ep,p,dt);e.root.rotation.y=Math.atan2(p.x-ep.x,-(p.z-ep.z));animateAgent(e,dt);e.cool-=dt;if(d<2&&e.cool<=0){player.hp-=8;e.cool=1.4;registerDamage();updateHUD();if(player.hp<=0)result(false)}}
shot-=dt;const target=enemies.filter(e=>Math.hypot(e.root.position.x-p.x,e.root.position.z-p.z)<weaponTypes[weaponIndex].range&&hasLineOfSight(p,e.root.position)).sort((a,b)=>B.Vector3.DistanceSquared(a.root.position,p)-B.Vector3.DistanceSquared(b.root.position,p))[0];
if(target&&shot<=0){shot=weaponTypes[weaponIndex].delay;player.root.rotation.y=Math.atan2(target.root.position.x-p.x,-(target.root.position.z-p.z));fire(p.add(new B.Vector3(0,1.4,0)),target.root.position.add(new B.Vector3(0,1.3,0)))}
for(let i=projectiles.length-1;i>=0;i--){const b=projectiles[i],prev=b.mesh.position.clone();b.mesh.position.addInPlace(b.v.scale(dt*b.speed));b.ttl-=dt;const hit=enemies.find(e=>{const center=e.root.position.add(new B.Vector3(0,1.3,0));const segment=b.mesh.position.subtract(prev),len2=segment.lengthSquared();const t=len2>0?Math.max(0,Math.min(1,B.Vector3.Dot(center.subtract(prev),segment)/len2)):0;return B.Vector3.DistanceSquared(center,prev.add(segment.scale(t)))<.58});if(hit){registerHit();hit.hp-=b.damage;b.ttl=0;if(hit.hp<=0){const deathX=hit.root.position.x,deathZ=hit.root.position.z;hit.root.getChildMeshes().forEach(m=>m.dispose());hit.root.dispose();enemies.splice(enemies.indexOf(hit),1);kills++;updateHUD();if(kills%4===0)dropMedkit(deathX,deathZ);if(kills>=objective())result(true);else if(enemies.length<5)spawn()}}if(b.ttl<=0){b.mesh.dispose();projectiles.splice(i,1)}}
for(let i=medkits.length-1;i>=0;i--){const kit=medkits[i];kit.time+=dt;kit.root.rotation.y+=dt*.8;kit.root.position.y=.24+Math.sin(kit.time*3)*.08;if(Math.hypot(p.x-kit.root.position.x,p.z-kit.root.position.z)<1.2&&player.hp<100){player.hp=Math.min(100,player.hp+30);kit.root.getChildMeshes().forEach(m=>m.dispose());kit.root.dispose();medkits.splice(i,1);status.textContent='АПТЕЧКА +30 HP';updateHUD()}}
camera.target=B.Vector3.Lerp(camera.target,p.add(new B.Vector3(0,1,0)),Math.min(1,dt*5));camera.alpha+=(cameraAngle-camera.alpha)*Math.min(1,dt*6);camera.beta+=(cameraPitch-camera.beta)*Math.min(1,dt*6);camera.radius+=(cameraZoom-camera.radius)*Math.min(1,dt*6)}
scene.render()});
window.addEventListener('resize',()=>engine.resize());updateHUD();menu();status.textContent='BABYLON.JS · ГОТОВО';
})();