import 'dart:ui';

/// Block Rush 1:1 colors — sampled from the two reference screenshots
/// (Task 22: gameplay 941×1672 + home 942×1670), the same values as the
/// web preset 'rush' (src/lib/skin.ts).
///
/// Frame order (matches the extracted Block tiles):
///   0 viola, 1 azzurro, 2 verde, 3 giallo,
///   4 arancione, 5 rosso, 6 rosa, 7 blu
class BlockPalette {
  BlockPalette._();

  static const int kBlockVariants = 8;

  /// Base color of each Block sprite frame (used for the drag-preview tint,
  /// line-clear effect colors and square particles).
  static const List<Color> blockColors = [
    Color(0xFFAC39FC), // frame 0 — viola      (172, 57, 252)
    Color(0xFF03BEFD), // frame 1 — azzurro    (3, 190, 253)
    Color(0xFF0DD830), // frame 2 — verde      (13, 216, 48)
    Color(0xFFFCEA27), // frame 3 — giallo     (252, 234, 39)
    Color(0xFFFC8115), // frame 4 — arancione  (252, 129, 21)
    Color(0xFFE31D2C), // frame 5 — rosso      (227, 29, 44)
    Color(0xFFDE3BEF), // frame 6 — rosa       (222, 59, 239)
    Color(0xFF1451FD), // frame 7 — blu        (20, 81, 253)
  ];

  // Screen chrome colors (Block Rush 1:1 theme).
  static const Color bg = Color(0xFF0A1755); // navy board night
  static const Color gridCell = Color(0xFF0A1755);
  static const Color text = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFF8FA3D9);
  static const Color accent = Color(0xFF3FE8FE); // neon ciano (board frame)
  static const Color gold = Color(0xFFFFC94D); // corona / best / bottoni
  static const Color scoreStroke = Color(0xFF2E7FE8); // bordo blu dello score
  static const Color popup = Color(0xFF2E1B5E); // superficie pannelli

  /// Nel gameplay di riferimento non c'è il cuore dietro lo score.
  static const bool showHeart = false;
}
