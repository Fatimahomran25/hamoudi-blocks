// عالم اللعب ثلاثي الأبعاد — "بلوك حمودي" (Milestone 2).
//
// شخصية بلوكية تُتحكَّم بجويستيك لمسي حر الحركة داخل أرضية محاطة بسياج،
// تبحث بين 4 منصّات موزعة عشوائياً (360°) عن الحرف/الرقم الصحيح. نظام
// قلوب (3)، تلميح اتجاه بعد 9 ثواني، احتفال + نجمة عند الإصابة، وقفة
// ودّية عند الخطأ. راجعي قسم "آلية اللعب" بالبرومت الأصلي لتفاصيل التصميم.
//
// جسر التواصل مع Flutter (طرفه الآخر بـ lib/screens/game/game_screen.dart):
//   Flutter → الصفحة: window.HamoudiGame.init(config) بعد استقبال {type:'ready'}.
//   الصفحة → Flutter: GameChannel.postMessage(JSON.stringify(msg)) لكل من:
//     {type:'ready'}
//     {type:'audio', event:'...', symbol?, direction?}
//     {type:'result', outcome:'win', heartsRemaining} | {outcome:'retry', roundIndex}
//     {type:'exit'}

import * as THREE from './vendor/three.module.js';

// ============================== الجسر (Bridge) ==============================

const Bridge = {
  send(msg) {
    try {
      if (window.GameChannel && typeof window.GameChannel.postMessage === 'function') {
        window.GameChannel.postMessage(JSON.stringify(msg));
      } else if (window.location.search.includes('debug=1')) {
        // eslint-disable-next-line no-console
        console.log('[bridge]', msg);
      }
    } catch (err) {
      // eslint-disable-next-line no-console
      console.warn('bridge send failed', err);
    }
  },
  audio(event, extra) {
    Bridge.send({ type: 'audio', event, ...extra });
  },
};

// ============================== الثوابت ==============================

const ARENA_RADIUS = 17.5; // حد السياج — الشخصية ما تتعدّاه.
const PEDESTAL_MIN_RADIUS = 6;
const PEDESTAL_MAX_RADIUS = 13;
const MOVE_SPEED = 6.4; // وحدات/ثانية
const JUMP_VELOCITY = 8.5;
const GRAVITY = 24;
const HIT_RADIUS = 1.9; // مسافة "اللمس" بين اللاعب والمنصّة
const HEART_START = 3;
const HINT_DELAY_MS = 9000;
const IDLE_DELAY_MS = 2600;

const COLORS = {
  red: 0xe2231a,
  blue: 0x2e86ff,
  yellow: 0xffd23f,
  green: 0x34c759,
  purple: 0x9b5de5,
  orange: 0xff8a3d,
  ink: 0x14141a,
};

const PLATE_PALETTE = [COLORS.blue, COLORS.purple, COLORS.orange, COLORS.green];

// ============================== حالة اللعبة ==============================

/** @type {{childName:string, avatar:{jacket:string,skin:string,hair:string}, items:Array<{symbol:string,exampleWord:string,emoji:string}>, resumeAt:number}} */
let config = null;

const state = {
  hearts: HEART_START,
  roundIndex: 0,
  pedestals: [], // {mesh, plate, item, isTarget, baseY}
  target: null,
  roundActive: false,
  inputLocked: false,
  isJumping: false,
  velocityY: 0,
  lastMoveAt: 0,
  nextIdleAt: 0,
  playingIdle: false,
  invulnerableUntil: 0,
  lastHintAt: 0,
  roundStartedAt: 0,
};

// ============================== إعداد المشهد ==============================

const canvas = document.getElementById('game-canvas');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'low-power' });
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));

const scene = new THREE.Scene();
scene.background = new THREE.Color(0x8fd3ff);
scene.fog = new THREE.Fog(0x8fd3ff, 26, 46);

const camera = new THREE.PerspectiveCamera(58, window.innerWidth / window.innerHeight, 0.1, 100);
const CAMERA_OFFSET = new THREE.Vector3(0, 7.5, 9.5);
camera.position.copy(CAMERA_OFFSET);

const ambient = new THREE.AmbientLight(0xffffff, 0.75);
scene.add(ambient);
const sun = new THREE.DirectionalLight(0xffffff, 0.9);
sun.position.set(8, 14, 6);
scene.add(sun);

function resize() {
  const w = window.innerWidth;
  const h = window.innerHeight;
  renderer.setSize(w, h);
  camera.aspect = w / h;
  camera.updateProjectionMatrix();
}
window.addEventListener('resize', resize);
resize();

