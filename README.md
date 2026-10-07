# Lumen Loom

Lumen Loom is an original light-routing puzzle: rotate mirrors to guide a beam through every crystal and out through the target edge. The board and controls reflow between portrait and landscape layouts.

## Run locally

```sh
flutter pub get
flutter run -d chrome
flutter test
```

## YouTube Playables build

The `codex/youtube-playables` branch loads the YouTube Playables SDK before Flutter and connects host language, pause/resume, cloud save, rewarded hints and interstitials. Its GitHub Actions workflow creates a test ZIP and checks the archive size, file count and paths. These checks do not replace YouTube's SDK test suite or submission review.

```sh
flutter build web --release --base-href / --dart-define=YOUTUBE_PLAYABLES_BUILD=true
python3 tool/prepare_youtube_playables.py
```

## Before submitting

- Confirm developer access to YouTube Playables and run the current SDK test suite and bundle analyzer in its portal.
- Test both orientations, resize/rotation, touch, pause/resume, save restoration and rewarded-ad behavior in the actual host.
- Review the title and artwork for trademark conflicts, and confirm ownership of every item you add before shipping.
- Complete the platform's content, privacy, age-rating and store metadata checks; these require the account owner.

The current Playables branch is a technical prototype. A successful local or CI build is not platform approval.
