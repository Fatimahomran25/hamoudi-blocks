# 🧊 Hamoudi Blocks

Hamoudi is 4 years old. He loves games with blocky characters and open
worlds he can run around in — so instead of another flashcard app, this
became a real, playable 3D world: he explores a small fenced-in arena on
foot, hunting down pedestals scattered around him, each one showing a
letter, a number, or a word. Find the right one and his character
celebrates; find the wrong one and a friendly voice tells him to try again.
No ads, no in-app purchases, no accounts for him to manage — he just opens
the app and plays.

Everything he hears is a real, natural voice (not a robotic text-to-speech
read-out), speaking classical Arabic, repeating each letter enough times
that it sticks. Everything he sees is rendered in a bold, blocky style with
thick black outlines and hard drop shadows — an original visual identity,
not a copy of any existing game's branding.

The project runs at zero recurring cost: a local Flutter app shell, a
real-time 3D world built with Three.js, natural voice audio generated
once via Azure's free tier, and a free GitHub Actions pipeline that builds
an installable iOS build without owning a Mac. It's built to be installed
directly on a phone — no app store required.

This repo has finished **Milestone 1** (app scaffolding), **Milestone 2**
(the real 3D game world, running Three.js inside a local WebView), and
**Milestone 3** (natural, pre-recorded Saudi Arabic voice via Azure Neural
TTS) — Firebase sync hasn't been added yet (see
[NEXT_STEPS.md](NEXT_STEPS.md) for each milestone's details).

## Running the project

```bash
flutter pub get
flutter run          # runs it on any connected device/emulator
flutter test         # smoke test
flutter analyze      # static check — should print "No issues found!"
```

## Building and installing directly on a device (no app store)

```bash
# Android — produces an APK you copy to the phone and install directly
flutter build apk --release

# iOS — needs a Mac + Xcode + cable + a regular (free) Apple ID
flutter build ios --release
# then open ios/Runner.xcworkspace in Xcode and Run on the connected device.
```

## Current screen map

```
SignInScreen (parent account — one time only)
  → AddChildScreen (child's name)
    → AvatarSelectScreen (character pick)
      → GameLoginScreen (child's profile, auto-login on future visits)
        → MainMenuScreen (🔤 Letters / 🔢 Numbers)
          → LanguageSelectScreen (🇸🇦 / 🇬🇧)
            → LevelsScreen (roadmap of levels + stars + locking)
              → GameScreen (WebView — the real 3D Three.js world)
                → LevelResultScreen (win 🎉 / try again 💪)
```

## Code structure

```
lib/
  app.dart                  # MaterialApp + AuthGate (picks the first screen based on session state)
  theme/app_theme.dart      # colors + NeoBox (black borders + box shadow)
  models/                   # ChildProfile, AvatarOption, ContentItem/Group
  data/content_repository.dart  # all letters/numbers (74 items) + their split into levels
  services/
    auth_service.dart       # parent account gate (local for now, Firebase later)
    profile_service.dart    # child profiles + progress (local for now)
    audio_service.dart      # plays the real assets/audio/ clips (Azure Neural TTS, Saudi voice)
  screens/
    onboarding/  home/  game/  settings/
    game/game_screen.dart   # local WebView for the Three.js world + GameChannel bridge
  widgets/
    big_button.dart  star_row.dart (StarRow + HeartRow)  blocky_avatar.dart

assets/game3d/               # the 3D game world (Three.js, no internet needed)
  index.html  style.css  game.js
  vendor/three.min.js        # Three.js bundled locally (no CDN; a classic
                              # script, not an ES Module — see the comment at the top of game.js)
  fonts/*.woff2               # the Baloo Bhaijaan 2 font, bundled locally

assets/audio/                 # natural, pre-recorded Saudi Arabic voice (Azure Neural TTS, classical Arabic)
  content/{ar|en}_{letter|number}_N.wav       # "Say: Alef... like Lion!" (74 files)
  content_found/{ar|en}_{letter|number}_N.wav # repeated 3 times on success (74 files)
  phrases/*.wav                                 # welcome/encouragement/hint/error/win (12 files)
```

Each service (`AuthService`, `ProfileService`, `AudioService`) is designed
so the screens only ever talk to its public interface — swapping the
internals later (Firebase, different audio backend) needs no screen
changes.

## The 3D game world (`GameScreen`)

`GameScreen` (in `lib/screens/game/game_screen.dart`) shows
`assets/game3d/index.html` via `webview_flutter`, fully local and offline.
Communication in both directions goes over a single JavaScript Channel
named `GameChannel`:

- **page → Flutter**: `{type:'ready'}` on init, `{type:'audio', event, ...}`
  for every audio event (routed to a method on `AudioService`),
  `{type:'result', outcome:'win'|'retry', ...}` when a level ends,
  `{type:'exit'}` when ✖️ is pressed.
- **Flutter → page**: `window.HamoudiGame.init(config)` after receiving
  `ready` — carries the child's name, the chosen `AvatarOption`'s colors,
  and the level's items from `ContentRepository`.

See the comments at the top of `assets/game3d/game.js` for every message's
details and the full gameplay logic (hearts, hints, celebration,
animations).
