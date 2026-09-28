import 'dart:ui';

/// Block Blast Rosso 1:1 — colori campionati dallo screenshot REALE
/// dell'utente (1536×2730, tema rosso caramella).
///
/// Frame order (matches the Block sprites):
///   0 latte, 1 menta, 2 lime, 3 fondente,
///   4 giallo, 5 arancio, 6 rosso, 7 rosa
class BlockPalette {
  BlockPalette._();

  static const int kBlockVariants = 8;

  /// Base color of each Block sprite frame (used for the drag-preview tint,
  /// line-clear effect colors and square particles).
  static const List<Color> blockColors = [
    Color(0xFF621F08), // frame 0 — latte    (98, 31, 8)
    Color(0xFF0CBEB1), // frame 1 — menta    (12, 190, 177)
    Color(0xFF85A700), // frame 2 — lime     (133, 167, 0)
    Color(0xFF4B1804), // frame 3 — fondente (75, 24, 4)
    Color(0xFFFED715), // frame 4 — giallo   (254, 215, 21)
    Color(0xFFFC6604), // frame 5 — arancio  (252, 102, 4)
    Color(0xFFD62549), // frame 6 — rosso    (214, 37, 73)
    Color(0xFFE02C54), // frame 7 — rosa     (224, 44, 84)
  ];

  // Screen chrome colors (Block Blast Rosso theme).
  static const Color bg = Color(0xFFB11524); // gradient top (strip has the real gradient)
  static const Color gridCell = Color(0xFF930D17); // empty cell red
  static const Color text = Color(0xFFFFFFFF);
  static const Color textMuted = Color(0xFFF5C6CB);
  static const Color accent = Color(0xFFE2314E); // glossy red buttons
  static const Color gold = Color(0xFFD4AF37); // gold ring / best score
}
