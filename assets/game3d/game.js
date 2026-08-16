// 3D game world — "Hamoudi Blocks" (Milestone 2).
//
// A blocky character controlled by a free-moving touch joystick inside a
// fenced-in ground, searching among 4 pedestals scattered randomly around
// (360°) for the correct letter/number. Hearts system (3), a direction hint
// after 9 seconds, celebration + a star on a hit, a friendly stumble on a
// miss. See the "Gameplay" section of the original prompt for design details.
//
// Bridge to Flutter (the other end lives in lib/screens/game/game_screen.dart):
//   Flutter → page: window.HamoudiGame.init(config) after receiving {type:'ready'}.
//   Page → Flutter: GameChannel.postMessage(JSON.stringify(msg)) for each of:
//     {type:'ready'}
//     {type:'audio', event:'...', symbol?, direction?}
//     {type:'result', outcome:'win', heartsRemaining} | {outcome:'retry', roundIndex}
//     {type:'exit'}

// Important note: Three.js is loaded here as a plain script (UMD, global
// THREE variable) via <script src="./vendor/three.min.js"> in index.html
// before this file — NOT as an ES Module (import). We tried ES Modules
// first, but WKWebView on iOS (via webview_flutter's loadFlutterAsset)
// doesn't guarantee a correct MIME type (text/javascript) for local files,
// and type="module" scripts are strict about this, so they fail silently
// (loading hangs forever on the 🧊 screen). A plain script is more
// forgiving and works reliably on both Android and iOS.

// ============================== Bridge ==============================

/** true if the page is open inside a real webview_flutter (GameChannel
 * present), false if it's open standalone in a regular browser (test/dev
 * mode). */
function hasBridge() {
  return !!(window.GameChannel && typeof window.GameChannel.postMessage === 'function');
}

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
    // In standalone browser test mode (no Flutter) there's no AudioService
    // to play the file — we play it directly here so we can hear the same
    // real audio without needing a full Flutter app.
    if (!hasBridge()) DemoAudio.play(event, extra);
  },
};

// ============================== Standalone test-mode audio ==============================
// Mirrors lib/services/audio_service.dart's logic exactly (same filenames
// and content ordering) — just in JavaScript so it works without Flutter.
// Files are read from a separate local server (see assets/audio/ — run it
// with something like: node static_server.js assets/audio 8792) since
// they're outside the game3d/ folder.
const DemoAudio = {
  baseUrl: 'http://localhost:8792/',
  arabicLetters: ['أ', 'ب', 'ت', 'ث', 'ج', 'ح', 'خ', 'د', 'ذ', 'ر', 'ز', 'س', 'ش', 'ص', 'ض', 'ط', 'ظ', 'ع', 'غ', 'ف', 'ق', 'ك', 'ل', 'م', 'ن', 'هـ', 'و', 'ي'],
  englishLetters: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split(''),
  arabicNumbers: ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'],
  englishNumbers: '0123456789'.split(''),

  contentKey(symbol) {
    const groups = [
      ['ar_letter', this.arabicLetters],
      ['en_letter', this.englishLetters],
      ['ar_number', this.arabicNumbers],
      ['en_number', this.englishNumbers],
    ];
    for (const [prefix, list] of groups) {
      const i = list.indexOf(symbol);
      if (i !== -1) return `${prefix}_${i}`;
    }
    return null;
  },

  currentAudio: null,

  playFile(relativePath) {
    try {
      // Stop any audio currently playing first, exactly like
      // AudioService.dart (one shared player) — otherwise a new sound
      // starting before the previous one finishes causes overlap (was a
      // real bug here, now fixed).
      if (this.currentAudio) {
        this.currentAudio.pause();
        this.currentAudio.currentTime = 0;
      }
      const audio = new Audio(this.baseUrl + relativePath);
      this.currentAudio = audio;
      audio.play().catch(() => {});
    } catch (err) {
      // Audio server isn't running or the file doesn't exist — ignore safely.
    }
  },

  play(event, extra) {
    if (event === 'level_intro') {
      if (extra?.symbol) {
        const key = this.contentKey(extra.symbol);
        if (key) this.playFile(`content/${key}.wav`);
      } else {
        this.playFile('phrases/level_intro.wav');
      }
      return;
    }
    if (event === 'hint_direction') {
      const dir = ['ahead', 'left', 'right', 'behind'].includes(extra?.direction) ? extra.direction : 'ahead';
      this.playFile(`phrases/hint_direction_${dir}.wav`);
      return;
    }
    if (event === 'correct_answer') {
      this.playFile(`phrases/correct_answer_${1 + Math.floor(Math.random() * 4)}.wav`);
      return;
    }
    if (event === 'found_answer') {
      const key = extra?.symbol ? this.contentKey(extra.symbol) : null;
      if (key) this.playFile(`content_found/${key}.wav`);
      return;
    }
    if (['wrong_answer', 'level_win', 'level_retry', 'jump'].includes(event)) {
      this.playFile(`phrases/${event}.wav`);
    }
  },
};