// ----- الأرضية (checkerboard خفيف عبر تكستشر بدل مئات المضلعات) -----

function buildGroundTexture() {
  const size = 128;
  const cvs = document.createElement('canvas');
  cvs.width = cvs.height = size;
  const ctx = cvs.getContext('2d');
  const light = '#3fbf6a';
  const dark = '#34a85c';
  const tiles = 8;
  const step = size / tiles;
  for (let y = 0; y < tiles; y++) {
    for (let x = 0; x < tiles; x++) {
      ctx.fillStyle = (x + y) % 2 === 0 ? light : dark;
      ctx.fillRect(x * step, y * step, step, step);
    }
  }
  const tex = new THREE.CanvasTexture(cvs);
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.repeat.set(6, 6);
  tex.magFilter = THREE.NearestFilter;
  return tex;
}

const ground = new THREE.Mesh(
  new THREE.PlaneGeometry(60, 60),
  new THREE.MeshLambertMaterial({ map: buildGroundTexture() }),
);
ground.rotation.x = -Math.PI / 2;
scene.add(ground);

// ----- السياج المحيط -----

const fenceGroup = new THREE.Group();
const FENCE_POSTS = 30;
for (let i = 0; i < FENCE_POSTS; i++) {
  const angle = (i / FENCE_POSTS) * Math.PI * 2;
  const post = new THREE.Mesh(
    new THREE.BoxGeometry(0.5, 1.4, 0.5),
    new THREE.MeshLambertMaterial({ color: i % 2 === 0 ? COLORS.red : 0xffffff }),
  );
  post.position.set(Math.cos(angle) * ARENA_RADIUS, 0.7, Math.sin(angle) * ARENA_RADIUS);
  fenceGroup.add(post);
}
scene.add(fenceGroup);

// ----- عناصر خلفية متحركة (غيوم + طيور) -----

function buildCloud() {
  const group = new THREE.Group();
  const mat = new THREE.MeshLambertMaterial({ color: 0xffffff });
  const puffs = 3 + Math.floor(Math.random() * 2);
  for (let i = 0; i < puffs; i++) {
    const puff = new THREE.Mesh(new THREE.BoxGeometry(2.2, 1.4, 1.6), mat);
    puff.position.set(i * 1.6 - puffs * 0.6, Math.random() * 0.4, Math.random() * 0.4);
    group.add(puff);
  }
  return group;
}

const clouds = [];
for (let i = 0; i < 4; i++) {
  const cloud = buildCloud();
  cloud.position.set((Math.random() - 0.5) * 50, 14 + Math.random() * 4, (Math.random() - 0.5) * 50);
  cloud.userData.speed = 0.25 + Math.random() * 0.25;
  clouds.push(cloud);
  scene.add(cloud);
}

function buildBird() {
  const bird = new THREE.Mesh(
    new THREE.ConeGeometry(0.35, 1, 3),
    new THREE.MeshLambertMaterial({ color: COLORS.ink }),
  );
  bird.rotation.z = Math.PI / 2;
  return bird;
}

const birds = [];
for (let i = 0; i < 3; i++) {
  const bird = buildBird();
  bird.userData.radius = 16 + Math.random() * 8;
  bird.userData.speed = 0.35 + Math.random() * 0.25;
  bird.userData.height = 9 + Math.random() * 3;
  bird.userData.offset = Math.random() * Math.PI * 2;
  birds.push(bird);
  scene.add(bird);
}

// ============================== الشخصية البلوكية ==============================

function hexToColor(hex, fallback) {
  if (!hex) return fallback;
  return new THREE.Color(hex);
}

/** يبني شخصية بلوكية (رأس+جسم+ذراعين+رجلين) بألوان avatar المُعطاة.
 * التركيب من الأرض للأعلى: رجلين (pivot بالورك) → جذع → ذراعين
 * (pivot بالكتف) → رأس → شعر، عشان القدمين تلمس الأرض بالضبط والأرجل/
 * الذرعان تتأرجح من مفصلها الصحيح وقت الجري بدل مركز الصندوق. */
