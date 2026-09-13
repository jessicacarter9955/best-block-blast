# Block Blast — Native Flutter port (1:1)

A native Flutter port of the **Block Blast** puzzle game using the **Flame**
game engine. No WebView — the game logic, rendering, audio, and UI are all
native Dart code. This is a **1:1 port** of the original Construct 3 /
GameDistribution build: same sprites, same sounds, same layout coordinates
(1080×1920 design), same scoring, combo, tutorial, and ranking logic.

## Project layout

```
flutter-app/
├── lib/
│   ├── main.dart                       Flutter entry point (GameWidget,
│   │                                   letterboxed 1080×1920 viewport).
│   └── game/
│       ├── block_blast_game.dart        Main FlameGame: state machine
│       │                                (home/hud/pause/revive/gameOver/
│       │                                ranking/waiting), 8×8 board, tray,
│       │                                drag-drop with ×2 scale and −200px
│       │                                lift, line clearing, combo/heart,
│       │                                score count-up, revive countdown,
│       │                                game-over flow, screen shake.
│       ├── rendering.dart               Canvas rendering of every screen and
│       │                                popup (Home, HUD, Pause, Revive,
│       │                                Game Over, Ranking, NoSpaceLeft,
│       │                                effects, particles).
│       ├── layout_constants.dart        Original design-space coordinates
│       │                                (Board 540,831 · 120px cells, tray
│       │                                placeholders, HUD, popups).
│       ├── bitmap_font.dart             Sprite-font renderer built from the
│       │                                original txtScore/txtGOScore/… glyph
│       │                                sheets.
│       ├── sprite_cache.dart            Loads sprites via the extracted
│       │                                Construct 3 manifest (77 sprites).
│       ├── sprite_manifest.dart         Manifest (JSON) parser.
│       ├── palette.dart                 Original 8 block colors.
│       ├── shapes.dart                  37 original shapes.
│       ├── tutorial.dart                Scripted 3-step tutorial (1:1 port
│       │                                of the original "Tutorials" events).
│       ├── ranking.dart                 Leaderboard with the original
│       │                                time-decay formula + "You" row.
│       ├── persistence.dart             "Block Blast_Data" storage:
│       │                                {SFX, Music, BestScore, Tut}.
│       ├── audio.dart                   PlaySFX 1:1 mapping, 14 score
│       │                                variants, 5 cheerful variants, beep.
│       └── tween.dart                   Small tween/scheduler engine used
│                                        for popups, count-ups and effects.
├── assets/
│   ├── sprites-named/                  77 PNG sprites extracted from the
│   │                                   original sprite sheets + manifest.json.
│   ├── audio/                          MP3 audio (converted from the
│   │                                   original webm via ffmpeg): 14 score
│   │                                   variations (s1–s15, no s12), 5
│   │                                   cheerful variations (c2–c6), beep,
│   │                                   put, return, whoosh, no_space, lose,
│   │                                   revive, music.
│   └── data/ranking.json               Original leaderboard seed data.
├── android/                            Standard Flutter Android scaffolding:
│   ├── settings.gradle.kts
│   ├── build.gradle.kts
│   ├── app/build.gradle.kts             (applicationId: com.jessicacarter.chocoblock,
│   │                                     minSdk=21, release signed with debug key)
│   ├── app/src/main/AndroidManifest.xml (portrait-locked, hardware-accelerated)
│   ├── app/src/main/res/                (launcher icons at 5 densities,
│   │                                     launch background, styles)
│   └── app/src/main/kotlin/com/jessicacarter/chocoblock/MainActivity.kt
├── docs/DIFFERENZE.md                   Full diff report: port vs original
│                                        (36 differences, all resolved here).
├── pubspec.yaml                        name=chocoblock, version=0.1.0+1
│                                       flame: ^1.20.0, flame_audio: ^2.10.0,
│                                       audioplayers: ^6.1.0
├── .github/workflows/build-apk.yml     GitHub Actions workflow.
├── .gitignore
└── README.md (this file)
```

## How it works

The game renders the **original sprites** (blocks, board, HUD, popups,
buttons, logo, banner, effects) through a single `Canvas` in the Flame game
loop, in a fixed **1080×1920 design space** that is uniformly scaled and
letterboxed to the device screen — exactly like the original's fixed
resolution. All coordinates match the originals: Board center (540, 831) with
120px cells, tray placeholders at (196.5 / 539.5 / 883.5, 1626) with 60px
cells, `txtScore` at (540, 211.5), and so on.

Game logic is a faithful port of the Construct 3 event sheets:

- **Piece generation** — pool of 5 placeable shapes (out of 37, verified
  with `ShapeCheckPlace`), 3 distinct shapes, 3 distinct colors.
