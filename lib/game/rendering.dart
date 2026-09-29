import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'block_blast_game.dart';
import 'layout_constants.dart';
import 'shapes.dart';

/// Block Rush 1:1 rendering — la stessa grafica del web, estratta dai due
/// screenshot reference dell'utente:
/// bg bokeh navy · board con bordo neon e celle incassate · blocchi candy
/// glossy · bottoni circolari viola · PLAY arancio · pannelli candy viola.
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
  //  Background (bg bokeh navy baked dai reference)
  // =====================================================================

  void _drawBackground(Canvas canvas) {
    final bg = state == GameState.home ? rush.get('bgHome') : rush.get('bgGame');
    bg.render(canvas, position: Vector2.zero(), size: Vector2(Design.width, Design.height));
  }

  // =====================================================================
  //  Board (frame 1:1 con interno baked + tile candy per colore)
  // =====================================================================

  void _drawBoard(Canvas canvas) {
    // Frame completo (bordo neon + celle incassate) a (26,343) 1019x1031.
    rush.get('frame').render(
          canvas,
          position: Vector2(Rush.frameL, Rush.frameT),
          size: Vector2(Rush.frameW, Rush.frameH),
        );

    // Drag preview: tile del pezzo al 40% sulle celle target.
    if (dragSlot >= 0 && dragValid && dragTargets.isNotEmpty) {
      final slot = tray[dragSlot]!;
      final preview = rush.block(slot.colorIdx);
      canvas.saveLayer(null, Paint()..color = const Color(0x66FFFFFF));
      for (final cell in dragTargets) {
        preview.render(
          canvas,
          position: Vector2(Rush.slotCx(cell.x) - Rush.pitchX / 2,
              Rush.slotCy(cell.y) - Rush.pitchY / 2),
          size: Vector2(Rush.pitchX, Rush.pitchY),
        );
      }
      canvas.restore();
    }

    // Blocchi piazzati (con ricolorazione delle righe in completamento).
    final draggingSlot = dragSlot >= 0 ? tray[dragSlot] : null;
    for (var y = 0; y < Rush.gridSize; y++) {
      for (var x = 0; x < Rush.gridSize; x++) {
        var colorIdx = grid[y][x];
        if (colorIdx == null) continue;
        if (draggingSlot != null && dragValid) {
          final inMarkedRow = dragMarkedLines.contains('R$y');
          final inMarkedCol = dragMarkedLines.contains('C$x');
          if (inMarkedRow || inMarkedCol) {
            colorIdx = draggingSlot.colorIdx;
          }
        }
        final block = rush.block(colorIdx);
        final cx = Rush.slotCx(x);
        final cy = Rush.slotCy(y);
        // Settle: mini pop quando il pezzo atterra.
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
          position: Vector2(cx - Rush.pitchX / 2, cy - Rush.pitchY / 2),
          size: Vector2(Rush.pitchX, Rush.pitchY),
        );
        if (settle != null && settle < 1) {
          canvas.restore();
        }
      }
    }

    for (final fx in lineFx) {
      _drawLineEffect(canvas, fx);
    }

    // Quadratini particella (1:1 CreateSquareEffect).
    final squarePaint = Paint();
    for (final s in squares) {
      final moveFrac = (s.t / s.dur).clamp(0.0, 1.0);
      final alpha = (1 - s.t).clamp(0.0, 1.0);
      squarePaint.color = Color.fromRGBO(s.color.r, s.color.g, s.color.b, alpha);
      canvas.drawRect(
        Rect.fromCenter(
          center: _off(s.x + s.vx * moveFrac, s.y + s.vy * moveFrac),
          width: s.size,
          height: s.size,
        ),
        squarePaint,
      );
    }

    for (final p in particles) {
      final alpha = (1 - p.t / p.life).clamp(0.0, 1.0);
      squarePaint.color = Color.fromRGBO(255, 255, 255, alpha * 0.8);
      canvas.drawCircle(_off(p.x, p.y), 6 * (1 - p.t / p.life) + 2, squarePaint);
    }

    for (final g in glowBursts) {
      final t = (g.t / 0.4).clamp(0.0, 1.0);
      final radius = 300 * t;
      final alpha = 30 * (1 - t) / 100;
      final paint = Paint()
        ..color = const Color(0xFFFFFFFF).withOpacity(alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
      canvas.drawCircle(_off(g.x, g.y), radius, paint);
    }
  }

  void _drawLineEffect(Canvas canvas, LineFx fx) {
    // Barra luminosa sulla riga/colonna completata (stesso feel dell'originale).
    final t = fx.t.clamp(0.0, 1.2);
    if (t >= 1.2) return;
    final opacity = t < 0.3 ? t / 0.3 : (1.2 - t) / 0.9;
    final paint = Paint()
      ..color = Color.fromRGBO(fx.color.r, fx.color.g, fx.color.b, 0.35 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    if (fx.horizontal) {
      canvas.drawRect(
        Rect.fromLTWH(Rush.frameL + 8, fx.pos - 55, Rush.frameW - 16, 110),
        paint,
      );
    } else {
      canvas.drawRect(
        Rect.fromLTWH(fx.pos - 55, Rush.frameT + 8, 110, Rush.frameH - 16),
        paint,
      );
    }
  }

  // =====================================================================
  //  Tray (vassoi 1:1: slot 190/540/890 @1600, celle 89, clamp larghe)
  // =====================================================================

  void _drawTray(Canvas canvas) {
    for (var i = 0; i < 3; i++) {
      final ph = slotCenter(i);
      final slot = tray[i];
      if (slot == null || slot.placed) continue;
      if (i == dragSlot) continue;

      var center = ph;
      var scale = 1.0;
      if (dragReturnT >= 0 && i == returningSlot) {
        final t = dragReturnT.clamp(0.0, 1.0);
        final eased = 1 - (1 - t) * (1 - t);
        center = Vector2(
          returnFrom.x + (ph.x - returnFrom.x) * eased,
          returnFrom.y + (ph.y - returnFrom.y) * eased,
        );
        scale = 1.0;
      } else if (slot.popT < 1) {
        scale = slot.popT;
      }
      _drawPiece(canvas, slot, center, scale);
    }

    // Pezzo trascinato: STESSA dimensione del vassoio (1:1 reference —
    // niente ingrandimento alla presa).
    if (dragSlot >= 0) {
      final slot = tray[dragSlot];
      if (slot != null) {
        _drawPiece(canvas, slot, dragPos, dragScale);
      }
    }
  }

  void _drawPiece(Canvas canvas, TraySlot slot, Vector2 center, double scale) {
    final shape = kShapes[slot.shapeIdx];
    final rows = shape.length;
    final cols = shape[0].length;
    var cell = Rush.trayCell * scale;
    // clamp: le forme larghe non toccano mai i vicini
    final clampScale = math.min(1.0,
        math.min(Rush.trayClamp / (cols * Rush.trayCell),
            Rush.trayClamp / (rows * Rush.trayCell)));
    cell *= clampScale;
    final block = rush.block(slot.colorIdx);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (shape[r][c] == 0) continue;
        final cx = center.x + (c - (cols - 1) / 2) * cell;
        final cy = center.y + (r - (rows - 1) / 2) * cell;
        block.render(
          canvas,
          position: Vector2(cx - cell / 2, cy - cell / 2),
          size: Vector2(cell, cell),
        );
      }
    }
  }

  // =====================================================================
  //  Tutorial hint (Hand + ghost)
  // =====================================================================

  void _drawTutorialHint(Canvas canvas) {
    if (!tutorial.active || state != GameState.hud) return;
    if (dragSlot >= 0) return;
    final slot = tray[1];
    if (slot == null || slot.placed) return;

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
      return;
    }

    math.Point<int>? target;
    if (tutorial.tutNum == 1) target = const math.Point(4, 4);
    if (tutorial.tutNum == 2) target = const math.Point(4, 4);
    if (tutorial.tutNum == 3) target = const math.Point(3, 3);
    if (target == null) return;

    final ph = slotCenter(1);
    final tx = Rush.slotCx(target.x);
    final ty = Rush.slotCy(target.y);
    final eased = 1 - (1 - moveT) * (1 - moveT);
    final gx = ph.x + (tx - ph.x) * eased;
    final gy = ph.y + (ty - ph.y) * eased;

    canvas.saveLayer(null, Paint()..color = Color.fromRGBO(255, 255, 255, fade));
    canvas.saveLayer(null, Paint()..color = const Color(0x80FFFFFF));
    _drawPiece(canvas, slot, Vector2(gx, gy), 1.0);
    canvas.restore();
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
  //  HUD (score luckiest + outline blu, corona + best sotto, pausa patch)
  // =====================================================================

  void _drawHud(Canvas canvas) {
    if (state == GameState.home) return;

    if (heartVisible) {
      final heart = sprites.get('Heart');
      final pulse = 1 + 0.08 * math.sin(heartPulse * 6.4);
      final s = 240.0 * pulse;
      canvas.saveLayer(null, Paint()..color = const Color(0x80FFD700));
      heart.render(
        canvas,
        position: Vector2(540 - s / 2, 243 - s / 2),
        size: Vector2(s, s),
      );
      canvas.restore();
    }

    // Score: bianco con outline blu #1D4FE8 (come il reference).
    _drawGameText(
      canvas,
      scoreShown.toInt().toString(),
      540,
      Rush.scoreY,
      181,
      const Color(0xFFFFFFFF),
      strokeColor: Rush.strokeBlue,
      strokeWidth: 15,
      glow: Rush.glowBlue,
    );

    // Corona + best (best SOTTO la corona).
    rush.get('crown').render(
          canvas,
          position: Vector2(Rush.crownX - Rush.crownW / 2, Rush.crownY - Rush.crownH / 2),
          size: Vector2(Rush.crownW, Rush.crownH),
        );
    _drawGameText(
      canvas,
      bestShown.toInt().toString(),
      Rush.crownX,
      Rush.bestY,
      110,
      Rush.bestYellow,
      strokeColor: Rush.bestStroke,
      strokeWidth: 8,
    );

    // Pausa: patch squircle 1:1 (154x157 naturale, centro (951,130)).
    final pause = rush.get('btnPause');
    pause.render(
      canvas,
      position: Vector2(Rush.pauseX - 77, Rush.pauseY - 78.5),
      size: Vector2(154, 157),
    );

    _drawComboDisplay(canvas);
    _drawEarnedDisplay(canvas);
  }

  void _drawComboDisplay(Canvas canvas) {
    final cd = comboDisplay;
    if (cd == null) return;
    final t = cd.t;
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

    canvas.saveLayer(null, Paint()..color = Color.fromRGBO(255, 255, 255, opacity));
    _drawGameText(
      canvas,
      'COMBO',
      540,
      890,
      76,
      const Color(0xFFFFFFFF),
      family: 'Riffic',
      strokeColor: const Color(0xFF3A2480),
      strokeWidth: 8,
    );
    if (cd.combo > 0) {
      _drawGameText(
        canvas,
        'x${cd.combo}',
        540,
        1030,
        150,
        const Color(0xFFFFD700),
        strokeColor: const Color(0xFF5A1A66),
        strokeWidth: 10,
        glow: const Color(0xFF3FE8FE),
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

    canvas.saveLayer(null, Paint()..color = Color.fromRGBO(255, 255, 255, opacity));
    canvas.save();
    canvas.scale(scale, scale);
    _drawGameText(
      canvas,
      '+${ed.value}',
      ed.x / scale,
      ed.y / scale,
      100,
      const Color(0xFFFFF3C4),
      strokeColor: const Color(0xFFD18F00),
      strokeWidth: 8,
      glow: const Color(0xFFFFD700),
    );
    canvas.restore();
    canvas.restore();
  }

  // =====================================================================
  //  Overlays (BlackBg / NoSpace / Revive / GameOver / Pause / Ranking)
  // =====================================================================

  void _drawBlackBg(Canvas canvas) {
    if (blackBgOpacity <= 0) return;
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, Design.width, Design.height),
      Paint()..color = const Color(0xB3000510).withOpacity(blackBgOpacity),
    );
  }

  void _drawNoSpaceBanner(Canvas canvas) {
    final ns = noSpaceBanner;
    if (ns == null) return;
    final t = ns.t.clamp(0.0, 1.0);
    final opacity = t < 0.1 ? t / 0.1 : (1 - t) / 0.9;
    if (opacity <= 0) return;
    canvas.saveLayer(null, Paint()..color = Color.fromRGBO(255, 255, 255, opacity));
    _drawGameText(
      canvas,
      'NO SPACE LEFT',
      540,
      1630,
      96,
      const Color(0xFFFF5A5A),
      strokeColor: const Color(0xFF5A1020),
      strokeWidth: 10,
    );
    canvas.restore();
  }

  void _drawReviveOverlay(Canvas canvas) {
    if (state != GameState.revive) return;
    _drawDim(canvas);
    _drawCandyPanel(canvas, 540, 760, 860, 760);
    _drawGameText(
      canvas,
      'CONTINUA?',
      540, 640, 80, const Color(0xFFFFFFFF),
      strokeColor: const Color(0xFF2A1A66), strokeWidth: 6,
      glow: const Color(0xFF9F6BFF), family: 'Riffic',
    );
    // countdown radiale
    final frac = reviveText / Design.reviveTime;
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(540, 940), width: 260, height: 260),
      -math.pi / 2, math.pi * 2 * frac,
      true, Paint()..color = const Color(0xFFF2D34D),
    );
    canvas.drawCircle(
      const Offset(540, 940), 98,
      Paint()..color = const Color(0xFF2A1D66),
    );
    _drawGameText(
      canvas, '$reviveText', 540, 940, 110,
      const Color(0xFFFFFFFF), strokeColor: const Color(0xFF150C36), strokeWidth: 6,
    );
    _drawPill(canvas, 'GUARDA ANNUNCIO E CONTINUA', 540, 1370, 740, 150);
  }

  void _drawGameOverOverlay(Canvas canvas) {
    if (state != GameState.gameOver) return;
    _drawDim(canvas);
    _drawCandyPanel(canvas, 540, 900, 880, 1250);
    _drawGameText(
      canvas, 'GAME OVER', 540, 560, 96, const Color(0xFFFFFFFF),
      strokeColor: const Color(0xFF2A1A66), strokeWidth: 8,
      glow: const Color(0xFF9F6BFF), family: 'Riffic',
    );
    _drawGameText(canvas, 'SCORE', 540, 750, 58, const Color(0xFFD9C8FF), family: 'Riffic');
    _drawGameText(
      canvas, '${scoreShown.toInt()}', 540, 890, 150, const Color(0xFFFFFFFF),
      strokeColor: Rush.strokeBlue, strokeWidth: 14, glow: Rush.glowBlue,
    );
    _drawGameText(canvas, 'BEST SCORE', 540, 1080, 52, const Color(0xFFD9C8FF), family: 'Riffic');
    rush.get('crown').render(
          canvas,
          position: Vector2(407.5 - 90, 1170),
          size: Vector2(180, 161),
        );
    _drawGameText(
      canvas, '${bestShown.toInt()}', 500, 1250, 74, Rush.bestYellow,
      strokeColor: Rush.bestStroke, strokeWidth: 7,
    );
    _drawPill(canvas, 'RIGIOCA', 540, 1470, 560, 140);
  }

  void _drawPauseOverlay(Canvas canvas) {
    if (state != GameState.pause && state != GameState.ranking) return;
    if (state == GameState.ranking && rankingReturn == GameState.home) return;

    _drawDim(canvas);
    _drawCandyPanel(canvas, 540, 960.5, 886, 1113);

    if (pausePopupY > 300) {
      // close
      _drawCircleBtn(canvas, 899, 482, 80);
      _drawGameText(canvas, 'X', 899, 482, 52, const Color(0xFFFFFFFF), family: 'Riffic');
      // toggles (patch 1:1)
      final sfx = rush.get(storage.sfxOn ? 'btnSfx' : 'btnSfxOff');
      sfx.render(
        canvas,
        position: Vector2(420 - 121, 800 - 122),
        size: Vector2(242, 244),
      );
      final music = rush.get(storage.musicOn ? 'btnMusic' : 'btnMusicOff');
      music.render(
        canvas,
        position: Vector2(660 - 121, 800 - 122),
        size: Vector2(242, 244),
      );
      // pills
      _drawPill(canvas, 'RIGIOCA', 540, 1022, 560, 132);
      _drawPill(canvas, 'CLASSIFICA', 540, 1180, 560, 132);
      _drawPill(canvas, 'HOME', 540, 1338, 560, 132);
    }
  }

  void _drawRankingOverlay(Canvas canvas) {
    if (rankingData == null) return;
    if (state != GameState.ranking && rankingReturn != GameState.home &&
        state != GameState.home && state != GameState.pause) {
      return;
    }
    _drawDim(canvas);
    final data = rankingData!;
    _drawCandyPanel(canvas, 540, 940, 920, 1400);

    // trofeo + titolo
    final cup = sprites.get('CupIcon');
    canvas.saveLayer(null, Paint()..color = const Color(0xFFF3BF08));
    cup.render(
      canvas,
      position: Vector2(460 - 58, 350 - 58),
      size: Vector2(116, 116),
    );
    canvas.restore();
    _drawGameText(
      canvas, 'CLASSIFICA', 540, 492, 84, const Color(0xFFFFFFFF),
      strokeColor: const Color(0xFF2A1A66), strokeWidth: 7,
      glow: const Color(0xFF9F6BFF), family: 'Riffic',
    );
    _drawCircleBtn(canvas, 850, 315, 80);
    _drawGameText(canvas, 'X', 850, 315, 52, const Color(0xFFFFFFFF), family: 'Riffic');

    // righe con medaglie (1:1 col web: prima riga centrata a y=867, passo 80)
    final rows = data.topRows;
    for (var i = 0; i < rows.length; i++) {
      final entry = rows[i];
      final y = 867.0 + i * 80;
      final isYou = entry.name == 'You';
      Color? medal;
      if (i == 0) {
        medal = Rush.medalGold;
      } else if (i == 1) {
        medal = Rush.medalSilver;
      } else if (i == 2) {
        medal = Rush.medalBronze;
      }
      _drawRankRow(canvas, 540, y, 792, 70, isYou, medal);
      final dark = const Color(0xFFFFFFFF);
      final rank = isYou && !data.youInTopRows ? data.displayRankFor(i) : i + 1;
      _drawGameText(canvas, '$rank', 540 - 792 / 2 + 64, y, 42,
          medal ?? const Color(0x8CFFFFFF));
      _drawGameText(canvas, entry.name, 540 - 792 / 2 + 190, y, 42, dark);
      _drawGameText(canvas, '${entry.score}', 540 + 792 / 2 - 42, y, 42,
          medal ?? Rush.medalGold);
    }
  }

  // =====================================================================
  //  Home (bg-home col logo baked + PLAY + 3 dischi)
  // =====================================================================

  void _drawHome(Canvas canvas) {
    // PLAY patch 1:1 (682x282 a (541,1315)).
    rush.get('play').render(
          canvas,
          position: Vector2(Rush.playX - Rush.playW / 2, Rush.playY - Rush.playH / 2),
          size: Vector2(Rush.playW, Rush.playH),
        );

    // Dischi: sfx (205), ranking (550), music (896) — patch 1:1 289px.
    _drawRushIcon(canvas, 0, storage.sfxOn ? 'btnSfx' : 'btnSfxOff');
    _drawRushIcon(canvas, 1, 'btnRanking');
    _drawRushIcon(canvas, 2, storage.musicOn ? 'btnMusic' : 'btnMusicOff');
  }

  void _drawRushIcon(Canvas canvas, int idx, String asset) {
    final s = rush.get(asset);
    // canvas naturale dei patch (disco ~226/0.78)
    const sizes = [289.0, 294.0, 291.0];
    final size = sizes[idx];
    s.render(
      canvas,
      position: Vector2(Rush.iconX[idx] - size / 2, Rush.iconY - size / 2),
      size: Vector2(size, size),
    );
  }

  // =====================================================================
  //  Helpers (pannelli candy, pillole, testo con stroke)
  // =====================================================================

  void _drawDim(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, Design.width, Design.height),
      Paint()..color = const Color(0xA8000510),
    );
  }

  /// Pannello candy viola: gradiente + bordo chiaro + ombra (PopupSurface web).
  void _drawCandyPanel(Canvas canvas, double cx, double cy, double w, double h) {
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
    // ombra
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.shift(const Offset(0, 18)), const Radius.circular(56)),
      Paint()..color = const Color(0x66000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
    );
    // gradiente
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(56)),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx, cy - h / 2),
          Offset(cx, cy + h / 2),
          [Rush.panelTop, Rush.panelBottom],
        ),
    );
    // bordo
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(54)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0x38FFFFFF),
    );
    // gloss in alto
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + 10, rect.top + 8, w - 20, h * 0.32),
        const Radius.circular(48),
      ),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(rect.left, rect.top),
          Offset(rect.left, rect.top + h * 0.34),
          [const Color(0x30FFFFFF), const Color(0x00FFFFFF)],
        ),
    );
  }

  /// Pill viola candy con testo Riffic bianco.
  void _drawPill(Canvas canvas, String label, double cx, double cy, double w, double h) {
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(h / 2));
    canvas.drawRRect(
      rrect.shift(const Offset(0, 8)),
      Paint()..color = const Color(0x55000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx, cy - h / 2), Offset(cx, cy + h / 2),
          [Rush.pillTop, Rush.pillBottom],
        ),
    );
    canvas.drawRRect(
      rrect.deflate(2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0x80FFFFFF),
    );
    _drawGameText(
      canvas, label, cx, cy, h * 0.47, const Color(0xFFFFFFFF),
      strokeColor: const Color(0xFF280F6E), strokeWidth: 5, family: 'Riffic',
    );
  }

  /// Bottone tondo viola (close).
  void _drawCircleBtn(Canvas canvas, double cx, double cy, double size) {
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: size, height: size);
    canvas.drawCircle(
      Offset(cx, cy + 4), size / 2,
      Paint()..color = const Color(0x55000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      Offset(cx, cy), size / 2,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx, cy - size / 2), Offset(cx, cy + size / 2),
          [Rush.pillTop, Rush.pillBottom],
        ),
    );
    canvas.drawCircle(
      Offset(cx, cy), size / 2 - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0x80FFFFFF),
    );
  }

  /// Riga classifica (glassy, medaglie, "Tu" evidenziato).
  void _drawRankRow(Canvas canvas, double cx, double y, double w, double h, bool you, Color? medal) {
    final rect = Rect.fromCenter(center: Offset(cx, y), width: w, height: h);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(22));
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(cx, y - h / 2), Offset(cx, y + h / 2),
          you
              ? [const Color(0x47FFD54A), const Color(0x29FFA03C)]
              : [const Color(0x1AFFFFFF), const Color(0x0DFFFFFF)],
        ),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = you
            ? const Color(0xBFFFC94D)
            : (medal != null ? medal.withOpacity(0.33) : const Color(0x1FFFFFFF)),
    );
  }

  /// Testo di gioco: font chunky + stroke + glow (passate: glow, stroke, fill).
  void _drawGameText(
    Canvas canvas,
    String text,
    double cx,
    double cy,
    double size,
    Color color, {
    Color? strokeColor,
    double strokeWidth = 0,
    Color? glow,
    String family = 'LuckiestGuy',
  }) {
    if (glow != null) {
      final glowTp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: family,
            fontSize: size,
            foreground: Paint()
              ..color = glow
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.16),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      glowTp.paint(canvas, Offset(cx - glowTp.width / 2, cy - glowTp.height / 2));
    }
    if (strokeColor != null && strokeWidth > 0) {
      final tp = _tp(text, size, family, null, stroke: strokeColor, strokeW: strokeWidth);
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }
    final tp = _tp(text, size, family, color);
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  TextPainter _tp(
    String text,
    double size,
    String family,
    Color? color, {
    Color? stroke,
    double strokeW = 0,
  }) {
    final style = stroke != null
        ? TextStyle(
            fontFamily: family,
            fontSize: size,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeW
              ..strokeJoin = StrokeJoin.round
              ..color = stroke,
          )
        : TextStyle(
            fontFamily: family,
            fontSize: size,
            color: color ?? const Color(0xFFFFFFFF),
          );
    return TextPainter(
      text: TextSpan(text: text, style: style),
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