function buildCharacter(avatar) {
  const jacket = hexToColor(avatar?.jacket, new THREE.Color(COLORS.red));
  const skin = hexToColor(avatar?.skin, new THREE.Color(0xf2c29a));
  const hair = hexToColor(avatar?.hair, new THREE.Color(0x2b1b12));

  const group = new THREE.Group();

  const HIP_Y = 0.9;
  const SHOULDER_Y = 1.9;
  const HEAD_SIZE = 0.7;

  const legGeo = new THREE.BoxGeometry(0.32, 0.9, 0.32);
  legGeo.translate(0, -0.45, 0); // pivot أعلى الساق
  const legMat = new THREE.MeshLambertMaterial({ color: 0x2c2c38 });
  const leftLeg = new THREE.Mesh(legGeo, legMat);
  leftLeg.position.set(-0.22, HIP_Y, 0);
  const rightLeg = new THREE.Mesh(legGeo, legMat);
  rightLeg.position.set(0.22, HIP_Y, 0);
  group.add(leftLeg, rightLeg);

  const torso = new THREE.Mesh(
    new THREE.BoxGeometry(0.82, SHOULDER_Y - HIP_Y, 0.48),
    new THREE.MeshLambertMaterial({ color: jacket }),
  );
  torso.position.y = (HIP_Y + SHOULDER_Y) / 2;
  group.add(torso);

  const armGeo = new THREE.BoxGeometry(0.26, 0.8, 0.26);
  armGeo.translate(0, -0.4, 0); // pivot عند الكتف
  const armMat = new THREE.MeshLambertMaterial({ color: jacket });
  const leftArm = new THREE.Mesh(armGeo, armMat);
  leftArm.position.set(-0.56, SHOULDER_Y, 0);
  const rightArm = new THREE.Mesh(armGeo, armMat);
  rightArm.position.set(0.56, SHOULDER_Y, 0);
  group.add(leftArm, rightArm);

  const head = new THREE.Mesh(
    new THREE.BoxGeometry(HEAD_SIZE, HEAD_SIZE, HEAD_SIZE),
    new THREE.MeshLambertMaterial({ color: skin }),
  );
  head.position.y = SHOULDER_Y + HEAD_SIZE / 2;
  group.add(head);

  const hairMesh = new THREE.Mesh(
    new THREE.BoxGeometry(HEAD_SIZE + 0.04, 0.22, HEAD_SIZE + 0.04),
    new THREE.MeshLambertMaterial({ color: hair }),
  );
  hairMesh.position.y = SHOULDER_Y + HEAD_SIZE + 0.02;
  group.add(hairMesh);

  group.userData.parts = { torso, head, hairMesh, leftArm, rightArm, leftLeg, rightLeg };
  return group;
}

let player = null;
let playerParts = null;

function spawnPlayer() {
  if (player) scene.remove(player);
  player = buildCharacter(config?.avatar);
  player.position.set(0, 0, 0);
  scene.add(player);
  playerParts = player.userData.parts;
}

// ============================== المنصّات (Pedestals) ==============================

function drawPlateTexture(item, colorHex) {
  const size = 256;
  const cvs = document.createElement('canvas');
  cvs.width = cvs.height = size;
  const ctx = cvs.getContext('2d');

  ctx.fillStyle = `#${colorHex.toString(16).padStart(6, '0')}`;
  roundRect(ctx, 8, 8, size - 16, size - 16, 28);
  ctx.fill();
  ctx.lineWidth = 10;
  ctx.strokeStyle = '#14141a';
  roundRect(ctx, 8, 8, size - 16, size - 16, 28);
  ctx.stroke();

  ctx.fillStyle = '#ffffff';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.font = '800 118px "Baloo Bhaijaan 2", sans-serif';
  ctx.fillText(item.symbol, size / 2, size / 2 - 34);

  ctx.font = '700 30px "Baloo Bhaijaan 2", sans-serif';
  ctx.fillText(item.emoji, size / 2, size / 2 + 66);
  ctx.font = '700 22px "Baloo Bhaijaan 2", sans-serif';
  ctx.fillStyle = '#f6f6f9';
  ctx.fillText(item.exampleWord, size / 2, size / 2 + 100);

  const tex = new THREE.CanvasTexture(cvs);
  tex.anisotropy = 2;
  return tex;
}

function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

function buildPedestal(item, isTarget, colorHex) {
  const group = new THREE.Group();

  const stand = new THREE.Mesh(
    new THREE.CylinderGeometry(0.55, 0.65, 1.1, 8),
    new THREE.MeshLambertMaterial({ color: COLORS.ink }),
  );
  stand.position.y = 0.55;
  group.add(stand);

  const plate = new THREE.Mesh(
    new THREE.PlaneGeometry(1.5, 1.5),
    new THREE.MeshBasicMaterial({ map: drawPlateTexture(item, colorHex), transparent: true }),
  );
  plate.position.y = 1.85;
  group.add(plate);

  group.userData.item = item;
  group.userData.isTarget = isTarget;
  group.userData.plate = plate;
  group.userData.bobOffset = Math.random() * Math.PI * 2;
  return group;
}

