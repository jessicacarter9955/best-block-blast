import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, RRect, Radius, Rect, Image;

/// Chocolate palette for Block Blast — used for cell highlight previews
/// and Flutter overlay colors. The actual block rendering uses the
/// original Block sprite frames (already recolored to this palette
/// via the recolor_blocks.py script).
class BlockPalette {
  BlockPalette._();

  static const Color bg          = Color(0xFF0A1119);
  static const Color gridCell    = Color(0xFF1F2A4E);
  static const Color gridBorder  = Color(0xFF3E559F);
  static const Color text        = Color(0xFFE5E7EB);
  static const Color textMuted   = Color(0xFF6B7280);

  // 8 block frame indices in the Block sprite. The recolored
  // block-sheet0.png already maps them to: gold, brown, green, sky,
  // cream, purple, sky (reused), purple (reused).
  static const int kBlockVariants = 8;

  // Approximate base color for each frame — used for the preview
  // overlay when dragging a piece (semi-transparent fill on cells).
  static const List<Color> blockColors = [
    Color(0xFFBF7ECA), // frame 0 — purple
    Color(0xFF9B5738), // frame 1 — brown
    Color(0xFFFAB82A), // frame 2 — gold
    Color(0xFFF2E8BD), // frame 3 — cream
    Color(0xFFCCE8FA), // frame 4 — sky
    Color(0xFF699627), // frame 5 — green
    Color(0xFFCCE8FA), // frame 6 — sky (reused)
    Color(0xFFBF7ECA), // frame 7 — purple (reused)
  ];
}
