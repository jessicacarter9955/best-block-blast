import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/material.dart' show Icons, IconData;

import 'block_blast_game.dart';
import 'layout_constants.dart';
import 'palette.dart';
import 'shapes.dart';

/// All rendering — a visual 1:1 of the original layers:
/// Bg -> Shadow -> Game -> Tut -> HUD -> Pause -> Revive -> GameOver -> Ranking.
extension GameRendering on BlockBlastGame {
  void renderWorld(Canvas canvas) {
    _drawBackground(canvas);
    if (state == GameState.home) {
      _drawHome(canvas);
      _drawRankingOverlay(canvas);
      return;
    }
    _drawBoard(canvas);
    _drawTray(canvas);
    _drawTutorialHint(canvas);
    _drawHud(canvas);
    _drawBlackBg(canvas);
    _drawNoSpaceBanner(canvas);
    _drawReviveOverlay(canvas);
    _drawGameOverOverlay(canvas);
    _drawPauseOverlay(canvas);
    _drawRankingOverlay(canvas);
  }

  // =====================================================================
  //  Background (original: Bg tiled gradient + Responsive)
  // =====================================================================

  void _drawBackground(Canvas canvas) {
    // 1:1: la home usa lo sfondo bokeh della home di riferimento, il gameplay
    // quello della schermata di gioco (entrambi estratti dagli screenshot).
    final isHome = state == GameState.home;
    final bg = sprites.get(isHome ? 'BgHome' : 'Bg');
    bg.render(canvas,
        position: Vector2.zero(), size: Vector2(Design.width, Design.height));
  }

  // =====================================================================
  //  Board (original layer "Game")
  // =====================================================================

  void _drawBoard(Canvas canvas) {
    // 1:1: frame neon 1086×1086 con glow esterno, centrato sulla board:
    // l'area celle (960px a offset 63) coincide coi centri spot 60..1020.
    final board = sprites.get('Board');
    board.render(
      canvas,
      position: Vector2(Design.boardArtL, Design.boardArtT),
      size: Vector2(Design.boardArtW, Design.boardArtH),
    );

    // 1:1: l'interno della board (celle + separatori) è già dentro lo sprite
    // Board — nessuno Spot da disegnare sopra.

    // Drag preview: BlockBelow (30% opacity, piece color) on target cells.
    if (dragSlot >= 0 && dragValid && dragTargets.isNotEmpty) {
      final slot = tray[dragSlot]!;
      final preview = sprites.get('BlockBelow', frame: slot.colorIdx);
      final previewPaint = Paint()..color = const Color(0x4DFFFFFF);
      canvas.saveLayer(null, previewPaint);
      for (final cell in dragTargets) {
        final cx = Design.gridOriginX + cell.x * Design.bigSize;
        final cy = Design.gridOriginY + cell.y * Design.bigSize;
        preview.render(
          canvas,
          position: Vector2(cx - Design.bigSize / 2, cy - Design.bigSize / 2),
          size: Vector2(Design.bigSize, Design.bigSize),
        );
      }
      canvas.restore();
    }

    // Placed blocks. Blocks in lines marked during the drag render in the
    // dragged piece's color (original CheckRowsCols recoloring).
    final draggingSlot = dragSlot >= 0 ? tray[dragSlot] : null;
    for (var y = 0; y < Design.gridSize; y++) {
      for (var x = 0; x < Design.gridSize; x++) {
        var colorIdx = grid[y][x];
        if (colorIdx == null) continue;
        if (draggingSlot != null && dragValid) {
          final inMarkedRow = dragMarkedLines.contains('R$y');
          final inMarkedCol = dragMarkedLines.contains('C$x');
          if (inMarkedRow || inMarkedCol) {
            colorIdx = draggingSlot.colorIdx;
          }
        }
        final block = sprites.get('Block', frame: colorIdx);
        var cx = Design.gridOriginX + x * Design.bigSize;
        var cy = Design.gridOriginY + y * Design.bigSize;
        // Settle animation: tiny pop when the piece lands (0.1s).
        final settle = settleCells[math.Point(x, y)];
        if (settle != null && settle < 1) {
          final s = 0.9 + 0.1 * settle;
          canvas.save();
          canvas.translate(cx, cy);
          canvas.scale(s, s);
          canvas.translate(-cx, -cy);
        }
        block.render(
          canvas,
          position: Vector2(cx - Design.bigSize / 2, cy - Design.bigSize / 2),
          size: Vector2(Design.bigSize, Design.bigSize),
        );
        if (settle != null && settle < 1) {
          canvas.restore();
        }
      }
    }

    // Line clear effects (LineEffect + GlowEffect bars).
    for (final fx in lineFx) {
      _drawLineEffect(canvas, fx);
    }

    // Square particles — 1:1 with the original CreateSquareEffect:
    // linear movement from the spawn point toward (spawn + v) over [dur],
    // opacity 100 -> 0 over exactly 1s (destroy at 1s), fixed size.
    final squarePaint = Paint();
    for (final s in squares) {
      final moveFrac = (s.t / s.dur).clamp(0.0, 1.0);
      final alpha = (1 - s.t).clamp(0.0, 1.0);
      squarePaint.color =
          Color.fromRGBO(s.color.r, s.color.g, s.color.b, alpha);
      canvas.drawRect(
        Rect.fromCenter(
          center: _off(s.x + s.vx * moveFrac, s.y + s.vy * moveFrac),
          width: s.size,
          height: s.size,
        ),
        squarePaint,
      );
    }

    // Spawn particles (white-ish dots from piece creation).
    for (final p in particles) {
      final alpha = (1 - p.t / p.life).clamp(0.0, 1.0);
      squarePaint.color = Color.fromRGBO(255, 255, 255, alpha * 0.8);
      canvas.drawCircle(
          _off(p.x, p.y), 6 * (1 - p.t / p.life) + 2, squarePaint);
    }

    // Circle glow bursts at piece spawn (original CircleGlow: scale 0 -> 300,
    // opacity 0 -> 30).
    for (final g in glowBursts) {
      final t = (g.t / 0.4).clamp(0.0, 1.0);
      final radius = 300 * t;
      final alpha = 30 * (1 - t) / 100;
      final paint = Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
      canvas.drawCircle(_off(g.x, g.y), radius, paint);
    }
  }