// ============================== Constants ==============================

const ARENA_RADIUS = 17.5; // Fence boundary — the character can't cross it.
const PEDESTAL_MIN_RADIUS = 6;
const PEDESTAL_MAX_RADIUS = 13;
const MOVE_SPEED = 6.4; // units/second
const JUMP_VELOCITY = 8.5;
const GRAVITY = 24;
const HIT_RADIUS = 1.9; // "touch" distance between the player and a pedestal
const HEART_START = 3;
// Periodic reminder of the letter/number every 15 seconds of searching with
// no progress (explicit request) — alternates between repeating the letter
// itself by voice and a direction hint (small arrow icon, not a speech
// bubble blocking the screen).
const REMINDER_DELAY_MS = 15000;
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

// ============================== Game state ==============================

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
  reminderCount: 0,
  roundStartedAt: 0,
};

// ============================== Scene setup ==============================

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

// ----- Ground (light checkerboard via a texture instead of hundreds of polygons) -----

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

// ----- Surrounding fence -----

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

// ----- Moving background elements (clouds + birds) -----

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

// ============================== Blocky character ==============================

function hexToColor(hex, fallback) {
  if (!hex) return fallback;
  return new THREE.Color(hex);
}

/** Builds a blocky character (head+torso+2 arms+2 legs) with the given
 * avatar's colors. Assembled bottom-up: legs (hip pivot) → torso → arms
 * (shoulder pivot) → head → hair, so the feet touch the ground exactly and
 * the legs/arms swing from their correct joint instead of the box's center
 * while running. */
