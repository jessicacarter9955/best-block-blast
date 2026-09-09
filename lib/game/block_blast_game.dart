import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';

import 'palette.dart';
import 'shapes.dart';

/// The main Block Blast game.
///
/// Layout (portrait):
///   - Header (rendered by Flutter overlay in main.dart): score box at top
///   - Grid: 8x8 cells, centered, occupies most of the width
///   - Tray: 3 piece slots below the grid
///
/// The game is fully rendered with Flame primitives (rounded
/// rectangles) — no sprite assets required. Audio is loaded from
/// assets/audio/ (mp3, converted from the original webm).
///
/// Text UI (header, score, game-over modal) is rendered via Flutter
/// overlay in main.dart, NOT on the canvas — keeps the game code clean.
class BlockBlastGame extends FlameGame with PanDetector {
  static const int kGridSize = 8;
  static const int kTraySize = 3;

  // Layout (set in onGameResize).
  late double _gridPx;
  late double _gridOriginX;
  late double _gridOriginY;
  late double _traySlotPx;
  late double _trayY;

  // State
  late final List<List<BlockColor?>> _grid;
  final List<Piece?> _tray = List.filled(kTraySize, null);
  int _score = 0;
  bool _gameOver = false;
  bool _audioReady = false;

  // Currently dragged piece
  DragState? _drag;
  Vector2? _lastDragPos;

  // Visual: cells currently flashing (clearing)
  final Set<Point<int>> _flashing = {};
  double _flashElapsed = 0;

  // Callbacks to Flutter overlay
  void Function(int score)? onScoreChanged;
  void Function(bool gameOver, int finalScore)? onGameOverChanged;

  @override
  Future<void> onLoad() async {
    _grid = List.generate(kGridSize, (_) => List.filled(kGridSize, null));

    // Pre-load audio (best-effort; if it fails the game still runs).
    try {
      await FlameAudio.audioCache.loadAll([
        'put.mp3', 'score.mp3', 'lose.mp3', 'whoosh.mp3',
        'beep.mp3', 'revive.mp3', 'return.mp3', 'no_space.mp3',
      ]);
      _audioReady = true;
    } catch (_) {}
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final double w = size.x;
    final double h = size.y;

    // 70px reserved at the top for the Flutter-rendered header (CHOCO BLOCK + score)
    // 40px reserved at the bottom for a footer hint
    final double headerReserve = 70;
    final double footerReserve = 40;
    final double gap = 16;
    final double padding = 16;

    final double maxGridW = w - padding * 2;
    final double availableForGrid = h - headerReserve - footerReserve - gap * 2 - (w - padding * 2) * 0.5;
    _gridPx = (maxGridW < availableForGrid ? maxGridW : availableForGrid) / kGridSize;
    final double gridW = _gridPx * kGridSize;
    _gridOriginX = (w - gridW) / 2;
    _gridOriginY = headerReserve + gap;

    _trayY = _gridOriginY + gridW + gap;
    final double trayW = w - padding * 2;
    _traySlotPx = (trayW - gap * 2) / 3;
  }

  // ---- Public getters ----
  double get gridPx => _gridPx;
  double get gridOriginX => _gridOriginX;
  double get gridOriginY => _gridOriginY;
  double get gridW => _gridPx * kGridSize;
  double get traySlotPx => _traySlotPx;
  double get trayY => _trayY;
  double get trayOriginX => 16;

  // ---- Tray logic ----
  void refillTray() {
    final rng = Random();
    for (int i = 0; i < kTraySize; i++) {
      _tray[i] = Piece(
        shape: kShapes[rng.nextInt(kShapes.length)],
        color: BlockPalette.blocks[rng.nextInt(BlockPalette.blocks.length)],
      );
    }
  }

  List<Piece?> get traySnapshot => List.unmodifiable(_tray);

  // ---- Pan gesture handling (game-level) ----
  @override
  void onPanStart(DragStartInfo info) {
    if (_gameOver) return;
    final pos = info.eventPosition.global;
    final slotIdx = _slotAt(pos);
    if (slotIdx == null) return;
    final piece = _tray[slotIdx];
    if (piece == null) return;
    _drag = DragState(slotIdx: slotIdx, piece: piece, pos: pos.clone());
    _lastDragPos = pos.clone();
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (_drag == null) return;
    _lastDragPos = info.eventPosition.global.clone();
    _drag!.pos = _lastDragPos!.clone();
  }

