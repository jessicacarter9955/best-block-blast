import 'dart:math' as math;

/// Non-destructive, pixel-perfect viewport shell around the original 1080×1920
/// Flame scene. The interactive canvas ALWAYS keeps its original aspect ratio
/// and hit-test coordinates; decorative imagery fills the remaining viewport.
///
/// The separate, reflowed landscape compositions under artwork/resolution-pack
/// are previews: they cannot be used as interactive canvas hit-test geometry.
enum FrameFormat { portrait, landscape, ultrawide, square }

class ResponsiveGameFrame {
  const ResponsiveGameFrame({
    required this.width,
    required this.height,
    required this.gameLeft,
    required this.gameTop,
    required this.gameWidth,
    required this.gameHeight,
    required this.format,
    required this.backgroundAsset,
  });

  static const designWidth = 1080.0;
  static const designHeight = 1920.0;

  final double width;
  final double height;
  final double gameLeft;
  final double gameTop;
  final double gameWidth;
  final double gameHeight;
  final FrameFormat format;
  final String backgroundAsset;

  /// [width] and [height] are logical Flutter pixels, not physical pixels.
  /// Device pixel ratio chooses higher-resolution backgrounds when helpful.
  factory ResponsiveGameFrame.forSize({
    required double width,
    required double height,
    double devicePixelRatio = 1,
    bool home = true,
  }) {
    if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
      throw ArgumentError('A positive, finite viewport is required.');
    }
    final scale = math.min(width / designWidth, height / designHeight);
    final gameWidth = designWidth * scale;
    final gameHeight = designHeight * scale;
    final aspect = width / height;
    final format = aspect >= 2.2
        ? FrameFormat.ultrawide
        : aspect >= 1.25
            ? FrameFormat.landscape
            : aspect >= 0.80
                ? FrameFormat.square
                : FrameFormat.portrait;
    final pixelsWide = width * devicePixelRatio;
    final pixelsHigh = height * devicePixelRatio;
    final filename = switch (format) {
      FrameFormat.portrait =>
        pixelsWide >= 2160 && pixelsHigh >= 3840
            ? 'portrait-4k-2160x3840'
            : 'portrait-full-hd-1080x1920',
      FrameFormat.landscape =>
        pixelsWide >= 3840 && pixelsHigh >= 2160
            ? 'landscape-4k-3840x2160'
            : 'landscape-full-hd-1920x1080',
      FrameFormat.ultrawide => 'ultrawide-3440x1440',
      FrameFormat.square => 'square-2048x2048',
    };
    final scene = home ? 'home' : 'game';
    return ResponsiveGameFrame(
      width: width,
      height: height,
      gameLeft: (width - gameWidth) / 2,
      gameTop: (height - gameHeight) / 2,
      gameWidth: gameWidth,
      gameHeight: gameHeight,
      format: format,
      backgroundAsset:
          'artwork/resolution-pack/backgrounds/$scene-$filename.webp',
    );
  }
}
