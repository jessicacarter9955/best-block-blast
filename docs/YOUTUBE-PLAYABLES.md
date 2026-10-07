# YouTube Playables build track

Branch: `codex/youtube-playables`.

The branch build injects the official YouTube Playables SDK before Flutter starts and compiles with `YOUTUBE_PLAYABLES_BUILD=true`. It routes save data to YouTube cloud storage, reads YouTube's locale, sends first-frame and game-ready signals, handles YouTube audio and pause/resume events, submits a new best score, and uses the YouTube rewarded/interstitial APIs. It does not load the Playgama Bridge CDN. The workflow checks the archive's size, file count and file names and publishes a test artifact.

## Still required before submission

- **Landscape is not finished.** The game still uses its 1080×1920 portrait layout. Test on real wide viewports and redesign/reflow the board, trays, score and controls for landscape before calling the game adapted. The existing portrait camera is not proof of landscape support.
- **Originality and rights are unresolved.** Current repository documentation says the logic is transcribed from a decompiled Construct 3 game and that sprite assets are extracted. YouTube rejects copied or lightly reworked games. Do not submit this build as an original game until the mechanics, name and assets have been replaced or you have documented rights and YouTube accepts the resulting work.
- Run the YouTube Playables SDK test suite and bundle analyzer in the developer portal. The GitHub archive-size check is only an early check, not the portal's initial-download measurement or certification.
- Test touch and mouse input, audio mute/resume, pause/resume, cloud saves across restarts, score submission, first-load time, and every declared locale in the YouTube environment.
- Apply to the Playables program; developer access is limited/early access.

## Local build

```bash
flutter pub get
flutter test
flutter build web --release --no-tree-shake-icons --base-href / --dart-define=YOUTUBE_PLAYABLES_BUILD=true
python3 tool/prepare_youtube_playables.py
```

The Playables SDK is loaded only in this branch's built `index.html`; the ordinary Playgama web release does not include that SDK script.