function buildCharacter(avatar) {
  const jacket = hexToColor(avatar?.jacket, new THREE.Color(COLORS.red));
  const skin = hexToColor(avatar?.skin, new THREE.Color(0xf2c29a));
  const hair = hexToColor(avatar?.hair, new THREE.Color(0x2b1b12));

  const group = new THREE.Group();

  const HIP_Y = 0.9;
  const SHOULDER_Y = 1.9;
  const HEAD_SIZE = 0.7;

  const legGeo = new THREE.BoxGeometry(0.32, 0.9, 0.32);
  legGeo.translate(0, -0.45, 0); // pivot at the top of the leg
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
  armGeo.translate(0, -0.4, 0); // pivot at the shoulder
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

// ============================== Pedestals ==============================

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

/** Distributes the level's pedestals (as many as `items` has) at a random
 * angle (360°) and random radius around the player. */
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

// ============================== Confetti ==============================

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

// ============================== HUD ==============================

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

// ============================== Joystick ==============================

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

// ----- Jump button -----

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

// ----- Direct touch interaction on the character -----

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

// ----- Exit button -----

document.getElementById('exit-btn').addEventListener('pointerdown', () => {
  Bridge.audio('ui_tap');
  Bridge.send({ type: 'exit' });
});

// ============================== Character animations ==============================

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

/** Gentle idle animations for when the child stands still (waves, a small
 * hop, looks around). */
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

/** A random playful animation when the character is touched directly (like
 * petting a pet character). */
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

/** Automatic celebration hop when the correct letter is reached. */
function playCelebrationHop(onDone) {
  animateTween(700, (t) => {
    player.position.y = Math.abs(Math.sin(t * Math.PI * 1.5)) * 0.9;
    player.rotation.y += 0.08;
  }, () => { player.position.y = 0; onDone && onDone(); });
}

/** A light stumble + quick pushback when touching a wrong pedestal. */
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

/** Generic helper to animate a value over time (no external tween library,
 * lightweight). */
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

// ============================== Round logic ==============================

function startLevel() {
  state.hearts = HEART_START;
  state.roundIndex = clamp(config.resumeAt || 0, 0, config.items.length - 1);
  renderHearts();
  spawnPlayer();
  // Welcome the child by their real name once at the start of the level
  // (text only — the recorded audio uses a generic "hero" address instead
  // of the name, see the "child name personalization" section of the
  // original prompt).
  if (state.roundIndex === 0) {
    showSpeech(`هيّا يا ${config.childName}! هل أنت مستعدّ للّعب؟ 🎮`, 2200);
    Bridge.audio('level_intro'); // no symbol = generic welcome, not an item intro.
  }
  // Longer delay on the first round so the welcome audio has time to finish
  // before the first round's audio starts (otherwise it gets cut off or
  // overlaps).
  setTimeout(beginRound, state.roundIndex === 0 ? 3400 : 0);
}

function beginRound() {
  state.target = config.items[state.roundIndex];
  state.roundActive = true;
  state.roundStartedAt = performance.now();
  state.lastHintAt = state.roundStartedAt;
  state.reminderCount = 0;
  state.invulnerableUntil = state.roundStartedAt + 400;

  player.position.set(0, 0, 0);
  player.rotation.set(0, 0, 0);

  layoutPedestals(config.items, state.target);
  renderTargetCard(state.target);
  renderProgress();
  showSpeech(
    `يا ${config.childName}، ابحث عن ${state.target.symbol}! مثل ${state.target.exampleWord} ${state.target.emoji}`,
    3200,
  );
  Bridge.audio('level_intro', { symbol: state.target.symbol });
  registerActivity();
}

function handleCorrectTouch(pedestal) {
  state.roundActive = false;
  spawnConfetti(pedestal.mesh.position.clone().add(new THREE.Vector3(0, 1.8, 0)));
  // "We found the letter Alef! Alef! Alef! Alef!" — repeated 3 times in
  // audio so it sticks in the child's memory (explicit request), instead of
  // generic praise alone.
  showSpeech(`${pickPraise()} وجدنا ${pedestal.item.symbol}! 🎉`, 3600);
  Bridge.audio('found_answer', { symbol: pedestal.item.symbol });
  playCelebrationHop(() => {
    // Extra delay before the next round so the repeated-name audio has time
    // to finish (~4 seconds).
    setTimeout(() => {
      state.roundIndex += 1;
      if (state.roundIndex >= config.items.length) {
        finishLevel(true);
      } else {
        beginRound();
      }
    }, 900);
  });
}

function handleWrongTouch(pedestal) {
  state.hearts -= 1;
  renderHearts();
  showSpeech('لا بأس، حاول مرة أخرى يا بطل! 💛', 2200);
  Bridge.audio('wrong_answer');
  const pushDir = player.position.clone().sub(pedestal.mesh.position).setY(0);
  if (pushDir.lengthSq() < 0.001) pushDir.set(0, 0, 1);
  pushDir.normalize();
  playStumble(pushDir);
  state.invulnerableUntil = performance.now() + 1100;

  if (state.hearts <= 0) {
    state.roundActive = false;
    // Short delay so the child sees the stumble and friendly message before
    // we move to the "try again" screen (instead of an abrupt animation cut).
    setTimeout(() => finishLevel(false), 900);
  }
}

const PRAISE = [
  'أحسنت! 🌟',
  'رائع جدّاً! 🎉',
  'عمل ممتاز! ⭐',
  'بارع يا بطل! 🏆',
];
function pickPraise() {
  return PRAISE[Math.floor(Math.random() * PRAISE.length)];
}

function finishLevel(didWin) {
  if (didWin) {
    Bridge.audio('level_win');
    showSpeech('أنهيت المستوى بنجاح! 🎉', 0);
    Bridge.send({ type: 'result', outcome: 'win', heartsRemaining: state.hearts });
  } else {
    Bridge.audio('level_retry');
    showSpeech('اقتربت كثيراً! حاول مرة أخرى يا بطل 💪', 0);
    Bridge.send({ type: 'result', outcome: 'retry', roundIndex: state.roundIndex });
  }

  // In standalone browser test mode (no Flutter) nobody receives the result
  // message above to show a win/loss screen — we show a simple fallback on
  // the same page instead of the experience feeling like it "just stopped"
  // with no explanation.
  if (!hasBridge()) showDemoResult(didWin);
}

function showDemoResult(didWin) {
  const veil = document.getElementById('demo-result-veil');
  const btn = document.getElementById('demo-result-btn');
  const levels = currentDemoLevels();
  const hasNextLevel = didWin && demoLevelIndex + 1 < levels.length;

  document.getElementById('demo-result-emoji').textContent = didWin ? '🎉' : '💪';
  document.getElementById('demo-result-title').textContent = didWin
    ? 'أحسنت يا بطل!'
    : 'اقتربت كثيراً يا بطل!';

  if (didWin && !hasNextLevel) {
    document.getElementById('demo-result-subtitle').textContent =
      `أكملتَ كل مستويات "${DEMO_GROUP_LABELS[demoGroup]}"! 🏆 (خلّصت بـ ${state.hearts} قلوب متبقية)`;
    btn.textContent = 'ابدأ من جديد 🔁';
    btn.onclick = () => startDemoLevel(demoGroup, 0);
  } else if (didWin) {
    document.getElementById('demo-result-subtitle').textContent =
      `خلّصت المستوى ${demoLevelIndex + 1} بـ ${state.hearts} قلوب متبقية 🌟 (بالتطبيق الحقيقي هذي لحظة شاشة الفوز وعدّاد النجوم)`;
    btn.textContent = 'المستوى التالي ➡️';
    btn.onclick = () => startDemoLevel(demoGroup, demoLevelIndex + 1);
  } else {
    document.getElementById('demo-result-subtitle').textContent =
      'بالتطبيق الحقيقي هذي لحظة شاشة "حاول مرة ثانية" — تعيد نفس السؤال بقلوب جديدة';
    btn.textContent = 'حاول مرة ثانية 🔁';
    btn.onclick = () => startDemoLevel(demoGroup, demoLevelIndex);
  }

  veil.classList.remove('hidden');
}

// ----- Periodic reminder: alternates between repeating the letter and a direction hint -----

function maybeRemind(now) {
  if (!state.roundActive || state.inputLocked) return;
  if (now - state.lastHintAt < REMINDER_DELAY_MS) return;
  state.lastHintAt = now;
  state.reminderCount += 1;

  // Odd reminder = repeat the letter/number by voice only (memory
  // reinforcement, without a speech bubble so it's not visually
  // distracting); even reminder = direction hint (icon + audio).
  if (state.reminderCount % 2 === 1) {
    Bridge.audio('level_intro', { symbol: state.target.symbol });
    return;
  }

  giveDirectionHint();
}

function giveDirectionHint() {
  const targetPedestal = state.pedestals.find((p) => p.item.symbol === state.target.symbol);
  if (!targetPedestal) return;

  const toTarget = targetPedestal.mesh.position.clone().sub(player.position).setY(0);
  if (toTarget.lengthSq() < 0.01) return;
  toTarget.normalize();

  // Important: the hint must be relative to the fixed screen/camera frame
  // (same system as the joystick controls: "forward" = world -Z always),
  // not relative to the character's facing direction (rotation.y changes
  // every time it turns) — otherwise the hint ends up reversed whenever the
  // character is turned away from its original direction (was a real bug
  // here, now fixed).
  const screenForward = new THREE.Vector3(0, 0, -1);
  const angle = signedAngleBetween(screenForward, toTarget);

  // 4 equal quadrants (90° each) instead of 3 unequal ones — adds "behind"
  // as a 4th direction (explicit request).
  const ARROW_BY_DIRECTION = { ahead: '⬆️', right: '➡️', behind: '⬇️', left: '⬅️' };
  let direction;
  if (Math.abs(angle) < Math.PI / 4) {
    direction = 'ahead';
  } else if (Math.abs(angle) > (3 * Math.PI) / 4) {
    direction = 'behind';
  } else if (angle > 0) {
    direction = 'right';
  } else {
    direction = 'left';
  }
  // Small arrow icon only (not a big speech bubble blocking the screen) —
  // the audio still plays in full as usual.
  showDirectionArrow(ARROW_BY_DIRECTION[direction]);
  Bridge.audio('hint_direction', { direction });
}

let arrowHideTimer = null;
function showDirectionArrow(arrow) {
  const el = document.getElementById('direction-arrow');
  el.textContent = arrow;
  el.classList.add('visible');
  if (arrowHideTimer) clearTimeout(arrowHideTimer);
  arrowHideTimer = setTimeout(() => el.classList.remove('visible'), 1800);
}

function signedAngleBetween(a, b) {
  const dot = clamp(a.x * b.x + a.z * b.z, -1, 1);
  const cross = a.x * b.z - a.z * b.x;
  return Math.atan2(cross, dot);
}

// ============================== Main update loop ==============================

const clock = new THREE.Clock();

function update() {
  const dt = Math.min(clock.getDelta(), 0.05);
  const now = performance.now();

  // Player movement
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

  // Jumping
  if (state.isJumping) {
    state.velocityY -= GRAVITY * dt;
    player.position.y += state.velocityY * dt;
    if (player.position.y <= 0) {
      player.position.y = 0;
      state.isJumping = false;
      state.velocityY = 0;
    }
  }

  // Idle
  if (!moving && !state.isJumping && !state.playingIdle && !state.inputLocked && now > state.nextIdleAt) {
    playIdleAnimation();
  }

  // Pedestal bobbing + plate rotation to face the camera
  for (const p of state.pedestals) {
    const plate = p.mesh.userData.plate;
    plate.position.y = 1.85 + Math.sin(now * 0.002 + p.mesh.userData.bobOffset) * 0.08;
    plate.lookAt(camera.position.x, p.mesh.position.y + plate.position.y, camera.position.z);
  }

  // Pedestal collision check (horizontal only — so jumping doesn't "dodge" touching a pedestal)
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

  maybeRemind(now);

  // Moving background
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

  // Camera follows the player
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

// ============================== Bootstrapping ==============================

async function loadFonts() {
  try {
    const arabic = new FontFace('Baloo Bhaijaan 2', 'url(./fonts/BalooBhaijaan2-Bold-Arabic.woff2)', { weight: '700 800' });
    const latin = new FontFace('Baloo Bhaijaan 2', 'url(./fonts/BalooBhaijaan2-Bold-Latin.woff2)', { weight: '700 800' });
    const loaded = await Promise.all([arabic.load(), latin.load()]);
    loaded.forEach((f) => document.fonts.add(f));
  } catch (err) {
    // The default system font is good enough if loading fails — doesn't
    // stop the game.
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
    : currentDemoLevels()[demoLevelIndex];
  return {
    childName: cfg?.childName || 'حمودي',
    avatar: cfg?.avatar || {},
    items,
    resumeAt: Number.isInteger(cfg?.resumeAt) ? cfg.resumeAt : 0,
  };
}

// ============================== Test-mode groups and levels ==============================
// Without Flutter there's no ContentRepository.levelsFor — the same content
// and grouping (4 items per level) is duplicated here so you can test all
// letters/numbers (Arabic and English) in the browser. See
// lib/data/content_repository.dart for the source of truth.
function chunk4(items) {
  const levels = [];
  for (let i = 0; i < items.length; i += 4) levels.push(items.slice(i, i + 4));
  return levels;
}

const DEMO_CONTENT = {
  arabicLetters: [
    ['أ', 'أسد', '🦁'], ['ب', 'بطة', '🦆'], ['ت', 'تفاح', '🍎'], ['ث', 'ثعلب', '🦊'],
    ['ج', 'جمل', '🐫'], ['ح', 'حصان', '🐴'], ['خ', 'خروف', '🐑'], ['د', 'دب', '🐻'],
    ['ذ', 'ذئب', '🐺'], ['ر', 'رمان', '🍇'], ['ز', 'زرافة', '🦒'], ['س', 'سمكة', '🐟'],
    ['ش', 'شمس', '☀️'], ['ص', 'صقر', '🦅'], ['ض', 'ضفدع', '🐸'], ['ط', 'طائرة', '✈️'],
    ['ظ', 'ظرف', '✉️'], ['ع', 'عصفور', '🐦'], ['غ', 'غزال', '🦌'], ['ف', 'فيل', '🐘'],
    ['ق', 'قطة', '🐱'], ['ك', 'كلب', '🐶'], ['ل', 'ليمون', '🍋'], ['م', 'موز', '🍌'],
    ['ن', 'نحلة', '🐝'], ['هـ', 'هدية', '🎁'], ['و', 'وردة', '🌹'], ['ي', 'يد', '✋'],
  ],
  englishLetters: [
    ['A', 'Apple', '🍎'], ['B', 'Ball', '⚽'], ['C', 'Cat', '🐱'], ['D', 'Dog', '🐶'],
    ['E', 'Elephant', '🐘'], ['F', 'Fish', '🐟'], ['G', 'Grapes', '🍇'], ['H', 'Hat', '🎩'],
    ['I', 'Ice Cream', '🍦'], ['J', 'Juice', '🧃'], ['K', 'Kite', '🪁'], ['L', 'Lion', '🦁'],
    ['M', 'Moon', '🌙'], ['N', 'Nest', '🪺'], ['O', 'Orange', '🍊'], ['P', 'Pizza', '🍕'],
    ['Q', 'Queen', '👑'], ['R', 'Rabbit', '🐰'], ['S', 'Sun', '☀️'], ['T', 'Tiger', '🐯'],
    ['U', 'Umbrella', '☂️'], ['V', 'Van', '🚐'], ['W', 'Watermelon', '🍉'], ['X', 'Xylophone', '🎹'],
    ['Y', 'Yoyo', '🪀'], ['Z', 'Zebra', '🦓'],
  ],
  arabicNumbers: [
    ['٠', 'صفر', '0️⃣'], ['١', 'واحد', '1️⃣'], ['٢', 'اثنان', '2️⃣'], ['٣', 'ثلاثة', '3️⃣'],
    ['٤', 'أربعة', '4️⃣'], ['٥', 'خمسة', '5️⃣'], ['٦', 'ستة', '6️⃣'], ['٧', 'سبعة', '7️⃣'],
    ['٨', 'ثمانية', '8️⃣'], ['٩', 'تسعة', '9️⃣'],
  ],
  englishNumbers: [
    ['0', 'Zero', '0️⃣'], ['1', 'One', '1️⃣'], ['2', 'Two', '2️⃣'], ['3', 'Three', '3️⃣'],
    ['4', 'Four', '4️⃣'], ['5', 'Five', '5️⃣'], ['6', 'Six', '6️⃣'], ['7', 'Seven', '7️⃣'],
    ['8', 'Eight', '8️⃣'], ['9', 'Nine', '9️⃣'],
  ],
};

const DEMO_GROUPS = Object.fromEntries(
  Object.entries(DEMO_CONTENT).map(([group, rows]) => [
    group,
    chunk4(rows.map(([symbol, exampleWord, emoji]) => ({ symbol, exampleWord, emoji }))),
  ]),
);
const DEMO_GROUP_LABELS = {
  arabicLetters: '🇸🇦 حروف',
  englishLetters: '🇬🇧 Letters',
  arabicNumbers: '🇸🇦 أرقام',
  englishNumbers: '🇬🇧 Numbers',
};

let demoGroup = 'arabicLetters';
let demoLevelIndex = 0;
let demoChildName = 'حمودي';
let demoAvatar = {};

function currentDemoLevels() {
  return DEMO_GROUPS[demoGroup];
}

/** Starts a specific level/group using the same saved child name/avatar
 * (without going back through the name/avatar intro). */
function startDemoLevel(group, levelIndex) {
  demoGroup = group;
  const levels = currentDemoLevels();
  demoLevelIndex = Math.max(0, Math.min(levelIndex, levels.length - 1));
  document.getElementById('demo-result-veil').classList.add('hidden');
  updateGroupSwitcherActive();
  window.HamoudiGame.init({ childName: demoChildName, avatar: demoAvatar });
}

// ============================== Test-mode prologue (name + avatar) ==============================
// Mirrors the same 6 characters from lib/models/avatar_option.dart
// (kAvatarOptions) — duplicated here because this JavaScript is standalone
// from the Flutter code. Keep the two in sync if you add/change a character
// in the app.
const DEMO_AVATARS = [
  { id: 'red_jacket', jacket: '#e2231a', skin: '#f2c29a', hair: '#2b1b12' },
  { id: 'blue_jacket', jacket: '#2e86ff', skin: '#e8ad7c', hair: '#1a1a1a' },
  { id: 'yellow_jacket', jacket: '#ffd23f', skin: '#8d5a3b', hair: '#3b2412' },
  { id: 'green_jacket', jacket: '#34c759', skin: '#f6d2ae', hair: '#6b4226' },
  { id: 'purple_jacket', jacket: '#9b5de5', skin: '#c98a5b', hair: '#120a06' },
  { id: 'orange_jacket', jacket: '#ff8a3d', skin: '#e8ad7c', hair: '#b8860b' },
];

/** A dark card with a live rotating 3D preview of the character — reuses
 * the same buildCharacter() used in actual gameplay, but with its own small
 * independent Three.js scene per card. */
function createAvatarPreview(container, avatar) {
  const canvas = document.createElement('canvas');
  container.appendChild(canvas);

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(32, 1, 0.1, 20);
  camera.position.set(0, 1.3, 4.8);
  camera.lookAt(0, 1.3, 0);

  scene.add(new THREE.AmbientLight(0xffffff, 0.9));
  const key = new THREE.DirectionalLight(0xffffff, 0.7);
  key.position.set(2, 3, 2);
  scene.add(key);

  const character = buildCharacter(avatar);
  scene.add(character);

  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));

  function resize() {
    const w = container.clientWidth;
    const h = container.clientHeight;
    if (w === 0 || h === 0) return;
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
  }
  resize();
  window.addEventListener('resize', resize);

  (function animate() {
    character.rotation.y += 0.012;
    renderer.render(scene, camera);
    requestAnimationFrame(animate);
  })();
}

function setupPrologue() {
  const prologueEl = document.getElementById('demo-prologue');
  const nameStep = document.getElementById('prologue-step-name');
  const avatarStep = document.getElementById('prologue-step-avatar');
  const nameInput = document.getElementById('prologue-name-input');
  const gridEl = document.getElementById('prologue-avatar-grid');

  let childName = '';
  let selectedAvatar = DEMO_AVATARS[0];

  DEMO_AVATARS.forEach((avatar, i) => {
    const card = document.createElement('div');
    card.className = 'avatar-card' + (i === 0 ? ' selected' : '');
    card.addEventListener('pointerdown', () => {
      selectedAvatar = avatar;
      gridEl.querySelectorAll('.avatar-card').forEach((el) => el.classList.remove('selected'));
      card.classList.add('selected');
    });
    gridEl.appendChild(card);
    createAvatarPreview(card, avatar);
  });

  document.getElementById('prologue-name-btn').addEventListener('pointerdown', () => {
    childName = nameInput.value.trim() || 'حمودي';
    nameStep.classList.add('hidden');
    avatarStep.classList.remove('hidden');
  });

  document.getElementById('prologue-avatar-btn').addEventListener('pointerdown', () => {
    prologueEl.classList.add('hidden');
    demoChildName = childName;
    demoAvatar = selectedAvatar;
    setupGroupSwitcher();
    window.HamoudiGame.init({ childName, avatar: selectedAvatar });
  });

  prologueEl.classList.remove('hidden');
}

/** Small buttons at the top of the screen that jump straight to the first
 * level of any group (Arabic/English letters/numbers) — a test tool only,
 * doesn't appear inside the real app. */
function setupGroupSwitcher() {
  const bar = document.getElementById('demo-group-switcher');
  if (bar.childElementCount > 0) {
    bar.classList.remove('hidden');
    updateGroupSwitcherActive();
    return;
  }
  Object.keys(DEMO_GROUPS).forEach((group) => {
    const btn = document.createElement('button');
    btn.className = 'demo-group-btn';
    btn.textContent = DEMO_GROUP_LABELS[group];
    btn.addEventListener('pointerdown', () => startDemoLevel(group, 0));
    bar.appendChild(btn);
  });
  bar.classList.remove('hidden');
  updateGroupSwitcherActive();
}

function updateGroupSwitcherActive() {
  const bar = document.getElementById('demo-group-switcher');
  [...bar.children].forEach((btn, i) => {
    btn.classList.toggle('active', Object.keys(DEMO_GROUPS)[i] === demoGroup);
  });
}

(async function boot() {
  await loadFonts();
  Bridge.send({ type: 'ready' });
  // Standalone browser test experience (no Flutter) — add ?demo=1 to the
  // URL. We show a simple intro (name + avatar) first instead of jumping
  // straight into the game world, so the test experience mirrors the real
  // app's "login → pick a character → play" flow.
  if (window.location.search.includes('demo=1') && !hasBridge()) {
    setupPrologue();
  }
})();
