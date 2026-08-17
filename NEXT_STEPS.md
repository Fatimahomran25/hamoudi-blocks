# Roadmap

This file translates the original engineering prompt into clear work
phases. **Milestones 1, 2, and 3 are done** (Flutter scaffolding + the real
3D game world + pre-recorded audio). The upcoming milestones are largely
independent of each other and can be done in any order, but the suggested
order below has a reason behind it.

## ✨ Extra polish — the levels screen as a roadmap

`lib/screens/home/levels_screen.dart` was changed from a plain card grid
to a winding level map (like familiar video game level maps): a dashed
path (S-curve) connecting levels, the selected character (in its real
colors via `BlockyAvatarPreview`) standing on the current level as a "you
are here" marker, completed levels in green with their stars shown below
them, the current level highlighted in yellow, and locked levels in gray
with a lock icon. An important fix made during the build: a `Stack` with
no bounded height constraint from its parent (a `Positioned` without
`height`) crashes with "size.isFinite" — every node needs an explicit
fixed height.

## ✅ Milestone 1 — Flutter app scaffolding (done)

- A local parent account (email/password), adding a child, character
  selection (6 options with an animated blocky preview), automatic
  session recall.
- Main menu → language → levels (74 items: 28 Arabic letters + 26 English
  letters + 10 Arabic numbers + 10 English numbers, 4 items per level).
- A star system and progressive level unlocking, win/"try again" screens.
- A visual identity (colors + Baloo Bhaijaan 2 font + black borders/box
  shadow) and RTL support.
- The gameplay screen itself was a temporary **placeholder**
  (`GamePlaceholderScreen`) — showing the level's items and simulated
  win/lose buttons for testing, with no real 3D world yet.
- Storage is fully local (`shared_preferences`), no network at all.

## ✅ Milestone 2 — the real 3D game world (done)

- A full Three.js world under `assets/game3d/` (`index.html` + `style.css`
  + `game.js`), 100% local and offline (Three.js itself + the Baloo
  Bhaijaan 2 font are bundled as files under `vendor/` and `fonts/`, no
  CDN at runtime at all): a blocky character (head/torso/2 arms/2 legs in
  the selected child's Avatar colors), a free-moving touch joystick + a
  jump button, 4 pedestals scattered randomly (360° angle and random
  radius) around the player each round, a 3-heart system spanning the
  whole level, a direction hint (ahead/right/left) after 9 seconds of
  being lost, celebration (confetti + a hop) on a hit, a light stumble +
  pushback on a miss, random idle animations after ~2.6 seconds of
  standing still, and direct touch interaction on the character
  (spin/hop). A light moving background (clouds + birds) and a
  checkerboard ground via a single texture (instead of hundreds of
  polygons) to keep performance light on a mid-range phone.
- The Flutter ↔ WebView bridge is a single JavaScript Channel named
  `GameChannel` (every message is documented at the top of
  `assets/game3d/game.js` and in `lib/screens/game/game_screen.dart`): the
  page sends `ready` then `audio` events (each routed to a method on
  `AudioService`) and `result` (win/"try again") and `exit`; Flutter
  replies with `window.HamoudiGame.init(config)` carrying the child's real
  name, the chosen `AvatarOption`'s colors, and the level's items from
  `ContentRepository`.
- `GameScreen` replaced `GamePlaceholderScreen` with the exact same
  signature (`childId, group, levelIndex`) plus an optional
  `startRoundIndex` field that lets "try again" resume the same question
  where hearts ran out instead of restarting the whole level from scratch
  ("the level never goes backward," per the original prompt) — the rest of
  the screens (levels, win, progress) needed no logic changes.
- The logic was actually tested (not just read through as code): running
  the page in a real browser (headless Chrome) with no console errors, a
  confirming screenshot of the scene and HUD, then a full
  `flutter build apk --debug` succeeded with the `game3d/` assets actually
  bundled into the resulting APK.
- An alternative (more effort, full control, not used here): Unity
  Personal (free) via `flutter_unity_widget` instead of WebView+Three.js.

## ✅ Milestone 3 — pre-recorded audio (done)

3 audio attempts were tried before landing on the final version
(documenting the decision to avoid repeating it later):

1. **Local Piper TTS** (`ar_JO-kareem-medium`, Jordanian) — guaranteed 100%
   zero cost, no card at all. **Rejected after actually trying it**:
   clarity wasn't good enough for a 4-year-old.
2. **Azure Neural TTS** (`ar-SA-HamedNeural`, Saudi, normal speed) — **also
   rejected**, same clarity concern.
3. **Final Azure Neural TTS** (`ar-SA-HamedNeural`, slower speed
   `rate: -15%`) — after trying 9 samples (Zariyah/Hamed Saudi + Kuwaiti/
   Qatari/Emirati male/female), this is the chosen option. Needs an Azure
   account (a card for verification only, Free F0 tier, no actual charge —
   see the setup steps if you need to regenerate the key later at
   portal.azure.com → Speech service → Keys and Endpoint).

**160 clips** under `assets/audio/`:
- `content/` (74 files) — "Say: Alef... like Lion!" played at the start of
  each round and every ~5 seconds as a reminder while searching.
- `content_found/` (74 files) — "We found the letter Alef! Alef! Alef!
  Alef!" (repeated 3 times) played on a hit instead of generic
  encouragement — an explicit request to reinforce the letter in the
  child's memory.
- `phrases/` (12 files) — welcome, 4 encouragement variants, a friendly
  error, win, "try again," 3 direction hints, a jump sound.

All text (written and spoken) is in **classical Arabic (Fusha)** (an
explicit request) instead of colloquial. The
`{ar|en}_{letter|number}_{index}.wav` naming automatically matches
`ContentRepository`'s ordering via `AudioService._contentAudioKey`. "Hero"
is used in the audio instead of the child's real name (the real name only
appears in the written speech-bubble text).

