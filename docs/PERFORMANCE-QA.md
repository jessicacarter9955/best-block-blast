# Performance QA — Web, Playgama, Android and desktop

## Automated free check

The manual GitHub Actions workflow **Audit Flutter Web Performance
(Lighthouse)** builds the production Flutter web game and runs headless Chrome
against a local-only HTTP server. Download the HTML/JSON performance report
from the workflow artifacts. It does not send assets to public audit services.

Lighthouse measures initial page loading and main-thread behavior. It does
**not** certify gameplay frame rate, touch latency, thermal throttling or
rendered correctness. Do not treat its score as a 60 FPS guarantee.

## Manual release gates

| Environment | Test | Proposed pass criterion |
| --- | --- | --- |
| Mobile web / Playgama | Portrait and landscape physical phones; no clipped tray or button | All controls visible and tappable |
| Android | Mid-range physical Android device, release/profile build | Smooth gameplay, no ANR or stutter during line clears |
| Desktop | 1920×1080, 3440×1440, and 3840×2160 | No stretched art; functional mouse/touch input |
| Game loop | Flutter DevTools Performance / GPU raster charts | Target 60 FPS with no sustained frame spikes |
| Distribution | Open built archive on its target platform | No missing audio, fonts, sprites or SDK initialization |

Keep measured device, browser, frame-time percentiles and build SHA in the
release report. Until tests have run against physical devices, performance
remains **unverified**.
