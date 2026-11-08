# Block Rush — six responsive artwork resolutions

Generated using `node scripts/build_resolution_pack.mjs` (requires Node >=20 and sharp).

| Name | Exact pixels | Preview gameplay | Preview home | Backgrounds |
| --- | --- | --- | --- | --- |
| portrait-full-hd | 1080×1920 | [game](previews/game-portrait-full-hd-1080x1920.webp) | [home](previews/home-portrait-full-hd-1080x1920.webp) | [game](backgrounds/game-portrait-full-hd-1080x1920.webp), [home](backgrounds/home-portrait-full-hd-1080x1920.webp) |
| portrait-4k | 2160×3840 | [game](previews/game-portrait-4k-2160x3840.webp) | [home](previews/home-portrait-4k-2160x3840.webp) | [game](backgrounds/game-portrait-4k-2160x3840.webp), [home](backgrounds/home-portrait-4k-2160x3840.webp) |
| landscape-full-hd | 1920×1080 | [game](previews/game-landscape-full-hd-1920x1080.webp) | [home](previews/home-landscape-full-hd-1920x1080.webp) | [game](backgrounds/game-landscape-full-hd-1920x1080.webp), [home](backgrounds/home-landscape-full-hd-1920x1080.webp) |
| landscape-4k | 3840×2160 | [game](previews/game-landscape-4k-3840x2160.webp) | [home](previews/home-landscape-4k-3840x2160.webp) | [game](backgrounds/game-landscape-4k-3840x2160.webp), [home](backgrounds/home-landscape-4k-3840x2160.webp) |
| ultrawide | 3440×1440 | [game](previews/game-ultrawide-3440x1440.webp) | [home](previews/home-ultrawide-3440x1440.webp) | [game](backgrounds/game-ultrawide-3440x1440.webp), [home](backgrounds/home-ultrawide-3440x1440.webp) |
| square | 2048×2048 | [game](previews/game-square-2048x2048.webp) | [home](previews/home-square-2048x2048.webp) | [game](backgrounds/game-square-2048x2048.webp), [home](backgrounds/home-square-2048x2048.webp) |

## Fidelity and scope

- All colored blocks, source board/frame, controls, crown and logo are resampled from original repository files (sha256 in `inventory.json`).
- Board cell interiors are regenerated from the **actual** Flutter renderer math/gradient (not from AI imitation).
- Portrait coordinates follow `lib/game/layout_constants.dart` exactly; horizontal and square layouts reflow HUD/tray without distorting the game board.
- The widescreen decorative background **edges** are AI-assisted and the original center artwork is composited back on top. Original assets remain untouched.
- 4K files have exact 4K dimensions, but their pixel detail is upscaled from lower-resolution originals; they are not native-4K illustrations.
- These files are STATIC previews and bitmap backdrops, not Flutter gameplay screenshots, running app viewport changes, or separate APK/Steam builds.
- `catalog.webp` and `inventory.json` cover every image, and the JSON includes all original filenames, dimensions, manifest object usages and SHA256.
- No licensed content ownership is implied; rights must be checked before public distribution.

The next production step is to apply the same landscape/square layout transforms to the running Flame canvas AND pointer-hit-test input, then test on real displays.