function clearPedestals() {
  for (const p of state.pedestals) scene.remove(p.mesh);
  state.pedestals = [];
}

/** يوزّع منصّات المستوى الأربع بزاوية عشوائية (360°) ونصف قطر عشوائي حول اللاعب. */
function layoutPedestals(items, targetItem) {
  clearPedestals();
  const count = items.length;
  const sector = (Math.PI * 2) / count;
  const order = [...items].sort(() => Math.random() - 0.5);

  order.forEach((item, i) => {
    const angle = sector * i + Math.random() * (sector * 0.6) - sector * 0.3;
    const radius = PEDESTAL_MIN_RADIUS + Math.random() * (PEDESTAL_MAX_RADIUS - PEDESTAL_MIN_RADIUS);
    const isTarget = item.symbol === targetItem.symbol;
    const colorHex = PLATE_PALETTE[i % PLATE_PALETTE.length];
    const mesh = buildPedestal(item, isTarget, colorHex);
    mesh.position.set(Math.cos(angle) * radius, 0, Math.sin(angle) * radius);
    scene.add(mesh);
    state.pedestals.push({ mesh, item, isTarget });
  });
}

// ============================== الاحتفال (Confetti) ==============================

const confettiPool = [];
function spawnConfetti(position) {
  const colors = [COLORS.red, COLORS.blue, COLORS.yellow, COLORS.green, COLORS.purple, COLORS.orange];
  for (let i = 0; i < 22; i++) {
    const mat = new THREE.SpriteMaterial({ color: colors[i % colors.length], transparent: true });
    const sprite = new THREE.Sprite(mat);
    sprite.scale.set(0.28, 0.28, 0.28);
    sprite.position.copy(position);
    const angle = Math.random() * Math.PI * 2;
    const speed = 2 + Math.random() * 3;
    sprite.userData.velocity = new THREE.Vector3(Math.cos(angle) * speed, 4 + Math.random() * 3, Math.sin(angle) * speed);
    sprite.userData.life = 1.1 + Math.random() * 0.3;
    sprite.userData.age = 0;
    scene.add(sprite);
    confettiPool.push(sprite);
  }
}

function updateConfetti(dt) {
  for (let i = confettiPool.length - 1; i >= 0; i--) {
    const s = confettiPool[i];
    s.userData.age += dt;
    s.userData.velocity.y -= GRAVITY * 0.5 * dt;
    s.position.addScaledVector(s.userData.velocity, dt);
    const t = s.userData.age / s.userData.life;
    s.material.opacity = Math.max(0, 1 - t);
    if (t >= 1) {
      scene.remove(s);
      confettiPool.splice(i, 1);
    }
  }
}

// ============================== الهود (HUD) ==============================

const heartsRowEl = document.getElementById('hearts-row');
const progressTextEl = document.getElementById('progress-text');
const targetSymbolEl = document.getElementById('target-symbol');
const targetWordEl = document.getElementById('target-word');
const targetEmojiEl = document.getElementById('target-emoji');
const speechBubbleEl = document.getElementById('speech-bubble');
const loadingVeilEl = document.getElementById('loading-veil');

function renderHearts() {
  heartsRowEl.textContent = '❤️'.repeat(state.hearts) + '🖤'.repeat(HEART_START - state.hearts);
}

function renderProgress() {
  progressTextEl.textContent = `${Math.min(state.roundIndex + 1, config.items.length)} / ${config.items.length}`;
}

function renderTargetCard(item) {
  targetSymbolEl.textContent = item.symbol;
  targetWordEl.textContent = item.exampleWord;
  targetEmojiEl.textContent = item.emoji;
}

let speechTimer = null;
function showSpeech(text, durationMs = 2600) {
  speechBubbleEl.textContent = text;
  speechBubbleEl.classList.add('visible');
  if (speechTimer) clearTimeout(speechTimer);
  if (durationMs > 0) {
    speechTimer = setTimeout(() => speechBubbleEl.classList.remove('visible'), durationMs);
  }
}

// ============================== الجويستيك ==============================

const joystickBase = document.getElementById('joystick-base');
const joystickKnob = document.getElementById('joystick-knob');
const joystickZone = document.getElementById('joystick-zone');
const moveVector = new THREE.Vector2(0, 0);
let joystickPointerId = null;

