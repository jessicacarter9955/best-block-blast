import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, RRect, Radius, Rect;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/widgets.dart';
import 'package:flutter/material.dart' show runApp, MaterialApp, Scaffold, runApp, debugShowCheckedModeBanner;
import 'package:flutter/material.dart' as flutter;

import 'sprite_cache.dart';
import 'sprite_manifest.dart';
import 'shapes.dart';

/// Session 1 of the multi-session Flame port of Block Blast.
///
/// Goal of this build: prove that we can load every Construct 3
/// sprite from the manifest, render them on a Flame canvas, and
/// display a "session 1 complete" splash showing all extracted
/// sprites as a contact sheet. Future sessions will turn this
/// into the actual playable game.
///
/// The session-1 build is intentionally a visual smoke test —
/// not the final gameplay. It's a checkpoint so the user can verify
/// the sprite pipeline works before we invest in gameplay logic.
class BlockBlastGame extends FlameGame {
  late SpriteCache _sprites;

  @override
  Future<void> onLoad() async {
    _sprites = await SpriteCache.load();
    // Add a scrollable contact-sheet of all extracted sprites so the
    // user can verify visually what we have to work with.
    add(_SpriteContactSheet(_sprites));
  }

  @override
  Color backgroundColor() => const Color(0xFF0A1119);
}

class _SpriteContactSheet extends PositionComponent {
  final SpriteCache sprites;
  _SpriteContactSheet(this.sprites);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final w = game.size.x;
    final h = game.size.y;

    // Header text
    final header = flutter.TextPainter(
      text: flutter.TextSpan(
        text: 'Session 1 — ${sprites.objectNames.length} sprites loaded',
        style: const flutter.TextStyle(
          color: flutter.Color(0xFFFAB82A),
          fontSize: 18,
          fontWeight: flutter.FontWeight.w700,
        ),
      ),
      textDirection: flutter.TextDirection.ltr,
    )..layout();
    header.paint(canvas, const Offset(16, 16));

    final sub = flutter.TextPainter(
      text: flutter.TextSpan(
        text: 'Next session: render grid + board + block sprites + tray',
        style: const flutter.TextStyle(
          color: flutter.Color(0xFF6B7280),
          fontSize: 11,
        ),
      ),
      textDirection: flutter.TextDirection.ltr,
    )..layout();
    sub.paint(canvas, Offset(16, 16 + header.height + 4));

    // Grid of sprites — 6 columns
    final cols = 6;
    final padding = 8.0;
    final top = 16 + header.height + sub.height + 20;
    final cellW = (w - padding * (cols + 1)) / cols;
    final cellH = cellW; // square cells

    // Sort object names alphabetically for stable layout
    final names = sprites.objectNames.toList()..sort();
    final rowH = cellH + 22; // extra for label
    for (int i = 0; i < names.length; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      final x = padding + col * (cellW + padding);
      final y = top + row * rowH;
      if (y > h - rowH) break; // off-screen; can't scroll yet

      final name = names[i];
      final sprite = sprites.get(name);
      final srcSize = sprite.srcSize;
      // Fit sprite into cell preserving aspect ratio
      final scaleW = cellW / srcSize.x;
      final scaleH = cellH / srcSize.y;
      final scale = scaleW < scaleH ? scaleW : scaleH;
      final drawW = srcSize.x * scale;
      final drawH = srcSize.y * scale;
      final dx = x + (cellW - drawW) / 2;
      final dy = y + (cellH - drawH) / 2;

      // Cell border
      final cellRect = Rect.fromLTWH(x, y, cellW, cellH);
      final cellRrect = RRect.fromRectAndRadius(cellRect, const Radius.circular(6));
      canvas.drawRRect(cellRrect, Paint()..color = const Color(0x3323344F));
      canvas.drawRRect(cellRrect, Paint()
        ..color = const Color(0xFF3E559F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5);

      // Sprite itself
      sprite.render(
        canvas,
        position: Vector2(dx, dy),
        size: Vector2(drawW, drawH),
      );

      // Label
      final label = flutter.TextPainter(
        text: flutter.TextSpan(
          text: name,
          style: const flutter.TextStyle(
            color: flutter.Color(0xFFE5E7EB),
            fontSize: 9,
            fontWeight: flutter.FontWeight.w500,
          ),
        ),
        textDirection: flutter.TextDirection.ltr,
        maxLines: 1,
        ellipsis: '..',
      )..layout(maxWidth: cellW);
      label.paint(canvas, Offset(x + 2, y + cellH + 2));
    }
  }
}