  @override
  void onPanEnd(DragEndInfo info) {
    if (_drag == null) return;
    final pos = _lastDragPos ?? _drag!.pos;
    _endDrag(pos);
  }

  int? _slotAt(Vector2 pos) {
    if (pos.y < _trayY || pos.y > _trayY + _traySlotPx) return null;
    final gap = 8.0;
    for (int i = 0; i < kTraySize; i++) {
      final ox = trayOriginX + i * (_traySlotPx + gap);
      if (pos.x >= ox && pos.x <= ox + _traySlotPx) return i;
    }
    return null;
  }

  void _endDrag(Vector2 pos) {
    final d = _drag;
    if (d == null) return;
    _drag = null;

    final shape = d.piece.shape;
    final cellX = ((pos.x - _gridOriginX) / _gridPx).floor() - (shape[0].length ~/ 2);
    final cellY = ((pos.y - _gridOriginY) / _gridPx).floor() - (shape.length ~/ 2);

    if (pieceFits(d.piece, cellX, cellY)) {
      placePiece(d.piece, cellX, cellY, d.slotIdx);
    }
  }

  bool pieceFits(Piece piece, int ox, int oy) {
    for (int r = 0; r < piece.shape.length; r++) {
      for (int c = 0; c < piece.shape[0].length; c++) {
        if (piece.shape[r][c] == 0) continue;
        final gx = ox + c;
        final gy = oy + r;
        if (gx < 0 || gx >= kGridSize || gy < 0 || gy >= kGridSize) return false;
        if (_grid[gy][gx] != null) return false;
      }
    }
    return true;
  }

  void placePiece(Piece piece, int ox, int oy, int slotIdx) {
    int cellCount = 0;
    for (int r = 0; r < piece.shape.length; r++) {
      for (int c = 0; c < piece.shape[0].length; c++) {
        if (piece.shape[r][c] == 1) {
          _grid[oy + r][ox + c] = piece.color;
          cellCount++;
        }
      }
    }
    _score += cellCount;
    onScoreChanged?.call(_score);

    if (_audioReady) {
      try { FlameAudio.play('put.mp3', volume: 0.4); } catch (_) {}
    }

    // Find completed rows/cols
    final fullRows = <int>[];
    final fullCols = <int>[];
    for (int y = 0; y < kGridSize; y++) {
      if (_grid[y].every((c) => c != null)) fullRows.add(y);
    }
    for (int x = 0; x < kGridSize; x++) {
      bool full = true;
      for (int y = 0; y < kGridSize; y++) {
        if (_grid[y][x] == null) {
          full = false;
          break;
        }
      }
      if (full) fullCols.add(x);
    }

    if (fullRows.isNotEmpty || fullCols.isNotEmpty) {
      final lines = fullRows.length + fullCols.length;
      final bonus = (lines * (lines + 1) * 5) ~/ 2;
      _score += bonus;
      onScoreChanged?.call(_score);

      final toClear = <Point<int>>{};
      for (final y in fullRows) {
        for (int x = 0; x < kGridSize; x++) {
          toClear.add(Point(x, y));
        }
      }
      for (final x in fullCols) {
        for (int y = 0; y < kGridSize; y++) {
          toClear.add(Point(x, y));
        }
      }

      _flashing.addAll(toClear);
      _flashElapsed = 0;

      Future.delayed(const Duration(milliseconds: 320), () {
        for (final p in toClear) {
          _grid[p.y][p.x] = null;
        }
        _flashing.clear();
        if (_audioReady) {
          try { FlameAudio.play('score.mp3', volume: 0.5); } catch (_) {}
        }
      });
    }

    // Consume the tray slot
    _tray[slotIdx] = null;
    if (_tray.every((p) => p == null)) {
      refillTray();
    }

    // Check game over
    if (!anyPieceFits()) {
      _gameOver = true;
      onGameOverChanged?.call(true, _score);
      if (_audioReady) {
        try { FlameAudio.play('lose.mp3', volume: 0.6); } catch (_) {}
      }
    }
  }

  bool anyPieceFits() {
    for (final p in _tray) {
      if (p == null) continue;
      for (int y = 0; y < kGridSize; y++) {
        for (int x = 0; x < kGridSize; x++) {
          if (pieceFits(p, x, y)) return true;
        }
      }
    }
    return false;
  }