function updateJoystickFromEvent(evt) {
  const rect = joystickBase.getBoundingClientRect();
  const cx = rect.left + rect.width / 2;
  const cy = rect.top + rect.height / 2;
  const dx = evt.clientX - cx;
  const dy = evt.clientY - cy;
  const maxR = rect.width / 2;
  const len = Math.hypot(dx, dy);
  const clamped = Math.min(len, maxR);
  const nx = len > 0 ? (dx / len) * clamped : 0;
  const ny = len > 0 ? (dy / len) * clamped : 0;
  joystickKnob.style.transform = `translate(${nx}px, ${ny}px)`;
  moveVector.set(clamp(nx / maxR, -1, 1), clamp(ny / maxR, -1, 1));
}

function resetJoystick() {
  joystickKnob.style.transform = 'translate(0px, 0px)';
  moveVector.set(0, 0);
  joystickPointerId = null;
}

joystickZone.addEventListener('pointerdown', (evt) => {
  if (joystickPointerId !== null) return;
  joystickPointerId = evt.pointerId;
  updateJoystickFromEvent(evt);
});
window.addEventListener('pointermove', (evt) => {
  if (evt.pointerId !== joystickPointerId) return;
  updateJoystickFromEvent(evt);
});
window.addEventListener('pointerup', (evt) => {
  if (evt.pointerId !== joystickPointerId) return;
  resetJoystick();
});
window.addEventListener('pointercancel', (evt) => {
  if (evt.pointerId !== joystickPointerId) return;
  resetJoystick();
});

function clamp(v, min, max) {
  return Math.max(min, Math.min(max, v));
}

// ----- زر القفز -----

const jumpBtn = document.getElementById('jump-btn');
jumpBtn.addEventListener('pointerdown', (evt) => {
  evt.preventDefault();
  tryJump();
});

function tryJump() {
  if (state.isJumping || state.inputLocked) return;
  state.isJumping = true;
  state.velocityY = JUMP_VELOCITY;
  Bridge.audio('jump');
  registerActivity();
}

// ----- تفاعل اللمس المباشر على الشخصية -----

const raycaster = new THREE.Raycaster();
const pointerNdc = new THREE.Vector2();
canvas.addEventListener('pointerdown', (evt) => {
  pointerNdc.set((evt.clientX / window.innerWidth) * 2 - 1, -(evt.clientY / window.innerHeight) * 2 + 1);
  raycaster.setFromCamera(pointerNdc, camera);
  const hits = raycaster.intersectObject(player, true);
  if (hits.length > 0) {
    playRandomFunAnimation();
    registerActivity();
  }
});

// ----- زر الخروج -----

document.getElementById('exit-btn').addEventListener('pointerdown', () => {
  Bridge.audio('ui_tap');
  Bridge.send({ type: 'exit' });
});

// ============================== حركات الشخصية ==============================

function registerActivity() {
  state.lastMoveAt = performance.now();
  state.nextIdleAt = state.lastMoveAt + IDLE_DELAY_MS;
}

let animTime = 0;
function animateLocomotion(dt, moving) {
  animTime += dt;
  const { leftArm, rightArm, leftLeg, rightLeg } = playerParts;
  if (moving && !state.isJumping) {
    const swing = Math.sin(animTime * 9) * 0.55;
    leftLeg.rotation.x = swing;
    rightLeg.rotation.x = -swing;
    leftArm.rotation.x = -swing;
    rightArm.rotation.x = swing;
  } else if (!state.playingIdle) {
    leftLeg.rotation.x = lerpAngle(leftLeg.rotation.x, 0, dt * 6);
    rightLeg.rotation.x = lerpAngle(rightLeg.rotation.x, 0, dt * 6);
    leftArm.rotation.x = lerpAngle(leftArm.rotation.x, 0, dt * 6);
    rightArm.rotation.x = lerpAngle(rightArm.rotation.x, 0, dt * 6);
  }
}

function lerpAngle(a, b, t) {
  return a + (b - a) * Math.min(1, t);
}

