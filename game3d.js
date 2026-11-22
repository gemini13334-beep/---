import * as THREE from './vendor/three.module.js';
import { GLTFLoader } from './vendor/GLTFLoader.js';
const gltfLoader=new GLTFLoader();
const assetStatus={loaded:0,failed:0};const modelPromises=new Map();function fetchModel(url){if(!modelPromises.has(url))modelPromises.set(url,new Promise((resolve,reject)=>gltfLoader.load(url,resolve,undefined,reject)));return modelPromises.get(url)}
function loadModel(url,parent,{height=2,offsetY=0,replace=null}={}){
 fetchModel(url).then(gltf=>{
  const model=gltf.scene.clone(true);const bounds=new THREE.Box3().setFromObject(model),size=bounds.getSize(new THREE.Vector3());
  if(!Number.isFinite(size.y)||size.y<=0)throw new Error('Invalid GLTF model size: '+url);
  const factor=height/size.y;model.scale.setScalar(factor);
  const scaled=new THREE.Box3().setFromObject(model);model.position.y=offsetY-scaled.min.y;
  model.traverse(o=>{if(o.isMesh){o.castShadow=true;o.receiveShadow=true;o.material=Array.isArray(o.material)?o.material.map(m=>m.clone()):o.material.clone()}});
  parent.add(model);
  if(replace){for(const item of Array.isArray(replace)?replace:[replace])item.visible=false;}
  assetStatus.loaded++;
  if(gltf.animations.length){const mixer=new THREE.AnimationMixer(model);mixer.clipAction(gltf.animations[0]).play();animationMixers.push({mixer,owner:parent})}
 }).catch(error=>{assetStatus.failed++;console.warn('GLTF fallback:',url,error)});
}
const animationMixers=[];