  void restart() {
    for (int y = 0; y < kGridSize; y++) {
      for (int x = 0; x < kGridSize; x++) {
        _grid[y][x] = null;
      }
    }
    _score = 0;
    _gameOver = false;
    _flashing.clear();
    refillTray();
    onScoreChanged?.call(_score);
    onGameOverChanged?.call(false, 0);
  }

  // ---- Render info ----
  Piece? get draggedPiece => _drag?.piece;
  bool isDraggingSlot(int slotIdx) => _drag?.slotIdx == slotIdx;
  BlockColor? cellAt(int x, int y) => _grid[y][x];
  int get score => _score;
  bool get isGameOver => _gameOver;

  /// Returns the (cellX, cellY) the piece is currently hovering over.
  Point<int>? getDragCell() {
    final d = _drag;
    if (d == null) return null;
    final shape = d.piece.shape;
    final cx = ((d.pos.x - _gridOriginX) / _gridPx).floor() - (shape[0].length ~/ 2);
    final cy = ((d.pos.y - _gridOriginY) / _gridPx).floor() - (shape.length ~/ 2);
    return Point(cx, cy);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_flashing.isNotEmpty) {
      _flashElapsed += dt;
    }
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
    _renderGrid(canvas);
    _renderTray(canvas);
    _renderDraggedPiece(canvas);
  }

  void _renderGrid(ui.Canvas canvas) {
    final bgPaint = ui.Paint()..color = const ui.Color(0x731F2A4E);
    final borderPaint = ui.Paint()
      ..color = BlockPalette.gridBorder
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final panelRrect = ui.RRect.fromRectAndRadius(
      ui.Rect.fromLTWH(_gridOriginX - 8, _gridOriginY - 8, gridW + 16, gridW + 16),
      const ui.Radius.circular(14),
    );
    canvas.drawRRect(panelRrect, bgPaint);
    canvas.drawRRect(panelRrect, borderPaint);

    for (int y = 0; y < kGridSize; y++) {
      for (int x = 0; x < kGridSize; x++) {
        final cx = _gridOriginX + x * _gridPx;
        final cy = _gridOriginY + y * _gridPx;
        final color = _grid[y][x];
        final cellRect = ui.Rect.fromLTWH(cx + 2, cy + 2, _gridPx - 4, _gridPx - 4);
        final cellRrect = ui.RRect.fromRectAndRadius(cellRect, const ui.Radius.circular(6));

        if (color == null) {
          canvas.drawRRect(cellRrect, ui.Paint()..color = BlockPalette.gridCell);
        } else if (_flashing.contains(Point(x, y))) {
          final t = (_flashElapsed / 0.32).clamp(0.0, 1.0);
          final flash = ui.Color.lerp(const ui.Color(0xFFFFFFFF), color.base, t)!;
          canvas.drawRRect(cellRrect, ui.Paint()..color = flash);
        } else {
          drawBlock(canvas, cellRrect, color);
        }
      }
    }

    final d = _drag;
    final dragCell = getDragCell();
    if (d != null && dragCell != null) {
      final fits = pieceFits(d.piece, dragCell.x, dragCell.y);
      final previewColor = fits ? d.piece.color.base : const ui.Color(0xFFC93131);
      for (int r = 0; r < d.piece.shape.length; r++) {
        for (int c = 0; c < d.piece.shape[0].length; c++) {
          if (d.piece.shape[r][c] == 0) continue;
          final gx = dragCell.x + c;
          final gy = dragCell.y + r;
          if (gx < 0 || gx >= kGridSize || gy < 0 || gy >= kGridSize) continue;
          final cx = _gridOriginX + gx * _gridPx;
          final cy = _gridOriginY + gy * _gridPx;
          final cellRect = ui.Rect.fromLTWH(cx + 2, cy + 2, _gridPx - 4, _gridPx - 4);
          final cellRrect = ui.RRect.fromRectAndRadius(cellRect, const ui.Radius.circular(6));
          canvas.drawRRect(cellRrect, ui.Paint()
            ..color = previewColor.withOpacity(0.30)
            ..style = ui.PaintingStyle.fill);
          canvas.drawRRect(cellRrect, ui.Paint()
            ..color = previewColor.withOpacity(0.75)
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 2.0);
        }
      }
    }
  }

  void _renderTray(ui.Canvas canvas) {
    final gap = 8.0;
    for (int i = 0; i < kTraySize; i++) {
      final ox = trayOriginX + i * (_traySlotPx + gap);
      final slotRect = ui.Rect.fromLTWH(ox, _trayY, _traySlotPx, _traySlotPx);
      final slotRrect = ui.RRect.fromRectAndRadius(slotRect, const ui.Radius.circular(12));
      final piece = _tray[i];
      final isDragging = isDraggingSlot(i);

      canvas.drawRRect(slotRrect, ui.Paint()
        ..color = BlockPalette.gridCell.withOpacity(isDragging ? 0.20 : 0.55));
      canvas.drawRRect(slotRrect, ui.Paint()
        ..color = BlockPalette.gridBorder.withOpacity(0.6)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.0);

      if (piece == null) continue;

      final shape = piece.shape;
      final rows = shape.length;
      final cols = shape[0].length;
      final maxCellSize = (_traySlotPx - 16) / max(rows, cols);
      final pieceW = cols * maxCellSize;
      final pieceH = rows * maxCellSize;
      final startX = ox + (_traySlotPx - pieceW) / 2;
      final startY = _trayY + (_traySlotPx - pieceH) / 2;

      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          if (shape[r][c] == 0) continue;
          final cellRect = ui.Rect.fromLTWH(
            startX + c * maxCellSize + 1,
            startY + r * maxCellSize + 1,
            maxCellSize - 2,
            maxCellSize - 2,
          );
          final cellRrect = ui.RRect.fromRectAndRadius(cellRect, const ui.Radius.circular(3));
          drawBlock(canvas, cellRrect, piece.color);
        }
      }
    }
  }

  void _renderDraggedPiece(ui.Canvas canvas) {
    final d = _drag;
    if (d == null) return;
    final shape = d.piece.shape;
    final rows = shape.length;
    final cols = shape[0].length;
    final cellSize = _gridPx;
    final pieceW = cols * cellSize;
    final pieceH = rows * cellSize;
    final startX = d.pos.x - pieceW / 2;
    final startY = d.pos.y - pieceH / 2;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (shape[r][c] == 0) continue;
        final cellRect = ui.Rect.fromLTWH(
          startX + c * cellSize + 1,
          startY + r * cellSize + 1,
          cellSize - 2,
          cellSize - 2,
        );
        final cellRrect = ui.RRect.fromRectAndRadius(cellRect, const ui.Radius.circular(6));
        drawBlock(canvas, cellRrect, d.piece.color);
      }
    }
  }
}

