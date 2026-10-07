# YouTube Playables branch

This branch builds the original Lumen Loom puzzle in responsive portrait and landscape layouts. The browser build used for testing is not the Playables release: the workflow adds the official SDK script to the packaged HTML and the app then uses platform save, language, lifecycle, rewarded-ad and interstitial APIs.

## Checks completed by CI

- Flutter tests and release web compilation.
- SDK script placement before Flutter bootstrap.
- Packaged file count and supported path characters.
- ZIP size below the current 30 MiB initial-download limit.

## Account-owner checks before submission

- Confirm Playables access, package the latest artifact, and run YouTube's current SDK validation tools.
- Verify the game at real portrait and landscape sizes, including rotation, touch input and safe areas.
- Verify first-frame/game-ready timing, mute state, pause/resume, cloud save restore and ad outcomes in the YouTube host.
- Review the content rating, privacy disclosures, title, icon and store listing.
- Clear the product name and every shipped asset for ownership and trademark conflicts.

The game contains no audio playback. The SDK audio-state event is observed so the host lifecycle remains connected; adding sound later requires honoring the host's enabled/disabled state.