/** حركات خمول لطيفة لما الطفل واقف بدون حركة (يلوّح، يقفز قفزة صغيرة، يستدير). */
function playIdleAnimation() {
  if (state.playingIdle || state.inputLocked) return;
  state.playingIdle = true;
  const kinds = ['wave', 'lookAround', 'hop'];
  const kind = kinds[Math.floor(Math.random() * kinds.length)];
  const { rightArm, head } = playerParts;
  const duration = 1000;

  if (kind === 'wave') {
    animateTween(duration, (t) => {
      rightArm.rotation.z = Math.sin(t * Math.PI * 4) * 0.7;
    }, () => { rightArm.rotation.z = 0; state.playingIdle = false; });
  } else if (kind === 'lookAround') {
    animateTween(duration, (t) => {
      head.rotation.y = Math.sin(t * Math.PI * 2) * 0.5;
    }, () => { head.rotation.y = 0; state.playingIdle = false; });
  } else {
    animateTween(420, (t) => {
      player.position.y = Math.sin(t * Math.PI) * 0.35;
    }, () => { player.position.y = 0; state.playingIdle = false; });
  }
  state.nextIdleAt = performance.now() + IDLE_DELAY_MS + Math.random() * 2000;
}

/** حركة مرحة عشوائية عند لمس الشخصية مباشرة (زي مداعبة شخصية أليفة). */
function playRandomFunAnimation() {
  if (state.inputLocked) return;
  state.playingIdle = true;
  const kinds = ['spin', 'doubleHop'];
  const kind = kinds[Math.floor(Math.random() * kinds.length)];
  if (kind === 'spin') {
    animateTween(600, (t) => {
      player.rotation.y = t * Math.PI * 2;
    }, () => { state.playingIdle = false; });
  } else {
    animateTween(500, (t) => {
      player.position.y = Math.abs(Math.sin(t * Math.PI * 2)) * 0.4;
    }, () => { player.position.y = 0; state.playingIdle = false; });
  }
}

/** قفزة احتفال تلقائية عند وصول الحرف الصحيح. */
function playCelebrationHop(onDone) {
  animateTween(700, (t) => {
    player.position.y = Math.abs(Math.sin(t * Math.PI * 1.5)) * 0.9;
    player.rotation.y += 0.08;
  }, () => { player.position.y = 0; onDone && onDone(); });
}

/** طيحة خفيفة + رجوع بسرعة عند لمس منصّة غلط. */
function playStumble(pushDir) {
  state.inputLocked = true;
  const startPos = player.position.clone();
  const endPos = startPos.clone().addScaledVector(pushDir, 1.6);
  clampToArena(endPos);
  animateTween(650, (t) => {
    player.position.lerpVectors(startPos, endPos, easeOutQuad(t));
    player.rotation.z = Math.sin(t * Math.PI) * 0.5;
  }, () => {
    player.rotation.z = 0;
    state.inputLocked = false;
  });
}

function easeOutQuad(t) {
  return 1 - (1 - t) * (1 - t);
}

/** أداة عامة لتحريك قيمة عبر الزمن (بدون مكتبة tween خارجية، خفيفة). */
function animateTween(durationMs, onUpdate, onComplete) {
  const start = performance.now();
  function step(now) {
    const t = Math.min(1, (now - start) / durationMs);
    onUpdate(t);
    if (t < 1) requestAnimationFrame(step);
    else onComplete && onComplete();
  }
  requestAnimationFrame(step);
}

function clampToArena(vec3) {
  const dist = Math.hypot(vec3.x, vec3.z);
  if (dist > ARENA_RADIUS) {
    const scale = ARENA_RADIUS / dist;
    vec3.x *= scale;
    vec3.z *= scale;
  }
}

// ============================== منطق الجولة (Round) ==============================

function startLevel() {
  state.hearts = HEART_START;
  state.roundIndex = clamp(config.resumeAt || 0, 0, config.items.length - 1);
  renderHearts();
  spawnPlayer();
  beginRound();
}

function beginRound() {
  state.target = config.items[state.roundIndex];
  state.roundActive = true;
  state.roundStartedAt = performance.now();
  state.lastHintAt = state.roundStartedAt;
  state.invulnerableUntil = state.roundStartedAt + 400;

  player.position.set(0, 0, 0);
  player.rotation.set(0, 0, 0);

  layoutPedestals(config.items, state.target);
  renderTargetCard(state.target);
  renderProgress();
  showSpeech(`دوّر على ${state.target.symbol}! زي ${state.target.exampleWord} ${state.target.emoji}`, 3200);
  Bridge.audio('level_intro', { symbol: state.target.symbol });
  registerActivity();
}

