# Playgama publishing

The Flutter web build integrates [Playgama Bridge](https://wiki.playgama.com/playgama/bridge-sdk/api) for ads, player storage, host language, game-ready notification, pause and audio events.

The web wrapper is in `lib/game/playgama_ads_web.dart`; native builds use the safe no-op wrapper in `lib/game/playgama_ads_stub.dart`. The game saves settings, tutorial state and best score through Bridge Storage when hosted on a Playgama platform. The ordinary browser build uses its normal local save. Visible interface text supports English, Italian and Russian and reads the active host language after SDK initialization.

Ads are requested at game over and when the player opts into a hint or revive. Music and sound effects are muted during ads and host-requested pauses. The first interactive game frame sends `game_ready`.

## Uploading a build

1. Wait for the `Build Playgama Web Bundle` workflow on `master` to finish successfully.
2. Download `block-rush-web-latest.zip` from the [latest release](https://github.com/jessicacarter9955/best-block-blast/releases/latest). It contains `index.html` at the ZIP root.
3. Upload it in the [Playgama developer dashboard](https://developer.playgama.com/applications/cmuplfi7601uipz0hhf5s8tci), fill the title, game description, instructions, devices, orientation and languages, then test with Playgama's QA tools before submitting.

Do not declare languages that have not been checked in the submitted build. Review the dashboard's current moderation feedback and platform-specific requirements before choosing distribution partners.

## Rights and ownership check before submission

The repository records that the current game logic was transcribed from a decompiled Construct 3 game and that many images are marked `extracted`. This is a material rights and originality issue. Confirm you own or have a written license for each reused source-game element and for the right to sublicense it to Playgama and its distribution partners. A new title, colors or added UI do not by themselves establish an original game.

Check the source and license for every asset group: extracted sprite sheets under `assets/sprites-named/`; the crown, backgrounds, blocks and controls under `assets/rush/`; all sound and music under `assets/audio/`; the bundled fonts under `assets/fonts/`; and the game name, crown/logo and any reference to another game's branding. Keep source files, licenses, receipts and permission emails together. The generated backgrounds and crown also need a review of the image-generation service's terms and any source-image rights.

Playgama states that the developer keeps rights but grants distribution/sublicensing rights as part of its publishing terms. Read and accept those terms only after the ownership checks are complete.

## YouTube Playables branch

The separate `codex/youtube-playables` branch builds with YouTube's SDK, cloud saves, audio and pause callbacks, language, first-frame/game-ready notifications, and a bundle-size/file-name check. This is a technical submission track, not a claim of certification: the current game still needs a purpose-built landscape layout and a demonstrably original game concept before it can meet YouTube's review criteria. See the branch's workflow and `docs/YOUTUBE-PLAYABLES.md`.