- **Scoring** — `EarnedScore = (Combo+1) × 10 × lines × max(1, lines−1)`
  plus +1 per placed block (verified live: 63 / 186 / 550 in the tutorial).
- **Combo** — consecutive clears, heart behind the score from Combo > 1,
  glow + "×N" + screen shake (5px, 0.2s), score sounds `s{min(15, Combo+1)}`,
  reset after 3 consecutive no-line moves.
- **Game over flow** — Waiting → music fade-out → `no_space` SFX →
  NoSpaceLeft banner pop-in → 1s → Revive (5s countdown with beep +
  radial progress) → Game Over (lose SFX, score count-up 0.8s).
- **Revive** — destroys the blocks overlapping the tray placeholders,
  resets placement counters, regenerates the tray, fades music back in.
- **Tutorial** — 3 scripted steps (columns / rows / cross) with drag
  constraints, ghost hand and block, saved `Tut=0` on completion.
- **Ranking** — `ranking.json` + time-decay bonus
  `int((1100 − days) × 8.5 × (i+1))`, "You" row highlighted, rank > 10
  shown via the calculated row.
- **Persistence** — `Block Blast_Data` = `{SFX, Music, BestScore, Tut}`,
  best score saved live during play.

Audio is loaded from `assets/audio/` via Flame's audio cache. The original
game used `.webm` files (which Flutter's audio system can't decode on all
platforms); they were converted to `.mp3` via `ffmpeg` with no other change.
Volumes match the original dB settings (music −5dB → 0.56 linear, cheerful
−10dB → 0.32 linear).

## Build the APK

You don't need Flutter installed locally — GitHub Actions builds the
APK for you.

### One-time setup

1. Make sure your repo is at https://github.com/jessicacarter9955/best-block-blast
2. Copy the contents of this `flutter-app/` folder INTO the repo root
   (not as a subfolder — GitHub Actions only runs workflows from
   `<repo-root>/.github/workflows/`). Example:
   ```bash
   cd /path/to/best-block-blast
   cp -r /home/z/my-project/flutter-app/* .
   cp -r /home/z/my-project/flutter-app/.github .
   cp /home/z/my-project/flutter-app/.gitignore .
   git add .
   git commit -m "Add native Flutter port (Flame engine)"
   git push
   ```
3. Watch the build at `https://github.com/jessicacarter9955/best-block-blast/actions`.

### Every push to `main`

- GitHub Actions installs Flutter (cached), bootstraps missing files
  (gradle wrapper) via `flutter create .`, then runs `flutter build apk --debug`.
- Download `chocoblock-debug-<sha>.apk` from the Actions tab → latest run → Artifacts.
- Install on your phone:
  ```
  adb install chocoblock-debug-<sha>.apk
  ```

### Tag a release

```bash
git tag v0.1.0
git push origin v0.1.0
```

- GitHub Actions builds the release APK (minified, shrunk).
- The APK is automatically attached to a new GitHub Release at
  `https://github.com/jessicacarter9955/best-block-blast/releases`.

## To change the app name or app id

Both are easy to change before publishing:

- **App name** (under the icon):
  - `android/app/src/main/AndroidManifest.xml` → `android:label="ChocoBlock"`
  - `pubspec.yaml` → `name: chocoblock`
- **Application ID**:
  - `android/app/build.gradle.kts` → `namespace = "..."` and `applicationId = "..."`
  - Rename the folder `android/app/src/main/kotlin/com/jessicacarter/chocoblock/`
    to match the new namespace, and update the `package` line in
    `MainActivity.kt`.

## To tweak the block colors

Edit `lib/game/palette.dart` — the 8 entries mirror the original
(141,95,215) purple, (54,178,225) cyan, (59,180,59) green, (72,100,231)
blue, (237,182,50) gold, (237,120,33) orange, (201,49,49) red,
(211,95,215) magenta.

## To add new piece shapes

Edit `lib/game/shapes.dart` and add a new `[[...]]` matrix to the
`kShapes` list. The game picks shapes randomly when refilling the
tray.

## iOS

Not yet scaffolded. To add iOS:

1. Get an Apple Developer account ($99/year).
2. Add `--platforms=ios` to the `flutter create` step in
   `.github/workflows/build-apk.yml`.
3. Run on a macOS GitHub Actions runner with a code-signing cert
   from GitHub Secrets.

## AdMob

Not yet wired. To add ads:

1. Add `google_mobile_ads: ^5.0.0` to `pubspec.yaml`.
2. Initialize MobileAds in `main.dart`'s `initState`.
3. Add a banner at the top of `GameScreen` (below the header) and
   an interstitial between tray refills.