**A bug found and fixed during this milestone**: the direction hint
(`giveDirectionHint` in `game.js`) was computing right/left relative to the
character's facing direction (`player.rotation.y`), which changes every
time the child turns — while the camera has a fixed orientation and
doesn't rotate with it (and the joystick system itself is already
world-oriented, not dependent on the character's facing). The result: the
hint came out reversed whenever the character was turned away from its
original direction. The fix: the hint is now computed relative to a fixed
world axis (`screenForward = (0,0,-1)`) matching the joystick system,
regardless of the character's rotation.

`lib/services/audio_service.dart` now actually plays the files via
`audioplayers` (instead of a stub), with a new `playFoundContent()` for the
triple repeat. Verified: `flutter analyze` and `flutter test` are clean,
and a full `flutter build apk --debug` succeeded with all 160 files
confirmed bundled into the APK.

⚠️ **The Azure key used for generation was temporary** — check with the
user if it's been regenerated since; if more clips are ever needed later,
a new key from the same Speech resource is required
(`hamoudi-tts-2026` in the `hamoudi-blocks` resource group).

## 4️⃣ Milestone 4 — Firebase (a real account + sync + notifications)

- Create a Firebase project on the **free Spark plan** (no credit card).
- Install `firebase_core` + `firebase_auth` + `cloud_firestore` +
  `firebase_messaging`, run `flutterfire configure`.
- Replace `lib/services/auth_service.dart`'s internals with
  `firebase_auth` (same public interface: `createAccount` / `signIn` /
  `signOut`).
- Replace/extend `lib/services/profile_service.dart` with Firestore sync
  on top of the same methods (`addChild`, `recordLevelResult`...), so the
  current local storage stays as an instant offline cache.
- Enable `firebase_messaging` for light reminder notifications to parents
  (once or twice a week at most) — remember the extra APNs setup needed on
  iOS.

## 5️⃣ Milestone 5 — direct distribution to Hamoudi's device

- Android: `flutter build apk --release` → install directly (enable
  "install from unknown sources" once in device settings).
- iOS: `flutter build ios --release` from a Mac with Xcode, connect the
  device by cable, run from Xcode with a regular Apple ID (weekly
  re-signing expected on the free account — check Apple's current
  documentation at that time).
- App icon: design an original icon (a rounded-corner square with a blue
  gradient + an original shape like a blocky letter "ح") — **do not copy
  any other game's logo shape**, even if the name differs (see the "logo
  and name" section of the original prompt for why this constraint
  exists).

## 6️⃣ Milestone 6 (future idea) — an in-world "friend" companion character

A second blocky character in the game world that occasionally speaks
pre-written encouragement or simple comments to the child ("Nice job
finding that one!", "Let's look over there!") — using the exact same
pre-recorded-audio system already in place (`assets/audio/`,
`AudioService`), not a new mechanism.

**Deliberately not a live AI chat.** Two reasons this stays scripted/
pre-recorded rather than a real conversational AI:
- **Cost**: every message to a live AI has a per-call cost, which breaks
  the project's zero-recurring-cost commitment.
- **Safety**: a 4-year-old having an open, unscripted conversation with an
  AI carries real risk — unpredictable output that can't be reviewed in
  advance. Every line the companion says needs to be written and approved
  by the parent ahead of time, exactly like the rest of the app's audio.
