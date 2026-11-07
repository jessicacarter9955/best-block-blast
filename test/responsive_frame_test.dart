import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:block_rush/game/responsive_frame.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all 12 selectable scene backgrounds are included in Flutter assets',
      () async {
    const viewports = <({double width, double height})>[
      (width: 1080, height: 1920),
      (width: 2160, height: 3840),
      (width: 1920, height: 1080),
      (width: 3840, height: 2160),
      (width: 3440, height: 1440),
      (width: 2048, height: 2048),
    ];
    final observedPaths = <String>{};

    for (final home in [true, false]) {
      for (final viewport in viewports) {
        final plan = ResponsiveGameFrame.forSize(
          width: viewport.width,
          height: viewport.height,
          home: home,
        );
        final path = plan.backgroundAsset;
        expect(observedPaths.add(path), isTrue, reason: 'duplicate asset: $path');
        final data = await rootBundle.load(path);
        expect(data.lengthInBytes, greaterThan(32), reason: path);
        expect(
          String.fromCharCodes(
              data.buffer.asUint8List(data.offsetInBytes, 4)),
          'RIFF',
          reason: 'background must be a readable WebP: $path',
        );
      }
    }
    expect(observedPaths, hasLength(12));
  });

  test('original 1080×1920 canvas remains exact on portrait', () {
    final f = ResponsiveGameFrame.forSize(width: 1080, height: 1920);
    expect(f.format, FrameFormat.portrait);
    expect(f.gameLeft, 0);
    expect(f.gameTop, 0);
    expect(f.gameWidth, 1080);
    expect(f.gameHeight, 1920);
    expect(f.backgroundAsset, contains('home-portrait-full-hd'));
  });

  test('tall smartphone fits without cropping or changing touch scale', () {
    final f = ResponsiveGameFrame.forSize(width: 360, height: 800);
    expect(f.gameWidth, closeTo(360, 0.001));
    expect(f.gameHeight, closeTo(640, 0.001));
    expect(f.gameTop, closeTo(80, 0.001));
  });

  test('desktop landscape uses extended art and undistorted portrait game', () {
    final f = ResponsiveGameFrame.forSize(
        width: 1920, height: 1080, home: false);
    expect(f.format, FrameFormat.landscape);
    expect(f.backgroundAsset, contains('game-landscape-full-hd'));
    expect(f.gameWidth, closeTo(607.5, 0.001));
    expect(f.gameHeight, closeTo(1080, 0.001));
    expect(f.gameLeft, closeTo(656.25, 0.001));
  });

  test('4k physical density selects the 4k background', () {
    final f = ResponsiveGameFrame.forSize(
        width: 1920, height: 1080, devicePixelRatio: 2);
    expect(f.backgroundAsset, contains('landscape-4k-3840x2160'));
  });

  test('21:9, square and portrait 4k each select the corresponding image', () {
    final wide = ResponsiveGameFrame.forSize(width: 3440, height: 1440);
    final square = ResponsiveGameFrame.forSize(width: 2048, height: 2048);
    final portrait = ResponsiveGameFrame.forSize(width: 1080, height: 1920,
        devicePixelRatio: 2);
    expect(wide.format, FrameFormat.ultrawide);
    expect(wide.backgroundAsset, contains('ultrawide-3440x1440'));
    expect(square.format, FrameFormat.square);
    expect(square.backgroundAsset, contains('square-2048x2048'));
    expect(portrait.backgroundAsset, contains('portrait-4k-2160x3840'));
    for (final frame in [wide, square, portrait]) {
      expect(frame.gameLeft, greaterThanOrEqualTo(0));
      expect(frame.gameTop, greaterThanOrEqualTo(0));
      expect(frame.gameLeft + frame.gameWidth, lessThanOrEqualTo(frame.width));
      expect(frame.gameTop + frame.gameHeight, lessThanOrEqualTo(frame.height));
      expect(frame.gameWidth / frame.gameHeight,
          closeTo(ResponsiveGameFrame.designWidth /
              ResponsiveGameFrame.designHeight, 1e-10));
    }
  });

  test('zero and NaN viewports are rejected rather than causing a crash', () {
    expect(() => ResponsiveGameFrame.forSize(width: 0, height: 1080),
        throwsArgumentError);
    expect(() => ResponsiveGameFrame.forSize(width: double.nan, height: 1920),
        throwsArgumentError);
  });
}