function handleCorrectTouch(pedestal) {
  state.roundActive = false;
  spawnConfetti(pedestal.mesh.position.clone().add(new THREE.Vector3(0, 1.8, 0)));
  showSpeech(pickPraise(), 2200);
  Bridge.audio('correct_answer');
  playCelebrationHop(() => {
    state.roundIndex += 1;
    if (state.roundIndex >= config.items.length) {
      finishLevel(true);
    } else {
      beginRound();
    }
  });
}

function handleWrongTouch(pedestal) {
  state.hearts -= 1;
  renderHearts();
  showSpeech('ولا يهمك يا حمودي، جرب مرة ثانية! 💛', 2200);
  Bridge.audio('wrong_answer');
  const pushDir = player.position.clone().sub(pedestal.mesh.position).setY(0);
  if (pushDir.lengthSq() < 0.001) pushDir.set(0, 0, 1);
  pushDir.normalize();
  playStumble(pushDir);
  state.invulnerableUntil = performance.now() + 1100;

  if (state.hearts <= 0) {
    state.roundActive = false;
    // مهلة قصيرة عشان الطفل يشوف الطيحة والرسالة الودّية قبل ما ننتقل
    // لشاشة "حاول مرة ثانية" (بدل قطع مفاجئ للانيميشن).
    setTimeout(() => finishLevel(false), 900);
  }
}

const PRAISE = [
  'أحسنت يا بطل! 🌟',
  'برافو عليك! 🎉',
  'يا سلام عليك! ⭐',
  'ممتاز يا حمودي! 🏆',
];
function pickPraise() {
  return PRAISE[Math.floor(Math.random() * PRAISE.length)];
}

function finishLevel(didWin) {
  if (didWin) {
    Bridge.audio('level_win');
    showSpeech('خلّصت المستوى! 🎉', 0);
    Bridge.send({ type: 'result', outcome: 'win', heartsRemaining: state.hearts });
  } else {
    Bridge.audio('level_retry');
    showSpeech('قربت توصل! جرب مرة ثانية يا بطل 💪', 0);
    Bridge.send({ type: 'result', outcome: 'retry', roundIndex: state.roundIndex });
  }
}

// ----- تلميح الاتجاه بعد 9 ثواني بدون وصول -----

function maybeGiveHint(now) {
  if (!state.roundActive || state.inputLocked) return;
  if (now - state.lastHintAt < HINT_DELAY_MS) return;
  state.lastHintAt = now;

  const targetPedestal = state.pedestals.find((p) => p.item.symbol === state.target.symbol);
  if (!targetPedestal) return;

  const toTarget = targetPedestal.mesh.position.clone().sub(player.position).setY(0);
  if (toTarget.lengthSq() < 0.01) return;
  toTarget.normalize();

  const forward = new THREE.Vector3(Math.sin(player.rotation.y), 0, Math.cos(player.rotation.y));
  const angle = signedAngleBetween(forward, toTarget);

  let direction;
  let text;
  if (Math.abs(angle) < 0.9) {
    direction = 'ahead';
    text = 'قدامك مباشرة! 👀';
  } else if (angle > 0) {
    direction = 'right';
    text = 'لف يمين شوي! ➡️';
  } else {
    direction = 'left';
    text = 'لف يسار شوي! ⬅️';
  }
  showSpeech(text, 2600);
  Bridge.audio('hint_direction', { direction });
}

function signedAngleBetween(a, b) {
  const dot = clamp(a.x * b.x + a.z * b.z, -1, 1);
  const cross = a.x * b.z - a.z * b.x;
  return Math.atan2(cross, dot);
}

// ============================== الحلقة الرئيسية (Update Loop) ==============================

const clock = new THREE.Clock();