// =============================================================================
// Data classes
// =============================================================================

class Piece {
  final List<List<int>> shape;
  final BlockColor color;
  const Piece({required this.shape, required this.color});
}

class DragState {
  final int slotIdx;
  final Piece piece;
  Vector2 pos;
  DragState({required this.slotIdx, required this.piece, required this.pos});
}

// =============================================================================
// Block drawing helper (3D-shaded rounded rect)
// =============================================================================

/// Draws a 3D-shaded block at the given RRect.
void drawBlock(ui.Canvas canvas, ui.RRect rrect, BlockColor color) {
  // Base fill
  canvas.drawRRect(rrect, ui.Paint()..color = color.base);

  // Top-left highlight
  final hw = rrect.width * 0.55;
  final hh = rrect.height * 0.30;
  final highlightRrect = ui.RRect.fromRectAndRadius(
    ui.Rect.fromLTWH(
      rrect.left + 2,
      rrect.top + 2,
      hw,
      hh,
    ),
    ui.Radius.circular(rrect.blRadius.x * 0.6),
  );
  canvas.drawRRect(highlightRrect, ui.Paint()..color = color.highlight.withOpacity(0.55));

  // Bottom shadow stripe
  final sh = rrect.height * 0.18;
  final shadowRrect = ui.RRect.fromRectAndRadius(
    ui.Rect.fromLTWH(
      rrect.left,
      rrect.bottom - sh,
      rrect.width,
      sh,
    ),
    ui.Radius.circular(rrect.blRadius.x),
  );
  canvas.drawRRect(shadowRrect, ui.Paint()..color = color.shadow.withOpacity(0.45));
}
