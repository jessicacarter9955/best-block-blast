# UI update

- Replaced screenshot-derived button patches with crisp Canvas controls.
- Rebuilt pause and leaderboard panels in the game's blue palette; added Resume, labelled audio switches and a persistent personal-best row.
- Dragged blocks now grow to the board's 120-pixel cells instead of 178 pixels, including compact tray pieces, cancellation and return animations.
- Added nine drag regression tests (`flutter test`).

## Clean backgrounds

Created with the built-in ImageGen tool. Original assets are retained. The sprite manifest now references:

- `assets/sprites-named/BgHome-clean.png`
- `assets/sprites-named/Bg-clean.png`

Home prompt: "Use case: precise-object-edit. Edit target is attached portrait Block Rush home background. Preserve exact BLOCK RUSH logo, its position and all upper artwork and overall blue neon block art style. Clean ONLY the lower area below the logo: remove all obvious rectangular clone patches, erased play button patches, bottom circular icon rims, button arc remnants and UI artifacts. Replace these with a smoothly continuous deep navy/cobalt blue background matching the surrounding bokeh and edge decorative floating blocks. No new buttons, icons, text or objects. Keep the logo and top 60 percent unchanged. Deliver full portrait background, approximately 9:16, opaque."

Gameplay prompt: "Use case: precise-object-edit. Edit target is attached portrait blue game background. Remove ALL baked UI debris: little yellow crown/zero bottoms and white score arc at top, pause button remnant top right, all rectangular inpainting patches. Keep decorative blurred colorful blocks at outer edges, original navy/cobalt palette and soft neon atmosphere. Make central play area a continuous smooth quiet dark blue gradient, no rectangular patch edges. No text, numbers, buttons, UI controls, grid or board anywhere. Deliver clean full portrait game backdrop 9:16, opaque."

## Local preview

With Flutter on PATH, run from the project root:

```powershell
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5173
```

The additional `block-rush` repository is a separate Next.js project at `C:/Users/jessi/Downloads/block-rush`; start it with `npm run dev -- --hostname 127.0.0.1` (port 3000).