function update() {
  const dt = Math.min(clock.getDelta(), 0.05);
  const now = performance.now();

  // حركة اللاعب
  const moving = !state.inputLocked && moveVector.length() > 0.08;
  if (moving) {
    registerActivity();
    const dirX = moveVector.x;
    const dirZ = moveVector.y;
    const targetYaw = Math.atan2(dirX, dirZ);
    player.rotation.y = lerpAngleShortest(player.rotation.y, targetYaw, dt * 10);
    const next = player.position.clone();
    next.x += dirX * MOVE_SPEED * dt;
    next.z += dirZ * MOVE_SPEED * dt;
    clampToArena(next);
    player.position.x = next.x;
    player.position.z = next.z;
  }
  animateLocomotion(dt, moving);

  // القفز
  if (state.isJumping) {
    state.velocityY -= GRAVITY * dt;
    player.position.y += state.velocityY * dt;
    if (player.position.y <= 0) {
      player.position.y = 0;
      state.isJumping = false;
      state.velocityY = 0;
    }
  }

  // خمول
  if (!moving && !state.isJumping && !state.playingIdle && !state.inputLocked && now > state.nextIdleAt) {
    playIdleAnimation();
  }

  // بوبينج المنصّات + دوران اللوحة نحو الكاميرا
  for (const p of state.pedestals) {
    const plate = p.mesh.userData.plate;
    plate.position.y = 1.85 + Math.sin(now * 0.002 + p.mesh.userData.bobOffset) * 0.08;
    plate.lookAt(camera.position.x, p.mesh.position.y + plate.position.y, camera.position.z);
  }

  // فحص التصادم بالمنصّات (أفقياً بس — عشان القفز ما "يتفادى" لمس المنصّة)
  if (state.roundActive && !state.inputLocked && now > state.invulnerableUntil) {
    for (const p of state.pedestals) {
      const dx = player.position.x - p.mesh.position.x;
      const dz = player.position.z - p.mesh.position.z;
      const dist = Math.hypot(dx, dz);
      if (dist < HIT_RADIUS) {
        if (p.isTarget) handleCorrectTouch(p);
        else handleWrongTouch(p);
        break;
      }
    }
  }

  maybeGiveHint(now);

  // خلفية متحركة
  for (const cloud of clouds) {
    cloud.position.x += cloud.userData.speed * dt;
    if (cloud.position.x > 30) cloud.position.x = -30;
  }
  for (const bird of birds) {
    const t = now * 0.001 * bird.userData.speed + bird.userData.offset;
    bird.position.set(Math.cos(t) * bird.userData.radius, bird.userData.height, Math.sin(t) * bird.userData.radius);
    bird.rotation.y = t + Math.PI / 2;
  }

  updateConfetti(dt);

  // كاميرا تتبع اللاعب
  const desiredCamPos = player.position.clone().add(CAMERA_OFFSET);
  camera.position.lerp(desiredCamPos, 1 - Math.pow(0.001, dt));
  const lookTarget = player.position.clone().add(new THREE.Vector3(0, 1.2, 0));
  camera.lookAt(lookTarget);

  renderer.render(scene, camera);
  requestAnimationFrame(update);
}

function lerpAngleShortest(a, b, t) {
  let diff = ((b - a + Math.PI) % (Math.PI * 2)) - Math.PI;
  if (diff < -Math.PI) diff += Math.PI * 2;
  return a + diff * Math.min(1, t);
}

// ============================== التهيئة ==============================

async function loadFonts() {
  try {
    const arabic = new FontFace('Baloo Bhaijaan 2', 'url(./fonts/BalooBhaijaan2-Bold-Arabic.woff2)', { weight: '700 800' });
    const latin = new FontFace('Baloo Bhaijaan 2', 'url(./fonts/BalooBhaijaan2-Bold-Latin.woff2)', { weight: '700 800' });
    const loaded = await Promise.all([arabic.load(), latin.load()]);
    loaded.forEach((f) => document.fonts.add(f));
  } catch (err) {
    // خط النظام الافتراضي يكفي لو فشل التحميل — ما يوقف اللعبة.
    // eslint-disable-next-line no-console
    console.warn('font load failed', err);
  }
}

let started = false;
window.HamoudiGame = {
  init(cfg) {
    config = normalizeConfig(cfg);
    if (!started) {
      started = true;
      loadingVeilEl.classList.add('hidden');
      requestAnimationFrame(update);
    }
    startLevel();
  },
};

function normalizeConfig(cfg) {
  const items = Array.isArray(cfg?.items) && cfg.items.length > 0
    ? cfg.items
    : [
        { symbol: 'ا', exampleWord: 'أسد', emoji: '🦁' },
        { symbol: 'ب', exampleWord: 'بطة', emoji: '🦆' },
        { symbol: 'ت', exampleWord: 'تفاح', emoji: '🍎' },
        { symbol: 'ث', exampleWord: 'ثعلب', emoji: '🦊' },
      ];
  return {
    childName: cfg?.childName || 'حمودي',
    avatar: cfg?.avatar || {},
    items,
    resumeAt: Number.isInteger(cfg?.resumeAt) ? cfg.resumeAt : 0,
  };
}

(async function boot() {
  await loadFonts();
  Bridge.send({ type: 'ready' });
  // وضع تجربة مستقل بالمتصفح (بدون Flutter) — أضيفي ?demo=1 بالرابط.
  if (window.location.search.includes('demo=1')) {
    window.HamoudiGame.init(null);
  }
})();
