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
let renderer;try{renderer=new THREE.WebGLRenderer({antialias:true,powerPreference:'high-performance'});}catch(e){loading.textContent="WebGL недоступен на этом устройстве. Требуется поддержка 3D.";throw e}
const mobile=/Android|iPhone|iPad/i.test(navigator.userAgent);let quality=mobile?'balanced':'high';function applyQuality(){renderer.setPixelRatio(Math.min(devicePixelRatio,quality==='high'?1.5:quality==='balanced'?1.15:.85));renderer.shadowMap.enabled=quality!=='low';renderer.shadowMap.type=THREE.PCFSoftShadowMap;renderer.setSize(innerWidth,innerHeight)}applyQuality();renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.4;document.body.prepend(renderer.domElement);
const scene=new THREE.Scene();scene.background=new THREE.Color(0x0c1826);scene.fog=new THREE.FogExp2(0x0c1826,.022);
const camera=new THREE.PerspectiveCamera(58,innerWidth/innerHeight,.1,150);
scene.add(new THREE.HemisphereLight(0x9ed8ff,0x16202b,1.8));
const sun=new THREE.DirectionalLight(0xd6e9ff,2.6);sun.position.set(-7,15,8);sun.castShadow=true;sun.shadow.mapSize.set(1024,1024);sun.shadow.camera.left=-25;sun.shadow.camera.right=25;sun.shadow.camera.top=25;sun.shadow.camera.bottom=-25;scene.add(sun);
function mat(color,roughness=.7,metalness=.15){return new THREE.MeshStandardMaterial({color,roughness,metalness})}
const floor=mat(0x344452,.85),wall=mat(0x607482),metal=mat(0x223544,.42,.65),amber=new THREE.MeshStandardMaterial({color:0xffc477,emissive:0xd97d21,emissiveIntensity:1.8}),cyan=new THREE.MeshStandardMaterial({color:0x77e5ff,emissive:0x147eaa,emissiveIntensity:1.6}),red=mat(0x8b4149);
function box(w,h,d,x,y,z,m,solid=false){const mesh=new THREE.Mesh(new THREE.BoxGeometry(w,h,d),m);mesh.position.set(x,y,z);mesh.castShadow=true;mesh.receiveShadow=true;scene.add(mesh);if(solid)obstacles.push({x,z,w,d});return mesh}
const obstacles=[];box(32,.3,34,0,-.2,0,floor);for(let x=-15;x<=15;x+=2){box(.025,.01,34,x,-.025,0,metal);box(32,.01,.025,0,-.025,x,metal)}
box(32,5,.7,0,2.5,-17,wall);box(32,5,.7,0,2.5,17,wall);box(.7,5,34,-16,2.5,0,wall);box(.7,5,34,16,2.5,0,wall);
for(let i=0;i<8;i++){let x=-11+(i%4)*7.3,z=-9+Math.floor(i/4)*17;box(3,1.3,2.4,x,.65,z,metal,true);box(2.6,.08,2,x,1.35,z,wall);if(i===0||i===3){const propAnchor=new THREE.Group();propAnchor.position.set(x,1.38,z);scene.add(propAnchor);loadModel('./models/crate.gltf',propAnchor,{height:1.05,offsetY:0})}box(.7,.9,.09,x,1.95,z-.7,cyan);if(i%4===0){const light=new THREE.PointLight(0x63cfff,5,8,2);light.position.set(x,2.3,z-.7);scene.add(light)}}
for(let i=0;i<6;i++){let x=-12+i*4.8;box(2.8,.09,.4,x,4.7,0,amber);if(i%3===0){const light=new THREE.PointLight(0xffdca6,7,12,2);light.position.set(x,4.25,0);scene.add(light)}}
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
// Segment versus expanded AABB: cover blocks projectiles and targeting.
function blocked(ax,az,bx,bz,pad=0){
 for(const o of obstacles){const minX=o.x-o.w/2-pad,maxX=o.x+o.w/2+pad,minZ=o.z-o.d/2-pad,maxZ=o.z+o.d/2+pad;let t0=0,t1=1,dx=bx-ax,dz=bz-az;
  for(const [start,delta,lo,hi] of [[ax,dx,minX,maxX],[az,dz,minZ,maxZ]]){if(Math.abs(delta)<1e-7){if(start<lo||start>hi){t0=2;break}}else{let a=(lo-start)/delta,b=(hi-start)/delta;if(a>b)[a,b]=[b,a];t0=Math.max(t0,a);t1=Math.min(t1,b)}}
  if(t0<=t1&&t0<=1&&t1>=0)return true
 }return false
}
const bullets=[];let health=100,kills=0,fire=0,invuln=0,ended=false;const damageOverlay=document.createElement('div');damageOverlay.style.cssText='position:fixed;inset:0;z-index:2;pointer-events:none;background:radial-gradient(ellipse at center,transparent 40%,#c71928 100%);opacity:0;transition:opacity 90ms';document.body.append(damageOverlay);const move={x:0,y:0},stick=document.getElementById('stick'),knob=document.getElementById('knob');let pointer=null;
function joystick(e){let r=stick.getBoundingClientRect(),x=e.clientX-(r.left+r.width/2),y=e.clientY-(r.top+r.height/2),len=Math.hypot(x,y),v=Math.min(1,len/47);move.x=len?x/len*v:0;move.y=len?y/len*v:0;knob.style.transform='translate('+move.x*39+'px,'+move.y*39+'px)'}
stick.addEventListener('pointerdown',e=>{pointer=e.pointerId;stick.setPointerCapture(pointer);joystick(e)});stick.addEventListener('pointermove',e=>{if(e.pointerId===pointer)joystick(e)});function release(e){if(e.pointerId===pointer){pointer=null;move.x=move.y=0;knob.style.transform=''}}stick.addEventListener('pointerup',release);stick.addEventListener('pointercancel',release);
const keys=new Set();addEventListener('keydown',e=>keys.add(e.key.toLowerCase()));addEventListener('keyup',e=>keys.delete(e.key.toLowerCase()));
let dash=0;document.getElementById('dash').addEventListener('pointerdown',()=>dash=0.23);
function canMove(x,z){return Math.abs(x)<15.1&&Math.abs(z)<16.1&&!obstacles.some(o=>Math.abs(x-o.x)<o.w/2+.55&&Math.abs(z-o.z)<o.d/2+.55)}
const clock=new THREE.Clock(),spark=new THREE.SphereGeometry(.12,6,6);let elapsed=0;const tempColor=new THREE.Color();function projectile(from,to,enemy){let v=to.clone().sub(from).normalize(),mesh=new THREE.Mesh(spark,enemy?amber:cyan);mesh.position.copy(from);scene.add(mesh);bullets.push({mesh,v,enemy,ttl:1.3})}
function update(){let dt=Math.min(clock.getDelta(),.04);elapsed+=dt;for(const item of animationMixers){if(item.owner.parent)item.mixer.update(dt)}if(ended)return;invuln=Math.max(0,invuln-dt);damageOverlay.style.opacity=String(Math.min(.62,Math.max(0,invuln-.12)*.95));let mx=move.x+(keys.has('d')?1:0)-(keys.has('a')?1:0),mz=move.y+(keys.has('s')?1:0)-(keys.has('w')?1:0),l=Math.hypot(mx,mz);if(l>1){mx/=l;mz/=l}let speed=dash>0?15:6;dash=Math.max(0,dash-dt);hero.userData.motion=(hero.userData.motion||0)+dt*Math.max(0,l)*11;const running=l>.08;hero.position.y=running?Math.abs(Math.sin(hero.userData.motion))*.07:Math.sin(elapsed*2)*.014;let nx=hero.position.x+mx*speed*dt,nz=hero.position.z+mz*speed*dt;if(canMove(nx,hero.position.z))hero.position.x=nx;if(canMove(hero.position.x,nz))hero.position.z=nz;
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
}e.lookAt(hero.position.x,0,hero.position.z);e.userData.motion=(e.userData.motion||0)+dt*7;e.position.y=Math.abs(Math.sin(e.userData.motion))*.035;e.userData.cool-=dt;if(d<2&&!blocked(e.position.x,e.position.z,hero.position.x,hero.position.z,.06)&&e.userData.cool<=0){e.userData.cool=1.25;if(invuln<=0){health=Math.max(0,health-12);invuln=.6;hpEl.textContent='HP '+health;damageOverlay.style.opacity='.62'}}}
fire-=dt;if(closest&&dist<22&&fire<=0){fire=.28;hero.lookAt(closest.position.x,0,closest.position.z);projectile(hero.position.clone().add(new THREE.Vector3(0,1.35,0)),closest.position.clone().add(new THREE.Vector3(0,1.2,0)),false)}
for(let i=bullets.length-1;i>=0;i--){let b=bullets[i];b.mesh.position.addScaledVector(b.v,dt*28);b.ttl-=dt;let wallHit=blocked(b.mesh.position.x-b.v.x*dt*28,b.mesh.position.z-b.v.z*dt*28,b.mesh.position.x,b.mesh.position.z,.05);let hit=wallHit?null:enemies.find(e=>Math.hypot(e.position.x-b.mesh.position.x,e.position.z-b.mesh.position.z)<.9);if(wallHit)b.ttl=0;if(hit){hit.userData.hp--;hit.userData.flash=.15;b.ttl=0;if(hit.userData.hp<=0){scene.remove(hit);for(let j=animationMixers.length-1;j>=0;j--)if(animationMixers[j].owner===hit)animationMixers.splice(j,1);enemies.splice(enemies.indexOf(hit),1);kills++;killsEl.textContent=kills+' / 12';if(kills<12&&enemies.length<5)spawn()}}if(b.ttl<=0){scene.remove(b.mesh);bullets.splice(i,1)}}
for(const e of enemies){e.userData.flash=Math.max(0,(e.userData.flash||0)-dt);e.traverse(o=>{if(o.isMesh&&o.material&&!Array.isArray(o.material)&&o.material.emissive){if(!o.userData.baseEmissive){o.userData.baseEmissive=o.material.emissive.clone();o.userData.baseIntensity=o.material.emissiveIntensity}o.material.emissive.copy(e.userData.flash>0?tempColor.set(0xff4937):o.userData.baseEmissive);o.material.emissiveIntensity=e.userData.flash>0?1.6:o.userData.baseIntensity}})}camera.position.lerp(new THREE.Vector3(hero.position.x+0,hero.position.y+15,hero.position.z+19),Math.min(1,dt*5));camera.lookAt(hero.position.x,1,hero.position.z-3);
if(health<=0||kills>=12){ended=true;msg.textContent=health<=0?'МИССИЯ ПРОВАЛЕНА':'МИССИЯ ВЫПОЛНЕНА!';showRestart()}}
function showRestart(){
 if(document.getElementById('restart3d'))return;
 const btn=document.createElement('button');btn.id='restart3d';btn.textContent='ИГРАТЬ СНОВА';
 Object.assign(btn.style,{position:'fixed',top:'50%',left:'50%',transform:'translate(-50%,-50%)',zIndex:'4',padding:'18px 24px',background:'#d5a25d',color:'#15202a',border:'2px solid #fbe3b1',fontWeight:'bold',fontSize:'17px'});
 btn.onclick=()=>location.reload();document.body.append(btn)
}
let running3d=true,frames=0,slowFrames=0,fpsWindowStart=performance.now();let pausedBySystem=false;
function frame(){
 if(!running3d)return;
 requestAnimationFrame(frame);
 if(document.hidden){pausedBySystem=true;return}
 if(pausedBySystem){clock.getDelta();fpsWindowStart=performance.now();frames=0;pausedBySystem=false}
 try{
  update();
  renderer.render(scene,camera);
  frames++;
  if(frames>=90){
   const now=performance.now();const fps=frames/Math.max((now-fpsWindowStart)/1000,.001);
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
}addEventListener('resize',()=>{camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();applyQuality()});const qualityButton=document.createElement('button');qualityButton.textContent='ГРАФИКА: '+quality.toUpperCase();Object.assign(qualityButton.style,{position:'fixed',top:'54px',right:'12px',zIndex:'3',background:'#172838d9',color:'#f4d49d',border:'1px solid #b6c7d2',padding:'8px',fontSize:'11px'});qualityButton.onclick=()=>{quality=quality==='low'?'balanced':quality==='balanced'?'high':'low';applyQuality();qualityButton.textContent='ГРАФИКА: '+quality.toUpperCase()};document.body.append(qualityButton);
renderer.domElement.addEventListener('webglcontextlost',event=>{
 event.preventDefault();running3d=false;
 loading.textContent='Потеряно соединение с 3D-видеоускорителем. Перезапусти игру.';
 document.body.append(loading);
});
renderer.domElement.addEventListener('webglcontextrestored',()=>location.reload());
document.addEventListener('visibilitychange',()=>{if(document.hidden){move.x=move.y=0;knob.style.transform='';keys.clear();pausedBySystem=true}});
frame();
if(running3d)loading.remove();