  /// Original LineEffect: colored ninepatch bar sweeping the cleared line —
  /// opacity 30 -> 100, width -> board-45, then height -> 120, then fade out.
  void _drawLineEffect(Canvas canvas, LineFx fx) {
    final t = fx.t;
    final length = (Design.boardSize - 45) * math.min(1.0, t / 0.1);
    var opacity = 0.30 + 0.70 * math.min(1.0, t / 0.1);
    var height = 25.0;
    if (t > 0.1 && t < 0.3) {
      height = 25 + (Design.bigSize - 25) * ((t - 0.1) / 0.08).clamp(0.0, 1.0);
    } else if (t >= 0.3) {
      height = Design.bigSize.toDouble();
      opacity = (1 - (t - 0.3) / 0.2).clamp(0.0, 1.0);
    }
    if (opacity <= 0) return;
    final paint = Paint()
      ..color = Color.fromRGBO(fx.color.r, fx.color.g, fx.color.b, opacity);
    final glow = Paint()
      ..color =
          Color.fromRGBO(fx.color.r, fx.color.g, fx.color.b, opacity * 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    if (fx.horizontal) {
      final y = fx.pos;
      final rect = Rect.fromCenter(
        center: _off(Design.boardX, y),
        width: length,
        height: height,
      );
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(12)), glow);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(12)), paint);
    } else {
      final x = fx.pos;
      final rect = Rect.fromCenter(
        center: _off(x, Design.boardY),
        width: height,
        height: length,
      );
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(12)), glow);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(12)), paint);
    }
  }

  // =====================================================================
  //  Tray (original: PlaceHolders + pieces with shadows)
  // =====================================================================

  void _drawTray(Canvas canvas) {
    for (var i = 0; i < 3; i++) {
      final ph = slotCenter(i);
      // 1:1: nessun PlaceHolder visibile — i pezzi fluttuano sullo sfondo
      // bokeh esattamente come nella screenshot di riferimento.
      final slot = tray[i];
      if (slot == null || slot.placed) continue;
      if (i == dragSlot) continue; // drawn separately on top

      // Returning animation (0.3s, ease-out) + pop-in scale.
      var center = ph;
      var scale = trayScaleFor(slot); // 1:1 web: clamp forme larghe
      if (dragReturnT >= 0 && i == returningSlot) {
        final t = dragReturnT.clamp(0.0, 1.0);
        final eased = 1 - (1 - t) * (1 - t);
        center = Vector2(
          returnFrom.x + (ph.x - returnFrom.x) * eased,
          returnFrom.y + (ph.y - returnFrom.y) * eased,
        );
        scale = returnScale + (trayScaleFor(slot) - returnScale) * eased;
      } else if (slot.popT < 1) {
        scale =
            slot.popT * trayScaleFor(slot); // pop-in (0.3s, advanced in update)
      }
      _drawPiece(canvas, slot, center, scale, withShadow: false);
    }

    // Dragged piece on top, big cells, no shadow (original hides shadows
    // while dragging).
    if (dragSlot >= 0) {
      final slot = tray[dragSlot];
      if (slot != null) {
        _drawPiece(canvas, slot, dragPos, dragScale, withShadow: false);
      }
    }
  }

  /// Draws a piece's blocks with cells of [cell] px centered on [center].
  void _drawPiece(Canvas canvas, TraySlot slot, Vector2 center, double scale,
      {required bool withShadow}) {
    final shape = kShapes[slot.shapeIdx];
    final rows = shape.length;
    final cols = shape[0].length;
    final cell = Design.smallSize * scale;
    final block = sprites.get('Block', frame: slot.colorIdx);
    final shadow = sprites.get('BlockShadow');
    final shadowOff = cell * 0.13; // original 8px offset on 60px blocks
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (shape[r][c] == 0) continue;
        final cx = center.x + (c - (cols - 1) / 2) * cell;
        final cy = center.y + (r - (rows - 1) / 2) * cell;
        if (withShadow) {
          shadow.render(
            canvas,
            position:
                Vector2(cx - cell / 2 + shadowOff, cy - cell / 2 + shadowOff),
            size: Vector2(cell, cell),
          );
        }
        block.render(
          canvas,
          position: Vector2(cx - cell / 2, cy - cell / 2),
          size: Vector2(cell, cell),
        );
      }
    }
  }

  // =====================================================================
  //  Tutorial hint (original layer "Tut": Hand + TutBlock ghost)
  // =====================================================================

  void _drawTutorialHint(Canvas canvas) {
    if (!tutorial.active || state != GameState.hud) return;
    if (dragSlot >= 0) return;
    final slot = tray[1];
    if (slot == null || slot.placed) return;

    // Hint cycle: move the ghost from the tray to the target, fade, repeat.
    final cycle = tutHintT % 2.2;
    var moveT = 0.0;
    var fade = 1.0;
    if (cycle < 0.5) {
      moveT = cycle / 0.5;
    } else if (cycle < 0.7) {
      moveT = 1;
    } else if (cycle < 1.0) {
      moveT = 1;
      fade = 1 - (cycle - 0.7) / 0.3;
    } else {
      return; // pause before recreating the hand (original 1.2s timer)
    }

    // Target cell for the current step.
    math.Point<int>? target;
    if (tutorial.tutNum == 1) target = const math.Point(4, 4);
    if (tutorial.tutNum == 2) target = const math.Point(4, 4);
    if (tutorial.tutNum == 3) target = const math.Point(3, 3);
    if (target == null) return;

    final ph = slotCenter(1);
    final tx = Design.gridOriginX + target.x * Design.bigSize;
    final ty = Design.gridOriginY + target.y * Design.bigSize;
    final eased = 1 - (1 - moveT) * (1 - moveT);
    final gx = ph.x + (tx - ph.x) * eased;
    final gy = ph.y + (ty - ph.y) * eased;
    final trayScale = trayScaleFor(slot);
    final scale = trayScale + (boardPieceScale - trayScale) * eased;

    canvas.saveLayer(
        null, Paint()..color = Color.fromRGBO(255, 255, 255, fade));
    // Ghost piece (TutBlock, 50% opacity).
    canvas.saveLayer(null, Paint()..color = const Color(0x80FFFFFF));
    _drawPiece(canvas, slot, Vector2(gx, gy), scale, withShadow: false);
    canvas.restore();
    // Hand sprite, hotspot near top-left (original 0.088, 0.098).
    final hand = sprites.get('Hand');
    final handSize = hand.srcSize;
    hand.render(
      canvas,
      position: Vector2(gx - handSize.x * 0.09, gy - handSize.y * 0.10),
      size: handSize,
    );
    canvas.restore();
  }

  // =====================================================================
  //  HUD (original layer "HUD")
  // =====================================================================

  void _drawHud(Canvas canvas) {
    if (state == GameState.home) return;

    // Heart behind the score (original Heart at (540, 210), Sine pulse).
    // 1:1: nello screen di riferimento non c'è → nascosto.
    if (BlockPalette.showHeart && heartVisible) {
      final heart = sprites.get('Heart');
      final pulse = 1 + 0.08 * math.sin(heartPulse * 6.4);
      final s = Design.heartSize * pulse;
      heart.render(
        canvas,
        position: Vector2(Design.heartX - s / 2, Design.heartY - s / 2),
        size: Vector2(s, s),
      );
    }

    // Score (1:1: cifre bianche con bordo blu come nel riferimento).
    _drawGameText(
      canvas,
      scoreShown.toInt().toString(),
      Design.width / 2,
      Design.txtScoreY,
      172,
      BlockPalette.text,
      BlockPalette.scoreStroke,
      14,
    );

    // Best score: crown + cifre oro (1:1).
    final cup = sprites.get('CupIcon');
    cup.render(
      canvas,
      position: Vector2(
          Design.cupX - Design.cupSize / 2, Design.cupY - Design.cupH / 2),
      size: Vector2(Design.cupSize, Design.cupH),
    );
    // Best score centrato SOTTO la corona (come il web, richiesta utente).
    final bestText = bestShown.toInt().toString();
    _drawGameText(
      canvas,
      bestText,
      Design.cupX,
      Design.bestScoreY,
      92,
      BlockPalette.gold,
      const Color(0xFF5A1A66),
      7,
    );

    _roundControl(canvas, 'hud_pause', Icons.pause_rounded, Design.pauseBtnX,
        Design.pauseBtnY, Design.pauseBtnSize);

    // Combo display (original "Combo" group).
    _drawComboDisplay(canvas);

    // Earned score popup (original "ShowEarnedScore").
    _drawEarnedDisplay(canvas);
  }

  void _drawComboDisplay(Canvas canvas) {
    final cd = comboDisplay;
    if (cd == null) return;
    final t = cd.t;
    // Appear 0..0.5s (scale to 1.4x image, opacity 0->100), hold, shrink
    // from 0.9s (0.5s), gone at 1.4s.
    double scale;
    double opacity;
    if (t < 0.3) {
      scale = 1.4 * _easeOutBack(t / 0.3);
      opacity = t / 0.3;
    } else if (t < 0.9) {
      scale = 1.4;
      opacity = 1;
    } else {
      final st = (t - 0.9) / 0.5;
      scale = 1.4 * (1 - st);
      opacity = 1 - st;
    }
    if (opacity <= 0 || scale <= 0) return;

    final glow = sprites.get('ComboSprite');
    final gw = glow.srcSize.x * scale;
    final gh = glow.srcSize.y * scale;
    canvas.saveLayer(
        null, Paint()..color = Color.fromRGBO(255, 255, 255, opacity));
    glow.render(canvas,
        position: Vector2(540 - gw / 2, 960 - gh / 2), size: Vector2(gw, gh));

    if (cd.combo > 1) {
      // Combo counter (txtComboNum, digits only), scale 0 -> 1.7, placed to
      // the right of the glow (original: ComboSprite.BBoxRight + TextWidth/2).
      final textScale = math.min(1.0, t / 0.3);
      final s = 1.7 * textScale;
      final textW = comboFont.measureWidth('${cd.combo}', scale: s * 0.7);
      comboFont.drawCentered(
        canvas,
        '${cd.combo}',
        540 + gw / 2 + textW / 2,
        960,
        scale: s * 0.7,
      );
    }
    canvas.restore();
  }

  void _drawEarnedDisplay(Canvas canvas) {
    final ed = earnedDisplay;
    if (ed == null) return;
    final t = ed.t;
    double scale;
    double opacity;
    if (t < 0.3) {
      scale = 1.2 * _easeOutBack(t / 0.3);
      opacity = t / 0.3;
    } else if (t < 1.0) {
      scale = 1.2;
      opacity = 1;
    } else {
      final ft = (t - 1.0) / 0.3;
      scale = 1.2 * (1 - ft);
      opacity = 1 - ft;
    }
    if (opacity <= 0) return;

    final glow = sprites.get('EarnedScoreGlow');
    final gw = glow.srcSize.x * scale;
    final gh = glow.srcSize.y * scale;
    canvas.saveLayer(
        null, Paint()..color = Color.fromRGBO(255, 255, 255, opacity));
    glow.render(
      canvas,
      position: Vector2(ed.x - gw / 2, ed.y - gh / 2),
      size: Vector2(gw, gh),
    );
    earnedFont.drawCentered(
      canvas,
      '+${ed.value}',
      ed.x,
      ed.y,
      scale: scale * 0.9,
    );

    // Cheerful praise (frame = lines, only for 2+ lines).
    if (ed.lines >= 2) {
      final frame = ed.lines.clamp(2, 6);
      final cheerful = sprites.get('Cheerful', frame: frame);
      final cw = cheerful.srcSize.x * scale;
      final ch = cheerful.srcSize.y * scale;
      cheerful.render(
        canvas,
        position: Vector2(ed.x - cw / 2, ed.y + 150 - ch / 2),
        size: Vector2(cw, ch),
      );
    }
    canvas.restore();
  }

  // =====================================================================
  //  Overlays
  // =====================================================================

  void _drawBlackBg(Canvas canvas) {
    if (blackBgOpacity <= 0.01) return;
    final paint = Paint()
      ..color = const Color(0xFF0E1626).withValues(alpha: blackBgOpacity);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, Design.width, Design.height),
      paint,
    );
  }

  void _drawNoSpaceBanner(Canvas canvas) {
    final ns = noSpaceBanner;
    if (ns == null) return;
    final t = ns.t.clamp(0.0, 1.0);
    final scale = _easeOutBack((t / 0.3).clamp(0.0, 1.0));
    final opacity = (t / 0.3).clamp(0.0, 1.0);
    final banner = sprites.get('NoSpaceLeft');
    final w = Design.noSpaceW * scale;
    final h = Design.noSpaceH * scale;
    canvas.saveLayer(
        null, Paint()..color = Color.fromRGBO(255, 255, 255, opacity));
    banner.render(
      canvas,
      position: Vector2(Design.noSpaceX - w / 2, Design.noSpaceY - h / 2),
      size: Vector2(w, h),
    );
    canvas.restore();
  }

  void _drawReviveOverlay(Canvas canvas) {
    if (state != GameState.revive) return;

    final circle = sprites.get('ReviveCircle');
    _drawSpriteCentered(
      canvas,
      circle,
      Design.reviveCircleX,
      Design.reviveCircleY,
      Design.reviveCircleSize,
      Design.reviveCircleSize,
    );

    // Radial progress arc (original RadialProgress behavior, 0..100).
    if (reviveRadial > 0) {
      final rect = Rect.fromCenter(
        center: _off(Design.reviveCircleX, Design.reviveCircleY),
        width: Design.reviveCircleSize - 24,
        height: Design.reviveCircleSize - 24,
      );
      final paint = Paint()
        ..color = const Color(0xFFFFC93C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
          rect, -math.pi / 2, math.pi * 2 * reviveRadial / 100, false, paint);
    }

    // Countdown number (big digits, oro su cerchio revive).
    _drawGameText(
      canvas,
      reviveText.toString(),
      Design.reviveCircleX,
      Design.reviveCircleY,
      200,
      BlockPalette.text,
      BlockPalette.gold,
      14,
    );

    final btn = sprites.get('BtnRevive');
    _drawSpriteCentered(
      canvas,
      btn,
      Design.btnReviveX,
      Design.btnReviveY,
      Design.btnReviveW,
      Design.btnReviveH,
    );
  }

  void _drawGameOverOverlay(Canvas canvas) {
    if (state != GameState.gameOver) return;

    // Light blue backdrop (original LightBlueBg 1277x2094 at (540,995)).
    final bg = sprites.get('LightBlueBg');
    final bw = 1277.0, bh = 2094.0;
    bg.render(
      canvas,
      position: Vector2(540 - bw / 2, 995 - bh / 2),
      size: Vector2(bw, bh),
    );

    // "Game Over" banner.
    final banner = sprites.get('GameOver');
    _drawSpriteCentered(
      canvas,
      banner,
      Design.goBannerX,
      Design.goBannerY,
      Design.goBannerW,
      Design.goBannerH,
    );

    // Labels: "Score" (frame 0) and "Best Score" (frame 1).
    final labelScore = sprites.get('TLabel', frame: 0);
    _drawSpriteCentered(
      canvas,
      labelScore,
      540,
      Design.goScoreLabelY,
      146,
      45,
    );
    final labelBest = sprites.get('TLabel', frame: 1);
    _drawSpriteCentered(
      canvas,
      labelBest,
      540,
      Design.goBestLabelY,
      262,
      45,
    );

    // Big score with count-up (1:1: bianco + bordo blu).
    _drawGameText(
      canvas,
      goScoreShown.toInt().toString(),
      540,
      Design.goScoreY,
      155,
      BlockPalette.text,
      BlockPalette.scoreStroke,
      14,
    );

    // Cup + best (left-anchored group at (482, 1223)).
    final cup = sprites.get('CupIcon');
    _drawSpriteCentered(
      canvas,
      cup,
      Design.goCupX,
      Design.goCupY,
      Design.goCupSize,
      Design.goCupH,
    );
    final bestText = storage.bestScore.toString();
    final bestW = _measureGameText(bestText, 54);
    _drawGameText(
      canvas,
      bestText,
      Design.goBestX + bestW / 2,
      Design.goBestY,
      54,
      BlockPalette.gold,
      const Color(0xFF7A4600),
      5,
    );

    // Play again button.
    final btn = sprites.get('BtnGOReset');
    _drawSpriteCentered(
      canvas,
      btn,
      Design.btnGOResetX,
      Design.btnGOResetY,
      Design.btnGOResetW,
      Design.btnGOResetH,
    );
  }

  void _drawPauseOverlay(Canvas canvas) {
    if (state != GameState.pause || rankingData != null) return;
    // Move the complete panel together, including its labels and controls.
    canvas.save();
    canvas.translate(0, pausePopupY - Design.pausePopupY);
    _panel(
        canvas,
        Rect.fromCenter(
          center: const Offset(540, Design.pausePopupY),
          width: Design.pausePopupW,
          height: Design.pausePopupH,
        ));
    _roundControl(canvas, 'pause_close', Icons.close_rounded, Design.btnCloseX,
        Design.btnCloseY, Design.btnCloseSize);
    _uiText(canvas, 'PAUSED', 540, 500, 76, title: true);
    _uiText(canvas, 'Ready when you are.', 540, 573, 34,
        color: const Color(0xFFB7CDF4));
    _actionButton(
        canvas,
        'pause_resume',
        'RESUME',
        Icons.play_arrow_rounded,
        Design.btnResumeX,
        Design.btnResumeY,
        Design.btnResumeW,
        Design.btnResumeH,
        primary: true);
    _settingRow(canvas, 'pause_sfx', 'Sound effects', Icons.volume_up_rounded,
        Design.btnSfxY, storage.sfxOn);
    _settingRow(canvas, 'pause_music', 'Music', Icons.music_note_rounded,
        Design.btnMusicY, storage.musicOn);
    _actionButton(
        canvas,
        'pause_ranking',
        'LEADERBOARD',
        Icons.emoji_events_rounded,
        Design.btnShowRankingX,
        Design.btnShowRankingY,
        Design.btnShowRankingW,
        Design.btnShowRankingH);
    _actionButton(canvas, 'pause_home', 'HOME', Icons.home_rounded,
        Design.btnHomeX, Design.btnHomeY, Design.btnHomeW, Design.btnHomeH,
        labelSize: 34);
    _actionButton(canvas, 'pause_reset', 'RESTART', Icons.refresh_rounded,
        Design.btnResetX, Design.btnResetY, Design.btnResetW, Design.btnResetH,
        labelSize: 34);
    canvas.restore();
  }

  void _drawRankingOverlay(Canvas canvas) {
    final data = rankingData;
    if (data == null) return;
    canvas.drawRect(const Rect.fromLTWH(0, 0, Design.width, Design.height),
        Paint()..color = const Color(0xB808102B));
    _panel(
        canvas,
        Rect.fromCenter(
          center: const Offset(540, Design.lbPopupY),
          width: Design.lbPopupW,
          height: Design.lbPopupH,
        ));
    _icon(canvas, Icons.emoji_events_rounded, 540, 260, 96,
        const Color(0xFFFFD05A));
    _uiText(canvas, 'LEADERBOARD', 540, Design.lbTitleY, 62, title: true);
    _uiText(canvas, 'A little better. Every round.', 540, 432, 32,
        color: const Color(0xFFB7CDF4));
    _roundControl(canvas, 'ranking_close', Icons.close_rounded, Design.lbCloseX,
        Design.lbCloseY, Design.lbCloseSize);
    _uiText(canvas, 'RANK', 190, 518, 25, color: const Color(0xFF92B3E8));
    _uiText(canvas, 'PLAYER', 288, 518, 25,
        color: const Color(0xFF92B3E8), align: TextAlign.left);
    _uiText(canvas, 'BEST SCORE', 902, 518, 25,
        color: const Color(0xFF92B3E8), align: TextAlign.right);

    final rows = data.topRows;
    for (var i = 0; i < rows.length; i++) {
      final entry = rows[i];
      final y = Design.lbRowStartY + i * Design.lbRowStep;
      final isYou = entry.name == 'You';
      final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(540, y),
            width: Design.lbRowW,
            height: Design.lbRowH,
          ),
          const Radius.circular(20));
      canvas.drawRRect(
          rect,
          Paint()
            ..color = isYou
                ? const Color(0xFF20578B)
                : (i.isEven
                    ? const Color(0xFF193771)
                    : const Color(0xFF142D62)));
      if (isYou) {
        canvas.drawRRect(
            rect,
            Paint()
              ..color = const Color(0xFF5DDDEB)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
      }
      const medals = [Color(0xFFFFD05A), Color(0xFFDBE9FF), Color(0xFFFFB58B)];
      final rankColor = i < 3 ? medals[i] : const Color(0xFF92B3E8);
      if (i < 3) {
        canvas.drawCircle(Offset(190, y), 27,
            Paint()..color = rankColor.withValues(alpha: 0.16));
      }
      _uiText(canvas, '${i + 1}', 190, y, 32, color: rankColor, bold: true);
      _uiText(canvas, isYou ? 'You' : entry.name, 288, y, 34,
          align: TextAlign.left, maxWidth: 330, bold: isYou);
      _uiText(canvas, _formatScore(entry.score), 902, y, 34,
          align: TextAlign.right,
          bold: true,
          color: isYou ? const Color(0xFF8CECF3) : const Color(0xFFF4F8FF));
    }

    // The player's result stays visible even outside the top ten.
    final bestRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(140, 1510, 800, 138), const Radius.circular(26));
    canvas.drawRRect(bestRect, Paint()..color = const Color(0xFF244D89));
    canvas.drawRRect(
        bestRect,
        Paint()
          ..color = const Color(0xFF5A91CD)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    _icon(canvas, Icons.person_rounded, 202, 1579, 62, const Color(0xFF8CECF3));
    _uiText(canvas, 'YOUR BEST', 260, 1556, 26,
        color: const Color(0xFFB7CDF4), align: TextAlign.left);
    _uiText(canvas, 'Rank #${data.yourRank}', 260, 1601, 32,
        align: TextAlign.left, bold: true);
    _uiText(canvas, _formatScore(storage.bestScore), 900, 1580, 46,
        align: TextAlign.right, color: const Color(0xFFFFD05A), bold: true);
    _uiText(canvas, 'Keep playing. Keep climbing.', 540, 1698, 28,
        color: const Color(0xFF92B3E8));
  }

  void _drawHome(Canvas canvas) {
    _actionButton(canvas, 'home_play', 'PLAY', Icons.play_arrow_rounded,
        Design.btnPlayX, Design.btnPlayY, Design.btnPlayW, Design.btnPlayH,
        primary: true, labelSize: 88);
    _roundControl(canvas, 'home_ranking', Icons.emoji_events_rounded, 539,
        Design.homeBtnY, Design.homeBtnSize);
    _roundControl(
        canvas,
        'home_music',
        storage.musicOn ? Icons.music_note_rounded : Icons.music_off_rounded,
        Design.homeMusicX,
        Design.homeBtnY,
        Design.homeBtnSize,
        active: storage.musicOn);
    _roundControl(
        canvas,
        'home_sfx',
        storage.sfxOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
        Design.homeSfxX,
        Design.homeBtnY,
        Design.homeBtnSize,
        active: storage.sfxOn);
  }

  // =====================================================================
  //  Helpers
  // =====================================================================

  String _formatScore(int value) => value
      .toString()
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  void _panel(Canvas canvas, Rect rect) {
    final panel = RRect.fromRectAndRadius(rect, const Radius.circular(54));
    canvas.drawRRect(panel.shift(const Offset(0, 16)),
        Paint()..color = const Color(0x66040B24));
    canvas.drawRRect(
        panel,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF173C7D), Color(0xFF102653), Color(0xFF0B183C)],
          ).createShader(rect));
    canvas.drawRRect(
        panel,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFF527BB8));
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(9), const Radius.circular(46)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0x264DAEFF));
  }

  void _pressTransform(Canvas canvas, String id, double x, double y) {
    canvas.save();
    if (pressedButton != id) return;
    canvas.translate(x, y);
    canvas.scale(0.96);
    canvas.translate(-x, -y);
  }

  void _roundControl(
      Canvas canvas, String id, IconData icon, double x, double y, double size,
      {bool active = true}) {
    _pressTransform(canvas, id, x, y);
    final rect =
        Rect.fromCenter(center: Offset(x, y), width: size, height: size);
    final shape = RRect.fromRectAndRadius(rect, Radius.circular(size * 0.32));
    canvas.drawRRect(shape.shift(const Offset(0, 6)),
        Paint()..color = const Color(0x99070F33));
    canvas.drawRRect(
        shape,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: active
                ? const [Color(0xFF4967C4), Color(0xFF253A82)]
                : const [Color(0xFF2D416B), Color(0xFF1C2A50)],
          ).createShader(rect));
    canvas.drawRRect(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = active ? const Color(0xFF89AEFF) : const Color(0xFF576990));
    _icon(canvas, icon, x, y, size * 0.53,
        active ? const Color(0xFFFFFFFF) : const Color(0xFF94A6C6));
    canvas.restore();
  }

  void _actionButton(Canvas canvas, String id, String label, IconData icon,
      double x, double y, double w, double h,
      {bool primary = false, double labelSize = 46}) {
    _pressTransform(canvas, id, x, y);
    final rect = Rect.fromCenter(center: Offset(x, y), width: w, height: h);
    final radius = Radius.circular(primary ? 38 : 26);
    final shape = RRect.fromRectAndRadius(rect, radius);
    canvas.drawRRect(
        shape.shift(const Offset(0, 8)),
        Paint()
          ..color =
              primary ? const Color(0xFFAF590B) : const Color(0xFF091735));
    canvas.drawRRect(
        shape,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: primary
                ? const [
                    Color(0xFFFFD34D),
                    Color(0xFFFFB21C),
                    Color(0xFFF18A0D)
                  ]
                : const [Color(0xFF2D559A), Color(0xFF21417D)],
          ).createShader(rect));
    canvas.drawRRect(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = primary ? 4 : 2
          ..color =
              primary ? const Color(0xFFFFE999) : const Color(0xFF5B82BA));
    final highlight =
        Rect.fromLTWH(rect.left + 14, rect.top + 10, w - 28, h * 0.34);
    canvas.drawRRect(
        RRect.fromRectAndRadius(highlight, radius),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFFFFFF).withValues(alpha: primary ? 0.28 : 0.09),
              const Color(0x00FFFFFF)
            ],
          ).createShader(highlight));
    final text =
        _gameTextPainter(label, labelSize, const Color(0xFFFFFFFF), null);
    final iconSize = labelSize * 1.25;
    final gap = labelSize * 0.32;
    final contentW = iconSize + gap + text.width;
    final startX = x - contentW / 2;
    _icon(canvas, icon, startX + iconSize / 2, y, iconSize,
        const Color(0xFFFFFFFF));
    _drawGameText(
        canvas,
        label,
        startX + iconSize + gap + text.width / 2,
        y + labelSize * 0.08,
        labelSize,
        const Color(0xFFFFFFFF),
        primary ? const Color(0xFFD98212) : const Color(0xFF163565),
        2);
    canvas.restore();
  }

  void _settingRow(Canvas canvas, String id, String label, IconData icon,
      double y, bool enabled) {
    _pressTransform(canvas, id, 540, y);
    final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(540, y), width: 712, height: 118),
        const Radius.circular(24));
    canvas.drawRRect(rect, Paint()..color = const Color(0xFF162F60));
    _icon(canvas, icon, 245, y, 54, const Color(0xFFA8C9FF));
    _uiText(canvas, label, 296, y, 38, align: TextAlign.left);
    final track = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(830, y), width: 104, height: 60),
        const Radius.circular(30));
    canvas.drawRRect(
        track,
        Paint()
          ..color =
              enabled ? const Color(0xFF40C9CF) : const Color(0xFF40557C));
    canvas.drawCircle(Offset(enabled ? 851 : 809, y), 23,
        Paint()..color = const Color(0xFFFFFFFF));
    _icon(
        canvas,
        enabled ? Icons.check_rounded : Icons.close_rounded,
        enabled ? 851 : 809,
        y,
        30,
        enabled ? const Color(0xFF158C96) : const Color(0xFF576B8F));
    canvas.restore();
  }

  void _icon(Canvas canvas, IconData icon, double x, double y, double size,
      Color color) {
    final painter = TextPainter(
      text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: size,
            color: color,
            height: 1,
          )),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
        canvas, Offset(x - painter.width / 2, y - painter.height / 2));
  }

  void _uiText(Canvas canvas, String text, double x, double y, double size,
      {Color color = const Color(0xFFF4F8FF),
      bool title = false,
      bool bold = false,
      TextAlign align = TextAlign.center,
      double maxWidth = double.infinity}) {
    final painter = TextPainter(
        text: TextSpan(
            text: text,
            style: TextStyle(
              fontFamily: title ? 'LuckiestGuy' : 'Arial',
              fontSize: size,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: color,
              height: 1.15,
            )),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…')
      ..layout(maxWidth: maxWidth);
    final dx = align == TextAlign.left
        ? x
        : align == TextAlign.right
            ? x - painter.width
            : x - painter.width / 2;
    painter.paint(canvas, Offset(dx, y - painter.height / 2));
  }

  void _drawSpriteCentered(
      Canvas canvas, Sprite sprite, double cx, double cy, double w, double h) {
    sprite.render(canvas,
        position: Vector2(cx - w / 2, cy - h / 2), size: Vector2(w, h));
  }

  /// Testo di gioco 1:1 (font Luckiest Guy): prima lo stroke, poi il fill,
  /// centrato su (cx, cy) — come lo score bianco/bordo blu del riferimento.
  void _drawGameText(Canvas canvas, String text, double cx, double cy,
      double size, Color fill, Color stroke, double strokeW) {
    final fillTp = _gameTextPainter(text, size, fill, null);
    final dx = cx - fillTp.width / 2;
    final dy = cy - fillTp.height / 2;
    if (strokeW > 0) {
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeJoin = StrokeJoin.round
        ..color = stroke;
      final strokeTp = _gameTextPainter(text, size, null, strokePaint);
      strokeTp.paint(canvas, Offset(dx, dy));
    }
    fillTp.paint(canvas, Offset(dx, dy));
  }

  double _measureGameText(String text, double size) {
    final tp = _gameTextPainter(text, size, const Color(0xFFFFFFFF), null);
    return tp.width;
  }

  TextPainter _gameTextPainter(
      String text, double size, Color? color, Paint? foreground) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'LuckiestGuy',
          fontSize: size,
          color: foreground == null ? color : null,
          foreground: foreground,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  Offset _off(double x, double y) => Offset(x, y);

  double _easeOutBack(double t) {
    final c1 = 1.70158;
    final c3 = c1 + 1;
    final p = t - 1;
    return 1 + c3 * p * p * p + c1 * p * p;
  }
}