const loading=document.getElementById('loading'),hpEl=document.getElementById('hp'),killsEl=document.getElementById('kills'),msg=document.getElementById('msg');
let renderer;try{renderer=new THREE.WebGLRenderer({antialias:true,powerPreference:'high-performance',alpha:false});}catch(e){loading.textContent="WebGL недоступен на этом устройстве. Требуется поддержка 3D.";throw e}
const mobile=/Android|iPhone|iPad/i.test(navigator.userAgent);
function readSetting(name,fallback){try{const v=localStorage.getItem('tactical3d_'+name);return v===null?fallback:v}catch{return fallback}}
function saveSetting(name,value){try{localStorage.setItem('tactical3d_'+name,String(value))}catch{}}
const savedQuality=readSetting('quality',mobile?'high':'high');
let stage=Math.max(1,Math.min(99,Number(readSetting('stage','1'))||1)),mode=readSetting('mode','campaign');
const targetKills=mode==='endless'?Infinity:12+(stage-1)*6;
const targetLabel=()=>Number.isFinite(targetKills)?String(targetKills):'∞';
let quality=['low','balanced','high'].includes(savedQuality)?savedQuality:(mobile?'high':'high');function applyQuality(){renderer.setPixelRatio(Math.min(devicePixelRatio,quality==='high'?Math.min(devicePixelRatio,2):quality==='balanced'?1.35:1.0));renderer.shadowMap.enabled=quality!=='low';renderer.shadowMap.type=THREE.PCFSoftShadowMap;renderer.setSize(innerWidth,innerHeight)}applyQuality();renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.4;document.body.prepend(renderer.domElement);
const scene=new THREE.Scene();scene.background=new THREE.Color(0x91b3c5);scene.fog=new THREE.FogExp2(0x91b3c5,.011);
const camera=new THREE.PerspectiveCamera(58,innerWidth/innerHeight,.1,150);
scene.add(new THREE.HemisphereLight(0xd6edff,0x87765e,2.0));
const sun=new THREE.DirectionalLight(0xffe1b4,2.8);sun.position.set(-7,15,8);sun.castShadow=true;sun.shadow.mapSize.set(mobile?512:1024,mobile?512:1024);sun.shadow.camera.left=-25;sun.shadow.camera.right=25;sun.shadow.camera.top=25;sun.shadow.camera.bottom=-25;scene.add(sun);
function mat(color,roughness=.7,metalness=.15){return new THREE.MeshStandardMaterial({color,roughness,metalness})}
const floor=mat(0x8b8273,.95),wall=mat(0xb5a38b,.96),metal=mat(0x223544,.42,.65),amber=new THREE.MeshStandardMaterial({color:0xffc477,emissive:0xd97d21,emissiveIntensity:1.8}),cyan=new THREE.MeshStandardMaterial({color:0x77e5ff,emissive:0x147eaa,emissiveIntensity:1.6}),red=mat(0x8b4149);
function box(w,h,d,x,y,z,m,solid=false){const mesh=new THREE.Mesh(new THREE.BoxGeometry(w,h,d),m);mesh.position.set(x,y,z);mesh.castShadow=true;mesh.receiveShadow=true;scene.add(mesh);if(solid)obstacles.push({x,z,w,d});return mesh}
const obstacles=[];
function makeConcreteTexture(){
 const canvas=document.createElement('canvas');canvas.width=256;canvas.height=256;const ctx=canvas.getContext('2d');
 ctx.fillStyle='#8b8273';ctx.fillRect(0,0,256,256);
 let seed=24577;function random(){seed=(seed*1664525+1013904223)>>>0;return seed/4294967296}
 for(let i=0;i<9500;i++){const shade=Math.floor(75+random()*95);ctx.fillStyle='rgba('+shade+','+(shade-4)+','+(shade-11)+','+(random()*.14)+')';ctx.fillRect(random()*256,random()*256,1+random()*3,1+random()*3)}
 ctx.strokeStyle='#504d48';ctx.lineWidth=2;for(let x=0;x<=256;x+=64){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,256);ctx.stroke()}for(let y=0;y<=256;y+=64){ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(256,y);ctx.stroke()}
 for(let i=0;i<22;i++){ctx.strokeStyle='rgba(48,45,42,'+(.06+random()*.18)+')';ctx.lineWidth=.5+random();ctx.beginPath();let x=random()*256,y=random()*256;ctx.moveTo(x,y);ctx.lineTo(x+random()*26-13,y+random()*25-12);ctx.stroke()}
 const tex=new THREE.CanvasTexture(canvas);tex.wrapS=tex.wrapT=THREE.RepeatWrapping;tex.repeat.set(4,4);tex.colorSpace=THREE.SRGBColorSpace;tex.anisotropy=Math.min(8,renderer.capabilities.getMaxAnisotropy());return tex
}
const concrete=new THREE.MeshStandardMaterial({map:makeConcreteTexture(),roughness:.97,metalness:0});
box(32,.3,34,0,-.2,0,concrete);
box(32,5,.7,0,2.5,-17,wall);box(32,5,.7,0,2.5,17,wall);box(.7,5,34,-16,2.5,0,wall);box(.7,5,34,16,2.5,0,wall);
for(let i=0;i<8;i++){let x=-11+(i%4)*7.3,z=-9+Math.floor(i/4)*17;box(3,1.3,2.4,x,.65,z,metal,true);box(2.6,.08,2,x,1.35,z,wall);if(i===0||i===3){const propAnchor=new THREE.Group();propAnchor.position.set(x,1.38,z);scene.add(propAnchor);loadModel('./models/crate.gltf',propAnchor,{height:1.05,offsetY:0})}box(.7,.9,.09,x,1.95,z-.7,cyan);if(i%4===0){const light=new THREE.PointLight(0x63cfff,5,8,2);light.position.set(x,2.3,z-.7);scene.add(light)}}
const stoneTrim=mat(0xd1bea0,.95),recess=mat(0x39444a,.94),wood=mat(0x7d6045,.92),iron=mat(0x484f4f,.75,.45);
for(let i=0;i<7;i++){
 const x=-13+i*4.25;
 for(const z of [-16.55,16.55]){
  box(3.3,.22,.16,x,4.6,z,stoneTrim);
  box(1.5,1.5,.14,x,3.35,z,recess);
  box(1.7,.15,.25,x,2.55,z,stoneTrim);
  box(.12,1.4,.19,x,3.35,z,wood);
  box(1.5,.12,.19,x,3.35,z,wood);
 }
}
for(let i=0;i<5;i++){
 const z=-12+i*6;
 for(const x of [-15.55,15.55]){
  box(.16,.22,3.5,x,4.6,z,stoneTrim);
  box(.16,1.5,1.45,x,3.35,z,recess);
  box(.23,.15,1.7,x,2.55,z,stoneTrim);
 }
}
for(let i=0;i<6;i++){
 const x=-12+i*4.8,z=i%2===0?-13:13;
 const barrel=new THREE.Mesh(new THREE.CylinderGeometry(.46,.46,.95,12),i%3===0?wood:iron);
 barrel.position.set(x,.48,z);barrel.castShadow=true;barrel.receiveShadow=true;scene.add(barrel);
 for(const y of [.22,.75]){const band=new THREE.Mesh(new THREE.TorusGeometry(.46,.035,5,12),iron);band.rotation.x=Math.PI/2;band.position.set(x,y,z);scene.add(band)}
}
function agent(color){const root=new THREE.Group(),suit=mat(color,.65,.25),skin=mat(0xf3c3a6),hair=mat(0xdde8f1);let body=new THREE.Mesh(new THREE.CapsuleGeometry(.43,.75,4,8),suit);body.position.y=1.15;root.add(body);let head=new THREE.Mesh(new THREE.SphereGeometry(.35,12,8),skin);head.position.y=2.05;root.add(head);let cap=new THREE.Mesh(new THREE.SphereGeometry(.37,12,8),hair);cap.position.set(0,2.19,-.07);cap.scale.y=.55;root.add(cap);let gun=new THREE.Mesh(new THREE.BoxGeometry(.17,.18,.9),metal);gun.position.set(.4,1.35,-.48);root.add(gun);root.traverse(o=>{if(o.isMesh){o.castShadow=true;o.receiveShadow=true}});scene.add(root);loadModel(color===0x39769a?'./models/hero.gltf':'./models/enemy.gltf',root,{height:2.45,replace:[...root.children]});return root}
const hero=agent(0x39769a);hero.position.set(0,0,11);const enemies=[];
function spawn(){
 const a=agent(0x943e48);let placed=false;
 for(let tries=0;tries<80;tries++){
  const x=(Math.random()-.5)*27,z=-12+Math.random()*15;
  if(canMove(x,z)&&Math.hypot(x-hero.position.x,z-hero.position.z)>7&&!enemies.some(e=>Math.hypot(x-e.position.x,z-e.position.z)<1.6)){a.position.set(x,0,z);placed=true;break}
 }
 if(!placed)a.position.set(0,0,-13);
 a.userData.hp=3;a.userData.cool=0;enemies.push(a)
}
for(let i=0;i<5;i++)spawn();
const radarCanvas=document.getElementById('radarcanvas'),radarCtx=radarCanvas.getContext('2d');
let radarLastDraw=0;
function drawRadar(){
 if(!radarCtx)return;
 const c=radarCtx,w=radarCanvas.width,h=radarCanvas.height;
 c.clearRect(0,0,w,h);c.fillStyle='#13222bd9';c.fillRect(0,0,w,h);
 c.strokeStyle='#6f89934b';c.lineWidth=1;
 for(let i=1;i<=3;i++){c.beginPath();c.arc(w/2,h/2,i*26,0,Math.PI*2);c.stroke()}
 c.beginPath();c.moveTo(w/2,0);c.lineTo(w/2,h);c.moveTo(0,h/2);c.lineTo(w,h/2);c.stroke();
 const scale=2.6;
 function dot(x,z,r,color){const px=w/2+(x-hero.position.x)*scale,py=h/2+(z-hero.position.z)*scale;if(px<5||px>w-5||py<5||py>h-5)return;c.fillStyle=color;c.beginPath();c.arc(px,py,r,0,Math.PI*2);c.fill()}
 for(const o of obstacles){const px=w/2+(o.x-hero.position.x)*scale,py=h/2+(o.z-hero.position.z)*scale;c.fillStyle='#73828a66';c.fillRect(px-o.w*scale/2,py-o.d*scale/2,o.w*scale,o.d*scale)}
 for(const e of enemies)dot(e.position.x,e.position.z,4,'#ec7469');
 for(const p of pickups)dot(p.mesh.position.x,p.mesh.position.z,3,'#5ce4ae');
 dot(hero.position.x,hero.position.z,5,'#9ad3f2');
 c.strokeStyle='#9ad3f2';c.beginPath();c.moveTo(w/2,h/2-11);c.lineTo(w/2,h/2-6);c.stroke()
}
// Segment versus expanded AABB: cover blocks projectiles and targeting.
function blocked(ax,az,bx,bz,pad=0){
 for(const o of obstacles){const minX=o.x-o.w/2-pad,maxX=o.x+o.w/2+pad,minZ=o.z-o.d/2-pad,maxZ=o.z+o.d/2+pad;let t0=0,t1=1,dx=bx-ax,dz=bz-az;
  for(const [start,delta,lo,hi] of [[ax,dx,minX,maxX],[az,dz,minZ,maxZ]]){if(Math.abs(delta)<1e-7){if(start<lo||start>hi){t0=2;break}}else{let a=(lo-start)/delta,b=(hi-start)/delta;if(a>b)[a,b]=[b,a];t0=Math.max(t0,a);t1=Math.min(t1,b)}}
  if(t0<=t1&&t0<=1&&t1>=0)return true
 }return false
}
function segmentDistanceSq(ax,az,bx,bz,px,pz){
 const dx=bx-ax,dz=bz-az,len=dx*dx+dz*dz;
 const t=len>0?Math.max(0,Math.min(1,((px-ax)*dx+(pz-az)*dz)/len)):0;
 const ex=ax+dx*t-px,ez=az+dz*t-pz;
 return ex*ex+ez*ez
}
let hitMarkerTime=0;const hitMarker=document.getElementById('crosshair');
function showHitMarker(){hitMarkerTime=.14;hitMarker.classList.add('hit')}
let noticeTimer=0;function notify(text,duration=2.5){msg.textContent=text;noticeTimer=duration}
const pickups=[];const medkitGeometry=new THREE.BoxGeometry(.45,.25,.45),medkitMaterial=new THREE.MeshStandardMaterial({color:0x2bc7a4,emissive:0x08795b,emissiveIntensity:.8});
function dropMedkit(x,z){
 const mesh=new THREE.Mesh(medkitGeometry,medkitMaterial);mesh.position.set(x,.32,z);scene.add(mesh);pickups.push({mesh,ttl:20})
}
const feed=document.getElementById('killfeed'),progressFill=document.getElementById('progressfill'),armorEl=document.getElementById('armor');
let armor=50;
armorEl.textContent=String(armor);
function addKillFeed(){
 const entry=document.createElement('div');entry.className='entry';entry.textContent='ОПЕРАТОР  ✦  ПРОТИВНИК';
 feed.prepend(entry);
 while(feed.children.length>3)feed.lastChild.remove();
 setTimeout(()=>{if(entry.isConnected)entry.remove()},3800);
}
const bullets=[];let health=100,kills=0,fire=0,invuln=0,ended=false;const damageDirection=document.getElementById('damageDirection');let damageDirectionTime=0;
function showDamageDirection(enemy){const dx=enemy.position.x-hero.position.x,dz=enemy.position.z-hero.position.z;damageDirection.style.transform='translate(-50%,-50%) rotate('+Math.atan2(dx,-dz)+'rad)';damageDirection.classList.add('active');damageDirectionTime=.55}
const damageOverlay=document.createElement('div');damageOverlay.style.cssText='position:fixed;inset:0;z-index:2;pointer-events:none;background:radial-gradient(ellipse at center,transparent 40%,#c71928 100%);opacity:0;transition:opacity 90ms';document.body.append(damageOverlay);const move={x:0,y:0},stick=document.getElementById('stick'),knob=document.getElementById('knob');let pointer=null;
function joystick(e){let r=stick.getBoundingClientRect(),x=e.clientX-(r.left+r.width/2),y=e.clientY-(r.top+r.height/2),len=Math.hypot(x,y),v=Math.min(1,len/47);move.x=len?x/len*v:0;move.y=len?y/len*v:0;knob.style.transform='translate('+move.x*39+'px,'+move.y*39+'px)'}
stick.addEventListener('pointerdown',e=>{if(pausedByPlayer||ended||pointer!==null)return;e.preventDefault();pointer=e.pointerId;stick.setPointerCapture(pointer);joystick(e)});stick.addEventListener('pointermove',e=>{if(e.pointerId===pointer&&!pausedByPlayer){e.preventDefault();joystick(e)}});function release(e){if(e.pointerId===pointer){pointer=null;move.x=move.y=0;knob.style.transform=''}}stick.addEventListener('pointerup',release);stick.addEventListener('pointercancel',release);
const keys=new Set();addEventListener('keydown',e=>keys.add(e.key.toLowerCase()));addEventListener('keyup',e=>keys.delete(e.key.toLowerCase()));
let dash=0,dashCooldown=0;const dashButton=document.getElementById('dash');
function triggerDash(){if(ended||pausedByPlayer||document.hidden||dashCooldown>0||dash>0)return;dash=.22;dashCooldown=2.8;dashButton.textContent='РЫВОК';dashButton.style.opacity='0.55'}
dashButton.addEventListener('pointerdown',triggerDash);
addEventListener('keydown',e=>{if(e.code==='Space'){e.preventDefault();if(!e.repeat)triggerDash()}});
function canMove(x,z){return Math.abs(x)<15.1&&Math.abs(z)<16.1&&!obstacles.some(o=>Math.abs(x-o.x)<o.w/2+.55&&Math.abs(z-o.z)<o.d/2+.55)}
const clock=new THREE.Clock(),spark=new THREE.SphereGeometry(.12,6,6);let elapsed=0;const tempColor=new THREE.Color();function projectile(from,to,enemy){let v=to.clone().sub(from).normalize(),mesh=new THREE.Mesh(spark,enemy?amber:cyan);mesh.position.copy(from);scene.add(mesh);bullets.push({mesh,v,enemy,ttl:1.3})}
function update(){let dt=Math.min(clock.getDelta(),.04);elapsed+=dt;for(const item of animationMixers){if(item.owner.parent)item.mixer.update(dt)}if(ended)return;if(damageDirectionTime>0){damageDirectionTime-=dt;if(damageDirectionTime<=0)damageDirection.classList.remove('active')}if(hitMarkerTime>0){hitMarkerTime-=dt;if(hitMarkerTime<=0)hitMarker.classList.remove('hit')}if(noticeTimer>0){noticeTimer-=dt;if(noticeTimer<=0)msg.textContent='Зачисти помещение. Стрельба автоматическая.'}invuln=Math.max(0,invuln-dt);damageOverlay.style.opacity=String(Math.min(.62,Math.max(0,invuln-.12)*.95));let mx=move.x+(keys.has('d')?1:0)-(keys.has('a')?1:0),mz=move.y+(keys.has('s')?1:0)-(keys.has('w')?1:0),l=Math.hypot(mx,mz);if(l>1){mx/=l;mz/=l}dashCooldown=Math.max(0,dashCooldown-dt);
if(dashCooldown===0&&dashButton.style.opacity!=='1'){dashButton.style.opacity='1';dashButton.textContent='РЫВОК'}
else if(dashCooldown>0)dashButton.textContent=Math.ceil(dashCooldown)+'с';
let speed=dash>0?15:6;dash=Math.max(0,dash-dt);hero.userData.motion=(hero.userData.motion||0)+dt*Math.max(0,l)*11;const running=l>.08;hero.position.y=running?Math.abs(Math.sin(hero.userData.motion))*.07:Math.sin(elapsed*2)*.014;let nx=hero.position.x+mx*speed*dt,nz=hero.position.z+mz*speed*dt;if(canMove(nx,hero.position.z))hero.position.x=nx;if(canMove(hero.position.x,nz))hero.position.z=nz;
let closest=null,dist=100;for(const e of enemies){let dx=hero.position.x-e.position.x,dz=hero.position.z-e.position.z,d=Math.hypot(dx,dz);if(d<dist&&!blocked(hero.position.x,hero.position.z,e.position.x,e.position.z,.06)){dist=d;closest=e}if(d>2.7){
 let step=dt*1.65,tx=dx/d,tz=dz/d;
 // Steering: probe lateral routes when direct pursuit is blocked by desks.
 let targetX=e.position.x+tx*step,targetZ=e.position.z+tz*step;
 if(!canMove(targetX,e.position.z)||!canMove(e.position.x,targetZ)||blocked(e.position.x,e.position.z,hero.position.x,hero.position.z,.2)){
  let sign=e.userData.flank||((Math.random()<.5)?-1:1);
  let options=[[tx*.35-tz*sign*.94,tz*.35+tx*sign*.94],[tx*.35+tz*sign*.94,tz*.35-tx*sign*.94],[-tz*sign,tx*sign],[tx,tz]];
  let found=options.find(v=>canMove(e.position.x+v[0]*step*2,e.position.z+v[1]*step*2)&&!blocked(e.position.x,e.position.z,e.position.x+v[0]*step*2,e.position.z+v[1]*step*2,.08));
  if(found){tx=found[0];tz=found[1];e.userData.flank=sign}
  else e.userData.flank=-sign
 }
 if(canMove(e.position.x+tx*step,e.position.z))e.position.x+=tx*step;
 if(canMove(e.position.x,e.position.z+tz*step))e.position.z+=tz*step;
}e.lookAt(hero.position.x,0,hero.position.z);e.userData.motion=(e.userData.motion||0)+dt*7;e.position.y=Math.abs(Math.sin(e.userData.motion))*.035;e.userData.cool-=dt;if(d<2&&!blocked(e.position.x,e.position.z,hero.position.x,hero.position.z,.06)&&e.userData.cool<=0){e.userData.cool=1.25;if(invuln<=0){const rawDamage=12,absorbed=Math.min(armor,Math.ceil(rawDamage*.65));armor-=absorbed;health=Math.max(0,health-(rawDamage-absorbed));armorEl.textContent=String(armor);showDamageDirection(e);invuln=.6;hpEl.textContent=String(health);damageOverlay.style.opacity='.62'}}}
fire-=dt;if(closest&&dist<22&&fire<=0){fire=.28;hero.lookAt(closest.position.x,0,closest.position.z);projectile(hero.position.clone().add(new THREE.Vector3(0,1.35,0)),closest.position.clone().add(new THREE.Vector3(0,1.2,0)),false)}
for(let i=bullets.length-1;i>=0;i--){let b=bullets[i];b.mesh.position.addScaledVector(b.v,dt*28);b.ttl-=dt;const prevX=b.mesh.position.x-b.v.x*dt*28,prevZ=b.mesh.position.z-b.v.z*dt*28;
 let wallHit=blocked(prevX,prevZ,b.mesh.position.x,b.mesh.position.z,.05);
 let hit=wallHit?null:enemies.find(e=>segmentDistanceSq(prevX,prevZ,b.mesh.position.x,b.mesh.position.z,e.position.x,e.position.z)<.75*.75);if(wallHit)b.ttl=0;if(hit){showHitMarker();hit.userData.hp--;hit.userData.flash=.15;b.ttl=0;if(hit.userData.hp<=0){scene.remove(hit);for(let j=animationMixers.length-1;j>=0;j--)if(animationMixers[j].owner===hit)animationMixers.splice(j,1);enemies.splice(enemies.indexOf(hit),1);kills++;if(kills%3===0)dropMedkit(hit.position.x,hit.position.z);killsEl.textContent=kills+' / '+targetLabel();progressFill.style.width=Number.isFinite(targetKills)?Math.min(100,kills/targetKills*100)+'%':'100%';addKillFeed();if((mode==='endless'||kills<targetKills)&&enemies.length<Math.min(8,4+stage))spawn()}}if(b.ttl<=0){scene.remove(b.mesh);bullets.splice(i,1)}}
for(let i=pickups.length-1;i>=0;i--){
 const p=pickups[i];p.ttl-=dt;p.mesh.rotation.y+=dt*1.8;p.mesh.position.y=.35+Math.sin(elapsed*4+i)*.08;
 if(Math.hypot(hero.position.x-p.mesh.position.x,hero.position.z-p.mesh.position.z)<1.1&&health<100){
  health=Math.min(100,health+25);hpEl.textContent=String(health);notify('АПТЕЧКА +25 HP');p.ttl=0
 }
 if(p.ttl<=0){scene.remove(p.mesh);pickups.splice(i,1)}
}
for(const e of enemies){e.userData.flash=Math.max(0,(e.userData.flash||0)-dt);e.traverse(o=>{if(o.isMesh&&o.material&&!Array.isArray(o.material)&&o.material.emissive){if(!o.userData.baseEmissive){o.userData.baseEmissive=o.material.emissive.clone();o.userData.baseIntensity=o.material.emissiveIntensity}o.material.emissive.copy(e.userData.flash>0?tempColor.set(0xff4937):o.userData.baseEmissive);o.material.emissiveIntensity=e.userData.flash>0?1.6:o.userData.baseIntensity}})}camera.position.lerp(new THREE.Vector3(hero.position.x+0,hero.position.y+15,hero.position.z+19),Math.min(1,dt*5));camera.lookAt(hero.position.x,1,hero.position.z-3);
if(health<=0||kills>=targetKills){ended=true;msg.textContent=health<=0?'МИССИЯ ПРОВАЛЕНА':'МИССИЯ ВЫПОЛНЕНА!';const mission=document.getElementById('mission');if(mission)mission.textContent=health<=0?'ОПЕРАЦИЯ ПРЕРВАНА':'ОПЕРАЦИЯ ЗАВЕРШЕНА';showRestart()}}
function showRestart(){
 if(document.getElementById('restart3d'))return;
 const overlay=document.createElement('div');overlay.id='restart3d';
 overlay.style.cssText='position:fixed;inset:0;z-index:12;background:linear-gradient(120deg,#101a24f5,#26343fe8);display:flex;align-items:center;justify-content:center;padding:18px;color:#f2e8d7;font:14px Arial';
 const panel=document.createElement('div');panel.style.cssText='width:min(94vw,530px);padding:24px;border-top:3px solid #df9f4d;background:#19242ef5;box-shadow:0 20px 70px #0009;display:flex;flex-direction:column;gap:14px';
 const heading=document.createElement('h2');heading.textContent=health<=0?'ОПЕРАЦИЯ ПРОВАЛЕНА':'МИССИЯ ВЫПОЛНЕНА';heading.style.cssText='margin:0;color:#e7b36c;letter-spacing:2px';
 const stats=document.createElement('p');stats.textContent='ЭТАП '+stage+' · УСТРАНЕНО '+kills+' · ЗДОРОВЬЕ '+health;stats.style.margin='0';
 function action(label,callback,primary=false){const b=document.createElement('button');b.textContent=label;b.style.cssText='padding:14px;border:1px solid #9b8a72;background:'+(primary?'#dba456':'#293a47')+';color:'+(primary?'#14212b':'#f0e7d5')+';font-weight:bold;letter-spacing:1px';b.onclick=callback;panel.append(b)}
 panel.append(heading,stats);
 if(health>0&&mode!=='endless')action('СЛЕДУЮЩАЯ ОПЕРАЦИЯ →',()=>{saveSetting('stage',stage+1);location.reload()},true);
 action('ПОВТОРИТЬ МИССИЮ',()=>location.reload(),health<=0);
 action('ГЛАВНОЕ МЕНЮ',()=>{saveSetting('menu','true');location.reload()});
 overlay.append(panel);document.body.append(overlay);
}
let running3d=true,frames=0,slowFrames=0,fpsWindowStart=performance.now();let pausedBySystem=false,pausedByPlayer=false;
const pauseButton=document.getElementById('pause3d'),pauseOverlay=document.createElement('div');
pauseOverlay.style.cssText='position:fixed;inset:0;z-index:10;display:none;align-items:center;justify-content:center;background:linear-gradient(115deg,#0a1420f5,#263846eb);color:#f1e6ce;font:bold 20px Arial;flex-direction:column;gap:16px;padding:24px;text-align:center';
const pauseTitle=document.createElement('div');pauseTitle.textContent='ОПЕРАЦИЯ ПРИОСТАНОВЛЕНА';pauseTitle.style.cssText='font-size:clamp(18px,4vw,30px);letter-spacing:3px;color:#e6b65b';
const pauseDetails=document.createElement('div');pauseDetails.style.cssText='font:12px Arial;color:#b9c8cf;letter-spacing:2px';pauseDetails.textContent='ТАКТИЧЕСКИЙ РЕЖИМ · 3D';
const resumeButton=document.createElement('button');resumeButton.textContent='ПРОДОЛЖИТЬ';resumeButton.style.cssText='padding:16px 24px;background:#d9a75e;color:#14202a;border:0;font-weight:bold';
const pausePanel=document.createElement('div');pausePanel.style.cssText='display:flex;flex-direction:column;gap:12px;width:min(350px,92vw);padding:22px;border:1px solid #8da0a866;background:#12202bea;box-shadow:0 12px 50px #0008';
const pauseStats=document.createElement('div');pauseStats.style.cssText='font:13px Arial;color:#c5d1d7;letter-spacing:1px';
const pauseQuality=document.createElement('button');pauseQuality.style.cssText='padding:13px;background:#273b49;color:#e5d7b9;border:1px solid #708795;font-weight:bold';
pauseQuality.onclick=()=>{quality=quality==='low'?'balanced':quality==='balanced'?'high':'low';saveSetting('quality',quality);applyQuality();pauseQuality.textContent='ГРАФИКА: '+quality.toUpperCase();qualityButton.textContent='ГРАФИКА: '+quality.toUpperCase()};
const hudSettings=document.createElement('div');hudSettings.style.cssText='display:flex;gap:8px;flex-wrap:wrap;justify-content:center';
const radarToggle=document.createElement('button'),crosshairToggle=document.createElement('button'),fpsToggle=document.createElement('button');
for(const button of [radarToggle,crosshairToggle,fpsToggle])button.style.cssText='flex:1;min-width:115px;padding:12px 8px;background:#273b49;color:#e5d7b9;border:1px solid #708795;font-size:12px;font-weight:bold';
const radarElement=document.getElementById('radar'),crosshairElement=document.getElementById('crosshair');
let showRadar=readSetting('radar','true')!=='false',showCrosshair=readSetting('crosshair','true')!=='false',showFPS=readSetting('fps','false')==='true';
const fpsMeter=document.getElementById('fpsmeter');
function syncHudToggles(){radarToggle.textContent='РАДАР: '+(showRadar?'ВКЛ':'ВЫКЛ');crosshairToggle.textContent='ПРИЦЕЛ: '+(showCrosshair?'ВКЛ':'ВЫКЛ');radarElement.style.display=showRadar?'':'none';crosshairElement.style.display=showCrosshair?'':'none';fpsToggle.textContent='FPS: '+(showFPS?'ВКЛ':'ВЫКЛ');fpsMeter.style.display=showFPS?'block':'none'}
radarToggle.onclick=()=>{showRadar=!showRadar;saveSetting('radar',showRadar);syncHudToggles()};
crosshairToggle.onclick=()=>{showCrosshair=!showCrosshair;saveSetting('crosshair',showCrosshair);syncHudToggles()};
fpsToggle.onclick=()=>{showFPS=!showFPS;saveSetting('fps',showFPS);syncHudToggles()};
hudSettings.append(radarToggle,crosshairToggle,fpsToggle);syncHudToggles();
const pauseRestart=document.createElement('button');pauseRestart.textContent='НАЧАТЬ ЗАНОВО';pauseRestart.style.cssText='padding:13px;background:#24313a;color:#d4c9ba;border:1px solid #566977;font-weight:bold';pauseRestart.onclick=()=>location.reload();
resumeButton.style.cssText='padding:15px;background:#dcae62;color:#15202a;border:0;font-weight:900;letter-spacing:1px';
pausePanel.append(pauseTitle,pauseDetails,pauseStats,resumeButton,pauseQuality,hudSettings,pauseRestart);pauseOverlay.append(pausePanel);document.body.append(pauseOverlay);
function togglePause(){if(ended)return;pausedByPlayer=!pausedByPlayer;pauseOverlay.style.display=pausedByPlayer?'flex':'none';if(pausedByPlayer){pauseStats.textContent='ЗДОРОВЬЕ '+health+'  |  БРОНЯ '+armor+'  |  ЦЕЛИ '+kills+'/'+targetLabel();pauseQuality.textContent='ГРАФИКА: '+quality.toUpperCase()}pauseButton.textContent=pausedByPlayer?'▶':'Ⅱ';move.x=move.y=0;pointer=null;knob.style.transform='';keys.clear();clock.getDelta();fpsWindowStart=performance.now();frames=0}
pauseButton.addEventListener('click',togglePause);resumeButton.addEventListener('click',togglePause);
function frame(){
 if(!running3d)return;
 requestAnimationFrame(frame);
 if(document.hidden){pausedBySystem=true;return}if(pausedByPlayer){clock.getDelta();fpsWindowStart=performance.now();frames=0;return}
 if(pausedBySystem){clock.getDelta();fpsWindowStart=performance.now();frames=0;pausedBySystem=false}
 try{
  update();
  if(showRadar&&performance.now()-radarLastDraw>90){drawRadar();radarLastDraw=performance.now()}
  renderer.render(scene,camera);
  frames++;
  if(frames>=90){
   const now=performance.now();const fps=frames/Math.max((now-fpsWindowStart)/1000,.001);if(showFPS){fpsMeter.textContent='FPS '+Math.round(fps);fpsMeter.style.color=fps<25?'#e6a06f':'#a6cfad'}
   slowFrames=fps<23?slowFrames+1:Math.max(0,slowFrames-1);
   if(slowFrames>=2&&quality!=='low'){
    quality=quality==='high'?'balanced':'low';applyQuality();
    qualityButton.textContent='ГРАФИКА: '+quality.toUpperCase()+' (АВТО)';
    slowFrames=0;
  }
  frames=0;fpsWindowStart=now;
  }
 }catch(error){
  running3d=false;
  console.error('3D runtime failure',error);
  const failure=document.createElement('div');
  failure.style.cssText='position:fixed;inset:0;z-index:20;display:flex;align-items:center;justify-content:center;background:#101923;color:#f4e6c7;padding:20px;text-align:center;font:15px Arial';
  const panel=document.createElement('div');
  const title=document.createElement('h2');title.textContent='ОШИБКА 3D-ИГРЫ';
  const details=document.createElement('p');details.textContent=String(error&&error.message||error);
  const button=document.createElement('button');button.textContent='ПОВТОРИТЬ ЗАПУСК';button.style.cssText='padding:14px;background:#e4b369;color:#101923';button.onclick=()=>location.reload();
  panel.append(title,details,button);failure.append(panel);document.body.append(failure);
 }
}addEventListener('resize',()=>{camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();applyQuality()});const qualityButton=document.createElement('button');qualityButton.textContent='ГРАФИКА: '+quality.toUpperCase();qualityButton.setAttribute('aria-label','Изменить качество 3D-графики');Object.assign(qualityButton.style,{position:'fixed',top:'calc(env(safe-area-inset-top,0px) + 100px)',right:'8px',zIndex:'4',background:'#17242de8',color:'#e6b65b',border:'1px solid #8da0a866',padding:'7px',fontSize:'10px',letterSpacing:'1px'});qualityButton.onclick=()=>{quality=quality==='low'?'balanced':quality==='balanced'?'high':'low';saveSetting('quality',quality);applyQuality();qualityButton.textContent='ГРАФИКА: '+quality.toUpperCase()};document.body.append(qualityButton);
renderer.domElement.addEventListener('webglcontextlost',event=>{
 event.preventDefault();running3d=false;
 loading.textContent='Потеряно соединение с 3D-видеоускорителем. Перезапусти игру.';
 document.body.append(loading);
});
renderer.domElement.addEventListener('webglcontextrestored',()=>location.reload());
document.addEventListener('visibilitychange',()=>{if(document.hidden){move.x=move.y=0;pointer=null;knob.style.transform='';keys.clear();pausedBySystem=true}});
frame();
if(running3d)loading.remove();
const mainMenu=document.createElement('div');mainMenu.id='mainMenu3d';
mainMenu.style.cssText='position:fixed;inset:0;z-index:15;display:flex;flex-direction:column;background:linear-gradient(95deg,#101822f8 0%,#1b2b39e8 54%,#101720d9 100%);color:#f0e8dc;font:14px Arial;overflow:auto';
const menuNav=document.createElement('div');menuNav.style.cssText='display:flex;align-items:center;gap:clamp(8px,2.5vw,26px);padding:12px clamp(18px,4vw,52px);background:#101923ee;border-bottom:1px solid #77899766;flex-wrap:wrap';
const menuBrand=document.createElement('strong');menuBrand.textContent='ОТПУСК / TACTICAL';menuBrand.style.cssText='font-size:clamp(15px,2vw,22px);color:#e5ad5b;letter-spacing:2px;margin-right:clamp(5px,3vw,32px)';
menuNav.append(menuBrand);
const menuBody=document.createElement('div');menuBody.style.cssText='flex:1;display:flex;align-items:center;gap:clamp(20px,4vw,70px);padding:clamp(18px,4vw,52px);min-height:0';
const menuPanel=document.createElement('div');menuPanel.style.cssText='width:min(100%,520px);display:flex;flex-direction:column;gap:12px;max-height:100%;overflow:auto';
const menuArt=document.createElement('div');menuArt.style.cssText='flex:1;min-width:0;align-self:stretch;display:flex;align-items:center;justify-content:center;opacity:.9;pointer-events:none';
const artCanvas=document.createElement('canvas');artCanvas.width=520;artCanvas.height=480;artCanvas.style.cssText='width:min(100%,520px);max-height:100%;object-fit:contain';
const ac=artCanvas.getContext('2d');
if(ac){ac.strokeStyle='#d4a45b';ac.lineWidth=3;ac.beginPath();ac.arc(260,205,105,0,Math.PI*2);ac.stroke();ac.fillStyle='#32495a';ac.fillRect(185,150,150,175);ac.fillStyle='#425c6e';ac.fillRect(215,100,90,90);ac.fillStyle='#131f29';ac.fillRect(225,145,70,28);ac.fillStyle='#d6a85e';ac.fillRect(239,155,42,6);ac.fillStyle='#233440';ac.fillRect(142,195,236,35);ac.fillStyle='#a8b8c0';ac.font='bold 17px Arial';ac.fillText('ОПЕРАТИВНИК · СЕКТОР A',123,360);ac.font='12px Arial';ac.fillText('TACTICAL OPERATIONS / FIELD UNIT',145,383)}
menuArt.append(artCanvas);menuBody.append(menuPanel,menuArt);
function menuButton(label,click,primary=false){const b=document.createElement('button');b.textContent=label;b.style.cssText='text-align:left;padding:14px 18px;background:'+(primary?'#dda75b':'#273a49dd')+';border:1px solid #8494a0;color:'+(primary?'#13212b':'#eee6da')+';font-weight:800;letter-spacing:1px';b.onclick=click;menuPanel.append(b)}
function heading(label,detail){const h=document.createElement('h2');h.textContent=label;h.style.cssText='font-size:clamp(22px,3vw,36px);margin:4px 0;color:#f0e8dc';const p=document.createElement('p');p.textContent=detail;p.style.cssText='color:#afbfca;line-height:1.5;margin:0 0 14px';menuPanel.append(h,p)}
function renderMenu(tab){menuPanel.replaceChildren();for(const button of menuNav.querySelectorAll('button')){button.style.color=button.dataset.tab===tab?'#e8b15c':'#d6e0e6';button.style.borderBottom=button.dataset.tab===tab?'3px solid #e8b15c':'3px solid transparent'}
if(tab==='play'){heading('ВЫБОР ОПЕРАЦИИ','Кампания · сектор A · этап '+stage+' · '+targetLabel()+' целей');
menuButton('▶  ПРОДОЛЖИТЬ КАМПАНИЮ',()=>{saveSetting('mode','campaign');saveSetting('menu','false');location.reload()},true);
menuButton('∞  БЕСКОНЕЧНЫЙ РЕЖИМ',()=>{saveSetting('mode','endless');saveSetting('menu','false');location.reload()});
menuButton('↻  НАЧАТЬ КАМПАНИЮ СНАЧАЛА',()=>{saveSetting('stage','1');saveSetting('mode','campaign');saveSetting('menu','false');location.reload()});
}else if(tab==='brief'){heading('БРИФИНГ · СЕКТОР A','Операция «Зачистка». Связь с разведгруппой потеряна. В заброшенном секторе обнаружены вооружённые отряды.');
const p=document.createElement('p');p.textContent='Цель: нейтрализовать противников, удержать позицию и перейти к следующему этапу. В бесконечном режиме сопротивление продолжается без финальной волны.';p.style.cssText='color:#d1d9dc;line-height:1.7';menuPanel.append(p);
menuButton('ПЕРЕЙТИ К ОПЕРАЦИЯМ',()=>renderMenu('play'),true);
}else if(tab==='settings'){heading('НАСТРОЙКИ','Графика и параметры отображения');
menuButton('КАЧЕСТВО: '+quality.toUpperCase(),()=>{quality=quality==='low'?'balanced':quality==='balanced'?'high':'low';saveSetting('quality',quality);applyQuality();renderMenu('settings')},true);
menuButton('РАДАР: '+(showRadar?'ВКЛ':'ВЫКЛ'),()=>{showRadar=!showRadar;saveSetting('radar',showRadar);syncHudToggles();renderMenu('settings')});
menuButton('ПРИЦЕЛ: '+(showCrosshair?'ВКЛ':'ВЫКЛ'),()=>{showCrosshair=!showCrosshair;saveSetting('crosshair',showCrosshair);syncHudToggles();renderMenu('settings')});
menuButton('FPS: '+(showFPS?'ВКЛ':'ВЫКЛ'),()=>{showFPS=!showFPS;saveSetting('fps',showFPS);syncHudToggles();renderMenu('settings')});
}}
for(const [tab,label] of [['play','ИГРАТЬ'],['brief','БРИФИНГ'],['settings','НАСТРОЙКИ']]){const b=document.createElement('button');b.dataset.tab=tab;b.textContent=label;b.style.cssText='background:transparent;border:0;border-bottom:3px solid transparent;padding:10px 4px;color:#d6e0e6;font-weight:800;letter-spacing:1px';b.onclick=()=>renderMenu(tab);menuNav.append(b)}
mainMenu.append(menuNav,menuBody);document.body.append(mainMenu);renderMenu('play');
pausedByPlayer=true;
killsEl.textContent='0 / '+targetLabel();document.getElementById('mission').textContent=mode==='endless'?'БЕСКОНЕЧНАЯ ОПЕРАЦИЯ':'ОПЕРАЦИЯ · ЭТАП '+stage;
if(readSetting('menu','true')==='false'){mainMenu.remove();pausedByPlayer=false}else saveSetting('menu','false');

