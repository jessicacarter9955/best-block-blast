import 'dart:ui';

/// Block Rush 1:1 colors — sampled from the two reference screenshots
/// (Task 22: gameplay 941×1672 + home 942×1670), the same values as the
/// web preset 'rush' (src/lib/skin.ts).
///
/// Frame order (matches the extracted Block tiles — TRUE reference palette):
///   0 viola, 1 azzurro, 2 verde, 3 blu,
///   4 viola scuro, 5 arancione, 6 rosso, 7 rosa
class BlockPalette {
  BlockPalette._();

  static const int kBlockVariants = 8;

  /// Base color of each Block sprite frame (used for the drag-preview tint,
  /// line-clear effect colors and square particles).
  static const List<Color> blockColors = [
    Color(0xFFB03FFD), // frame 0 — viola       (176, 63, 253)
    Color(0xFF03C0FD), // frame 1 — azzurro     (3, 192, 253)
    Color(0xFF10D931), // frame 2 — verde       (16, 217, 49)
    Color(0xFF1653FC), // frame 3 — blu         (22, 83, 252)
    Color(0xFF5C27BD), // frame 4 — viola scuro (92, 39, 189)
    Color(0xFFFC8418), // frame 5 — arancione   (252, 132, 24)
    Color(0xFFE31F2C), // frame 6 — rosso       (227, 31, 44)
    Color(0xFFDE3CEF), // frame 7 — rosa        (222, 60, 239)
  ];

  // Screen chrome colors (Block Rush 1:1 theme).
  static const Color bg = Color(0xFF0A1755); // navy board night
  static const Color gridCell = Color(0xFF0A1755);
  static const Color text = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFF8FA3D9);
  static const Color accent = Color(0xFF3FE8FE); // neon ciano (board frame)
  static const Color gold = Color(0xFFFDF303); // cifre best (dal reference)
  static const Color scoreStroke = Color(0xFF0A2BB0); // bordo blu dello score (ref)
  static const Color popup = Color(0xFF2E1B5E); // superficie pannelli

  /// Nel gameplay di riferimento non c'è il cuore dietro lo score.
  static const bool showHeart = false;
}
