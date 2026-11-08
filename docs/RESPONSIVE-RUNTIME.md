# Block Rush: runtime viewport integration (six resolutions)

The original Flutter/Flame game is a fixed **1080×1920** logical scene. All
in-game touch hitboxes, block dragging, HUD, board cells and animation paths
depend on that coordinate system.

The new `ResponsiveGameFrame` provides a **safe adaptive outer frame**:

1. It keeps the interactive game at its **original 9:16 ratio**, using Flame's
   existing fixed-resolution viewport. Input/touch remains in original game
   coordinates on every display.
2. It fills otherwise empty screen space with the corresponding game/Home
   backdrop from the generated artwork pack, for portrait, landscape, 4K,
   ultrawide and square devices.
3. It selects 4K backgrounds only when the physical display resolution supports
   them; the more compact Full HD assets are preferred elsewhere.
4. It switches to the appropriate Home/Game artwork when the game state changes;
   this outer artwork is not interactive.

## Screen variants

| Viewport | Outer image | Interactive gameplay |
| --- | --- | --- |
| Portrait Full HD | `1080×1920` | 1080×1920 reference geometry, scaled to fit |
| Portrait 4K | `2160×3840` | Same geometry, high-density backdrop |
| Landscape Full HD | `1920×1080` | 9:16 portrait game centered, original controls |
| Landscape 4K | `3840×2160` | 9:16 portrait game centered, original controls |
| Ultrawide | `3440×1440` | 9:16 portrait game centered, original controls |
| Square | `2048×2048` | 9:16 portrait game centered, original controls |

**Important limitation:** the landscape/square *mockup images* reflow the
board, tray and HUD into separate zones, but **the live Flame game does not yet
reflow those regions**. Implementing those variants in the actual game requires
coordinated renderer and inverse hit-test coordinate transforms, plus a device
test pass. A static preview alone cannot certify this functionality.

No changes were made to the original sprites, block logic, score, Playgama
bridge or save data. The only runtime changes are the decorative outer image
and aspect-preserving sizing of `GameWidget`.

## Testing

`flutter test test/responsive_frame_test.dart`

This covers the six format assignments, centering, portrait reference geometry,
physical pixel density selection, non-clipping and invalid viewport rejection.

Manual QA is still required on Chrome (mobile/desktop), Android, and any
Playgama host where fullscreen/iframe dimensions may differ from the window.

Android's generated release manifest now uses `screenOrientation="user"`
instead of a forced portrait lock. This permits rotation when the user's
device settings allow it, without overriding a system rotation lock.

The Flutter web entry point now declares the real device-width viewport and
disables page scroll/overscroll around the canvas. The browser no longer has
to infer a default desktop-width viewport on narrow phones.

## Desktop distribution without Steam

`.github/workflows/build-desktop.yml` prepares portable Windows ZIP and Linux
TAR.GZ builds in two independent GitHub Actions jobs. It regenerates platform
boilerplate at build time (this repository does not track `windows/` or
`linux/`), runs Flutter tests, and uploads the executables as CI artifacts.
The workflow runs on main/master pushes and supports manual dispatch from the
Actions tab. No Steam Direct registration is involved. These are **not**
installer, signed, or Steam builds; they should undergo manual first-run QA
and may trigger unsigned-app warnings on Windows.
