import 'package:flutter/material.dart';

/// Chocolate-themed palette for the Block Blast port.
///
/// Six base colors with matching shadow / highlight variants for the
/// 3D shaded block look. The palette is exposed as a list of
/// [BlockColor] records so the game can iterate them when spawning
/// random pieces.
class BlockPalette {
  BlockPalette._();

  // ---- Base palette (matches the user's uploaded screenshot) ----
  static const Color bg          = Color(0xFF0A1119); // page background
  static const Color gridCell    = Color(0xFF1F2A4E); // empty grid cell
  static const Color gridBorder  = Color(0xFF3E559F); // grid border / blue UI
  static const Color text        = Color(0xFFE5E7EB);
  static const Color textMuted   = Color(0xFF6B7280);

  // ---- Block colors (each with a base, shadow, and highlight) ----
  static const List<BlockColor> blocks = [
    BlockColor(name: 'gold',   base: Color(0xFFFAB82A), shadow: Color(0xFF7D5809), highlight: Color(0xFFFFD472)),
    BlockColor(name: 'brown',  base: Color(0xFF9B5738), shadow: Color(0xFF5D2F18), highlight: Color(0xFFC97A56)),
    BlockColor(name: 'green',  base: Color(0xFF699627), shadow: Color(0xFF3D5814), highlight: Color(0xFF9BC64A)),
    BlockColor(name: 'sky',    base: Color(0xFFCCE8FA), shadow: Color(0xFF7FA7BD), highlight: Color(0xFFFFFFFF)),
    BlockColor(name: 'cream',  base: Color(0xFFF2E8BD), shadow: Color(0xFFA39A7E), highlight: Color(0xFFFFFFFF)),
    BlockColor(name: 'purple', base: Color(0xFFBF7ECA), shadow: Color(0xFF73407C), highlight: Color(0xFFE0B7E8)),
  ];
}

/// One block color with its 3-tone shading.
class BlockColor {
  final String name;
  final Color base;
  final Color shadow;
  final Color highlight;

  const BlockColor({
    required this.name,
    required this.base,
    required this.shadow,
    required this.highlight,
  });
}
