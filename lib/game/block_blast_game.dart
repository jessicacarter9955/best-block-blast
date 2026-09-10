import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, RRect, Radius, Rect, Image;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart' as flutter show TextPainter, TextSpan, TextStyle, FontWeight, TextDirection, Color;

import 'audio.dart';
import 'palette.dart';
import 'shapes.dart';
import 'sprite_cache.dart';

/// The full Block Blast game — a native Flame port using the original
/// Construct 3 sprite assets (chocolate recolor applied to the Block
/// sprite sheet).
///
/// Layout (portrait phone):
///   - Top: header overlay (Flutter-rendered: title + score panel)
///   - Middle: Board sprite (8x8 grid panel) with block cells
///   - Bottom: 3-slot tray with piece previews
///   - Background: Bg sprite (vertical blue gradient strip) tiled to
///     fill the screen
///
/// State:
///   - 8x8 grid of (colorIdx | null)
///   - 3 tray slots each holding a Piece (or null)
///   - score, game-over flag, music/sfx toggles
///
/// Drag-and-drop:
///   - Pan gesture at game level
///   - PanStart: hit-test tray slots, start drag if hit
///   - PanUpdate: move floating piece + show preview on grid
///   - PanEnd: drop piece if it fits, snap back to tray otherwise
class BlockBlastGame extends FlameGame with PanDetector {
  static const int kGridSize = 8;
  static const int kTraySize = 3;

  late SpriteCache _sprites;
  late GameAudio _audio;

  // Layout (set in onGameResize)
  late double _gridPx; // size of one cell
  late double _gridX; // top-left x of grid (board panel inside)
  late double _gridY; // top-left y of grid (board panel inside)
  late double _boardPx; // size of the Board sprite (panel including border)
  late double _boardX; // top-left x of board sprite
  late double _boardY; // top-left y of board sprite
  late double _trayY;
  late double _traySlotPx;
  late double _headerReserve;

  // State
  late List<List<int?>> _grid; // each cell is null or colorIdx 0..7
  final List<Piece?> _tray = List.filled(kTraySize, null);
  int _score = 0;
  int _bestScore = 0;
  bool _gameOver = false;
  bool _paused = false;

  // Drag state
  _DragState? _drag;
  Vector2? _lastDragPos;

  // Visuals
  final Set<_Cell> _flashing = {};
  double _flashT = 0;

  // Tutorial state — show hand animation until first piece is placed
  bool _tutorialActive = true;
  double _tutorialT = 0;

  // Combo text state — show "Amazing!" / "Combo x2" / "+N" on line clears
  String? _comboMsg; // "Amazing!", "Great!", "Combo x3", etc.
  int? _comboBonus; // the +N score popup
  double _comboT = 0; // time since combo text appeared (for animation)
  static const double _comboDuration = 1.5; // seconds the combo text shows

  // Callbacks to Flutter overlay
  void Function(int score, int best)? onScoreChanged;
  void Function(bool over)? onGameOverChanged;
  void Function(bool paused)? onPausedChanged;
  void Function(bool music, bool sfx)? onAudioTogglesChanged;

  @override
  Future<void> onLoad() async {
    _sprites = await SpriteCache.load();
    _audio = GameAudio();
    await _audio.init();
    _grid = List.generate(kGridSize, (_) => List<int?>.filled(kGridSize, null));

    // Add the background first (drawn behind everything).
    add(_BackgroundComponent(_sprites));
    // Add the score panel (CupIcon + score number at the top).
    add(_ScorePanelComponent(this, _sprites));
    // Add the board panel + grid cells.
    add(_BoardComponent(this, _sprites));
    // Add the tray (3 slots).
    add(_TrayComponent(this, _sprites));
    // Add the drag preview layer (renders floating piece + ghost preview).
    add(_DragPreviewComponent(this, _sprites));
    // Add the tutorial hand (shows on first launch until first piece placed).
    add(_TutorialHandComponent(this, _sprites));
    // Add the combo text layer (floating "Amazing!" / "Combo x2" / "+N").
    add(_ComboTextComponent(this));

    // Initial state.
    refillTray();
    _audio.startMusic();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final w = size.x;
    final h = size.y;

    // Layout reserves:
    //   top: header overlay (~70px) rendered by Flutter
    //   bottom: footer hint (~30px) rendered by Flutter
    _headerReserve = 70;
    final footerReserve = 30;
    final gap = 16;
    final padding = 16;

    // Tray: 3 squares below the grid, each slot is square.
    // Tray width = w - padding*2, slot = (trayW - gap*2) / 3
    final trayW = w - padding * 2;
    _traySlotPx = (trayW - gap * 2) / 3;

    // The grid + tray must fit in: h - headerReserve - footerReserve - gap (between grid and tray) - gap (above grid)
    // Grid size = the board panel size = a square.
    final availableForGrid = h - _headerReserve - footerReserve - gap * 2 - _traySlotPx - gap;
    final maxGridW = w - padding * 2;
    _boardPx = maxGridW < availableForGrid ? maxGridW : availableForGrid;
    _boardX = (w - _boardPx) / 2;
    _boardY = _headerReserve + gap;

    // The grid (cells) is inset from the board sprite — the board sprite
    // has a thick border. Empirically the board sprite is 994x994 and
    // the inner grid is roughly 8x125 = 1000px (but board is 994, so
    // inner grid is ~7/8 of the board, with ~6% padding on each side).
    // For our layout we'll just give the grid a small inset (3% of boardPx).
    final inset = _boardPx * 0.04;
    _gridX = _boardX + inset;
    _gridY = _boardY + inset;
    _gridPx = (_boardPx - inset * 2) / kGridSize;

    // Tray Y: below the board + gap.
    _trayY = _boardY + _boardPx + gap;
  }

  // Public getters used by child components
  double get gridPx => _gridPx;
  double get gridX => _gridX;
  double get gridY => _gridY;
  double get boardPx => _boardPx;
  double get boardX => _boardX;
  double get boardY => _boardY;
  double get trayY => _trayY;
  double get traySlotPx => _traySlotPx;
  double get trayOriginX => 16;
  Size get viewport => size.toSize();
  SpriteCache get sprites => _sprites;
  GameAudio get audio => _audio;

  // ---- State accessors ----
  int? cellAt(int x, int y) => _grid[y][x];
  List<Piece?> get traySnapshot => List.unmodifiable(_tray);
  int get score => _score;
  int get bestScore => _bestScore;
  bool get isGameOver => _gameOver;
  bool get isPaused => _paused;
  bool get musicOn => _audio.musicOn;
  bool get sfxOn => _audio.sfxOn;

  // ---- Tray logic ----
  void refillTray() {
    final rng = Random();
    for (int i = 0; i < kTraySize; i++) {
      _tray[i] = Piece(
        shape: kShapes[rng.nextInt(kShapes.length)],
        colorIdx: rng.nextInt(BlockPalette.kBlockVariants),
      );
    }
  }

  // ---- Drag handling (game-level) ----
  @override
  void onPanStart(DragStartInfo info) {
    if (_gameOver || _paused) return;
    final pos = info.eventPosition.global;
    final slotIdx = _slotAt(pos);
    if (slotIdx == null) return;
    final piece = _tray[slotIdx];
    if (piece == null) return;
    _drag = _DragState(slotIdx: slotIdx, piece: piece, pos: pos.clone());
    _lastDragPos = pos.clone();
    _audio.sfxWhoosh();
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
    final cellX = ((pos.x - _gridX) / _gridPx).floor() - (shape[0].length ~/ 2);
    final cellY = ((pos.y - _gridY) / _gridPx).floor() - (shape.length ~/ 2);

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
    // Dismiss tutorial on first piece placement
    _tutorialActive = false;

    for (int r = 0; r < piece.shape.length; r++) {
      for (int c = 0; c < piece.shape[0].length; c++) {
        if (piece.shape[r][c] == 1) {
          _grid[oy + r][ox + c] = piece.colorIdx;
        }
      }
    }
    _score += piece.cellCount;
    if (_score > _bestScore) _bestScore = _score;
    onScoreChanged?.call(_score, _bestScore);

    _audio.sfxPut();

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
      if (_score > _bestScore) _bestScore = _score;
      onScoreChanged?.call(_score, _bestScore);

      // Trigger combo floating text
      _comboMsg = _comboMessageFor(lines);
      _comboBonus = bonus;
      _comboT = 0;

      final toClear = <_Cell>{};
      for (final y in fullRows) {
        for (int x = 0; x < kGridSize; x++) {
          toClear.add(_Cell(x, y));
        }
      }
      for (final x in fullCols) {
        for (int y = 0; y < kGridSize; y++) {
          toClear.add(_Cell(x, y));
        }
      }

      _flashing.addAll(toClear);
      _flashT = 0;

      Future<void>.delayed(const Duration(milliseconds: 320), () {
        for (final c in toClear) {
          _grid[c.y][c.x] = null;
        }
        _flashing.clear();
        _audio.sfxScore();
      });
    }

    _tray[slotIdx] = null;
    if (_tray.every((p) => p == null)) {
      refillTray();
    }

    if (!anyPieceFits()) {
      _gameOver = true;
      onGameOverChanged?.call(true);
      _audio.sfxLose();
      _audio.stopMusic();
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
    _paused = false;
    _flashing.clear();
    _tutorialActive = true;
    _tutorialT = 0;
    _comboMsg = null;
    _comboBonus = null;
    _comboT = 0;
    refillTray();
    onScoreChanged?.call(_score, _bestScore);
    onGameOverChanged?.call(false);
    onPausedChanged?.call(false);
    _audio.startMusic();
  }

  String _comboMessageFor(int lines) {
    switch (lines) {
      case 1: return 'Good!';
      case 2: return 'Great!';
      case 3: return 'Amazing!';
      case 4: return 'Awesome!';
      default: return 'Combo x$lines!';
    }
  }

  void togglePause() {
    if (_gameOver) return;
    _paused = !_paused;
    onPausedChanged?.call(_paused);
    if (_paused) {
      _audio.pauseMusic();
    } else {
      _audio.resumeMusic();
    }
  }

  void toggleMusic() {
    _audio.toggleMusic();
    onAudioTogglesChanged?.call(_audio.musicOn, _audio.sfxOn);
  }

  void toggleSfx() {
    _audio.toggleSfx();
    onAudioTogglesChanged?.call(_audio.musicOn, _audio.sfxOn);
  }

  // ---- Drag render info (used by _DragPreviewComponent) ----
  Piece? get draggedPiece => _drag?.piece;
  bool isDraggingSlot(int slotIdx) => _drag?.slotIdx == slotIdx;

  _Cell? getDragCell() {
    final d = _drag;
    if (d == null) return null;
    final shape = d.piece.shape;
    final cx = ((d.pos.x - _gridX) / _gridPx).floor() - (shape[0].length ~/ 2);
    final cy = ((d.pos.y - _gridY) / _gridPx).floor() - (shape.length ~/ 2);
    return _Cell(cx, cy);
  }

  Vector2? get dragPos => _drag?.pos;

  @override
  void update(double dt) {
    super.update(dt);
    if (_flashing.isNotEmpty) {
      _flashT += dt;
    }
    if (_tutorialActive) {
      _tutorialT += dt;
    }
    if (_comboMsg != null) {
      _comboT += dt;
      if (_comboT >= _comboDuration) {
        _comboMsg = null;
        _comboBonus = null;
      }
    }
  }
}

// =============================================================================
// Data classes
// =============================================================================

class _Cell {
  final int x, y;
  const _Cell(this.x, this.y);
  @override
  bool operator ==(Object other) => other is _Cell && other.x == x && other.y == y;
  @override
  int get hashCode => Object.hash(x, y);
}

class _DragState {
  final int slotIdx;
  final Piece piece;
  Vector2 pos;
  _DragState({required this.slotIdx, required this.piece, required this.pos});
}

// =============================================================================
// Background — vertical gradient using Bg sprite (27x1920 strip)
// =============================================================================

class _BackgroundComponent extends PositionComponent with HasGameRef<BlockBlastGame> {
  final SpriteCache sprites;
  late final Sprite _bgSprite;

  _BackgroundComponent(this.sprites);

  @override
  Future<void> onLoad() async {
    _bgSprite = sprites.get('Bg');
  }

  @override
  void render(Canvas canvas) {
    final w = gameRef.size.x;
    final h = gameRef.size.y;
    // Tile the Bg sprite horizontally — it's a 27px-wide strip.
    // Stretch the strip to cover the screen width while preserving
    // the vertical gradient.
    final srcW = _bgSprite.srcSize.x;
    final srcH = _bgSprite.srcSize.y;
    // Scale the strip's height to match the screen height, then scale
    // width by the same factor. If the resulting width < screen width,
    // tile (but for a 27px strip scaled to 915px height, the scaled
    // width is ~13px, so we need to tile ~30 times).
    final scaleY = h / srcH;
    final tileW = srcW * scaleY;
    final tileH = h;
    int n = (w / tileW).ceil();
    for (int i = 0; i < n; i++) {
      _bgSprite.render(
        canvas,
        position: Vector2(i * tileW, 0),
        size: Vector2(tileW + 1, tileH),
      );
    }
  }
}

// =============================================================================
// Board + grid cells
// =============================================================================

class _BoardComponent extends PositionComponent with HasGameRef<BlockBlastGame> {
  final BlockBlastGame game_;
  final SpriteCache sprites;
  late final Sprite _boardSprite;
  late final Sprite _blockShadowSprite;

  _BoardComponent(this.game_, this.sprites);

  @override
  Future<void> onLoad() async {
    _boardSprite = sprites.get('Board');
    _blockShadowSprite = sprites.get('BlockShadow');
  }

  @override
  void render(Canvas canvas) {
    // 1. Draw the Board sprite (the grid panel background).
    _boardSprite.render(
      canvas,
      position: Vector2(gameRef.boardX, gameRef.boardY),
      size: Vector2(gameRef.boardPx, gameRef.boardPx),
    );

    // 2. Draw the 8x8 grid cells.
    final px = gameRef.gridPx;
    final gx = gameRef.gridX;
    final gy = gameRef.gridY;
    for (int y = 0; y < BlockBlastGame.kGridSize; y++) {
      for (int x = 0; x < BlockBlastGame.kGridSize; x++) {
        final cx = gx + x * px;
        final cy = gy + y * px;
        final colorIdx = gameRef.cellAt(x, y);
        final isFlashing = gameRef._flashing.contains(_Cell(x, y));

        if (colorIdx == null) {
          // Empty cell: draw a subtle darker rect to indicate the grid.
          final cellRect = Rect.fromLTWH(cx + 1, cy + 1, px - 2, px - 2);
          final rrect = RRect.fromRectAndRadius(cellRect, const Radius.circular(4));
          canvas.drawRRect(rrect, Paint()..color = const Color(0xFF1F2A4E));
        } else if (isFlashing) {
          // Flash white during clear animation.
          final t = (gameRef._flashT / 0.32).clamp(0.0, 1.0);
          final flash = Color.lerp(const Color(0xFFFFFFFF), const Color(0xFF1F2A4E), t)!;
          final cellRect = Rect.fromLTWH(cx, cy, px, px);
          canvas.drawRect(cellRect, Paint()..color = flash);
        } else {
          // Filled cell: draw the Block sprite for this colorIdx.
          final blockSprite = sprites.get('Block', frame: colorIdx);
          blockSprite.render(
            canvas,
            position: Vector2(cx, cy),
            size: Vector2(px, px),
          );
        }
      }
    }
  }
}

// =============================================================================
// Tray (3 piece slots)
// =============================================================================

class _TrayComponent extends PositionComponent with HasGameRef<BlockBlastGame> {
  final BlockBlastGame game_;
  final SpriteCache sprites;

  _TrayComponent(this.game_, this.sprites);

  @override
  void render(Canvas canvas) {
    final gap = 8.0;
    final slotPx = gameRef.traySlotPx;
    final trayY = gameRef.trayY;
    final trayX = gameRef.trayOriginX;

    for (int i = 0; i < BlockBlastGame.kTraySize; i++) {
      final ox = trayX + i * (slotPx + gap);
      final slotRect = Rect.fromLTWH(ox, trayY, slotPx, slotPx);
      final slotRrect = RRect.fromRectAndRadius(slotRect, const Radius.circular(14));

      // Slot background (rounded rect, semi-transparent dark)
      canvas.drawRRect(slotRrect, Paint()
        ..color = const Color(0x731F2A4E));
      canvas.drawRRect(slotRrect, Paint()
        ..color = const Color(0xFF3E559F).withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4);

      final piece = gameRef.traySnapshot[i];
      if (piece == null) continue;

      final isDragging = gameRef.isDraggingSlot(i);
      final opacity = isDragging ? 0.25 : 1.0;

      // Draw the piece's blocks centered in the slot.
      _drawPieceInSlot(canvas, piece, ox, trayY, slotPx, opacity);
    }
  }

  void _drawPieceInSlot(Canvas canvas, Piece piece, double ox, double oy, double slotPx, double opacity) {
    final rows = piece.rows;
    final cols = piece.cols;
    // Each block in the tray is sized to fit the slot, with the piece
    // centered. Block size = min((slotPx - 16) / max(rows, cols), ...)
    final maxCellSize = (slotPx - 16) / max(rows, cols);
    final pieceW = cols * maxCellSize;
    final pieceH = rows * maxCellSize;
    final startX = ox + (slotPx - pieceW) / 2;
    final startY = oy + (slotPx - pieceH) / 2;

    final blockSprite = sprites.get('Block', frame: piece.colorIdx);

    // Save canvas state so we can apply opacity via a layer.
    if (opacity < 1.0) {
      canvas.saveLayer(Rect.fromLTWH(ox, oy, slotPx, slotPx), Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
    }
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (piece.shape[r][c] == 0) continue;
        final cellRect = Rect.fromLTWH(
          startX + c * maxCellSize,
          startY + r * maxCellSize,
          maxCellSize,
          maxCellSize,
        );
        blockSprite.render(
          canvas,
          position: Vector2(cellRect.left, cellRect.top),
          size: Vector2(cellRect.width, cellRect.height),
        );
      }
    }
    if (opacity < 1.0) {
      canvas.restore();
    }
  }
}

// =============================================================================
// Drag preview layer — floating piece under finger + ghost preview on grid
// =============================================================================

class _DragPreviewComponent extends PositionComponent with HasGameRef<BlockBlastGame> {
  final BlockBlastGame game_;
  final SpriteCache sprites;

  _DragPreviewComponent(this.game_, this.sprites);

  @override
  void render(Canvas canvas) {
    final piece = gameRef.draggedPiece;
    if (piece == null) return;

    // 1. Draw ghost preview on the grid (the cells the piece would
    //    occupy if dropped now).
    final dragCell = gameRef.getDragCell();
    if (dragCell != null) {
      final fits = gameRef.pieceFits(piece, dragCell.x, dragCell.y);
      final previewColor = fits
          ? BlockPalette.blockColors[piece.colorIdx]
          : const Color(0xFFC93131);
      final px = gameRef.gridPx;
      for (int r = 0; r < piece.rows; r++) {
        for (int c = 0; c < piece.cols; c++) {
          if (piece.shape[r][c] == 0) continue;
          final gx = dragCell.x + c;
          final gy = dragCell.y + r;
          if (gx < 0 || gx >= BlockBlastGame.kGridSize || gy < 0 || gy >= BlockBlastGame.kGridSize) continue;
          final cx = gameRef.gridX + gx * px;
          final cy = gameRef.gridY + gy * px;
          final cellRect = Rect.fromLTWH(cx, cy, px, px);
          final cellRrect = RRect.fromRectAndRadius(cellRect, const Radius.circular(4));
          canvas.drawRRect(cellRrect, Paint()
            ..color = previewColor.withOpacity(0.30));
          canvas.drawRRect(cellRrect, Paint()
            ..color = previewColor.withOpacity(0.75)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0);
        }
      }
    }

    // 2. Draw the floating piece under the finger.
    final pos = gameRef.dragPos;
    if (pos != null) {
      final cellPx = gameRef.gridPx;
      final pieceW = piece.cols * cellPx;
      final pieceH = piece.rows * cellPx;
      final startX = pos.x - pieceW / 2;
      final startY = pos.y - pieceH / 2;
      final blockSprite = sprites.get('Block', frame: piece.colorIdx);
      for (int r = 0; r < piece.rows; r++) {
        for (int c = 0; c < piece.cols; c++) {
          if (piece.shape[r][c] == 0) continue;
          blockSprite.render(
            canvas,
            position: Vector2(startX + c * cellPx, startY + r * cellPx),
            size: Vector2(cellPx, cellPx),
          );
        }
      }
    }
  }
}

// =============================================================================
// Score panel — CupIcon (crown) + score number + best score at the top
// =============================================================================

class _ScorePanelComponent extends PositionComponent with HasGameRef<BlockBlastGame> {
  final BlockBlastGame game_;
  final SpriteCache sprites;
  late final Sprite _crownSprite;

  _ScorePanelComponent(this.game_, this.sprites);

  @override
  Future<void> onLoad() async {
    _crownSprite = sprites.get('CupIcon');
  }

  @override
  void render(Canvas canvas) {
    if (gameRef.isGameOver || gameRef.isPaused) return;

    final w = gameRef.size.x;
    final crownSize = 44.0;
    final crownX = 16.0;
    final crownY = 20.0;

    // Draw the crown (CupIcon) on the left
    _crownSprite.render(
      canvas,
      position: Vector2(crownX, crownY),
      size: Vector2(crownSize, crownSize),
    );

    // Draw the score number in the center-top area (large, white)
    final scoreText = '${gameRef.score}';
    final scoreTp = flutter.TextPainter(
      text: flutter.TextSpan(
        text: scoreText,
        style: const flutter.TextStyle(
          color: flutter.Color(0xFFFFFFFF),
          fontSize: 30,
          fontWeight: flutter.FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: flutter.TextDirection.ltr,
    )..layout();

    final scoreX = (w - scoreTp.width) / 2;
    final scoreY = 24.0;
    scoreTp.paint(canvas, Offset(scoreX, scoreY));

    // Draw BEST score below the main score (small, muted gold)
    final bestTp = flutter.TextPainter(
      text: flutter.TextSpan(
        text: 'BEST ${gameRef.bestScore}',
        style: const flutter.TextStyle(
          color: flutter.Color(0xFFFAB82A),
          fontSize: 11,
          fontWeight: flutter.FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: flutter.TextDirection.ltr,
    )..layout();
    bestTp.paint(canvas, Offset((w - bestTp.width) / 2, scoreY + 34));
  }
}

// =============================================================================
// Tutorial hand — animates from tray slot 0 to grid center on first launch
// =============================================================================

class _TutorialHandComponent extends PositionComponent with HasGameRef<BlockBlastGame> {
  final BlockBlastGame game_;
  final SpriteCache sprites;
  late final Sprite _handSprite;

  _TutorialHandComponent(this.game_, this.sprites);

  @override
  Future<void> onLoad() async {
    _handSprite = sprites.get('Hand');
  }

  @override
  void render(Canvas canvas) {
    if (!gameRef._tutorialActive || gameRef.isGameOver || gameRef.isPaused) return;

    final t = gameRef._tutorialT;
    final cycle = (t % 2.0) / 2.0;
    double progress;
    if (cycle < 0.5) {
      progress = cycle * 2;
    } else {
      progress = 2 - cycle * 2;
    }
    progress = progress.clamp(0.0, 1.0);

    final startX = gameRef.trayOriginX + gameRef.traySlotPx / 2;
    final startY = gameRef.trayY + gameRef.traySlotPx / 2;
    final endX = gameRef.gridX + gameRef.gridPx * 4;
    final endY = gameRef.gridY + gameRef.gridPx * 4;

    final x = startX + (endX - startX) * progress;
    final y = startY + (endY - startY) * progress;

    final handW = 72.0;
    final handH = 60.0;
    _handSprite.render(
      canvas,
      position: Vector2(x - handW / 2, y - handH - 10),
      size: Vector2(handW, handH),
    );
  }
}

// =============================================================================
// Combo text — floating "Amazing!" / "Combo x2" / "+N" on line clears
// =============================================================================

class _ComboTextComponent extends PositionComponent with HasGameRef<BlockBlastGame> {
  final BlockBlastGame game_;

  _ComboTextComponent(this.game_);

  @override
  void render(Canvas canvas) {
    final msg = gameRef._comboMsg;
    if (msg == null) return;

    final t = gameRef._comboT;
    final duration = BlockBlastGame._comboDuration;
    final floatUp = (t / duration).clamp(0.0, 1.0) * 40;
    final opacity = t > duration - 0.5
        ? (1.0 - (t - (duration - 0.5)) / 0.5).clamp(0.0, 1.0)
        : 1.0;

    final w = gameRef.size.x;
    final centerX = w / 2;
    final centerY = gameRef.gridY + gameRef.gridPx * 3 - floatUp;

    final msgTp = flutter.TextPainter(
      text: flutter.TextSpan(
        text: msg,
        style: flutter.TextStyle(
          color: const flutter.Color(0xFFFAB82A).withOpacity(opacity),
          fontSize: 32,
          fontWeight: flutter.FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: flutter.TextDirection.ltr,
    )..layout();
    msgTp.paint(canvas, Offset(centerX - msgTp.width / 2, centerY));

    final bonus = gameRef._comboBonus;
    if (bonus != null) {
      final bonusTp = flutter.TextPainter(
        text: flutter.TextSpan(
          text: '+$bonus',
          style: flutter.TextStyle(
            color: const flutter.Color(0xFFFFFFFF).withOpacity(opacity),
            fontSize: 22,
            fontWeight: flutter.FontWeight.w700,
          ),
        ),
        textDirection: flutter.TextDirection.ltr,
      )..layout();
      bonusTp.paint(canvas, Offset(centerX - bonusTp.width / 2, centerY + 38));
    }
  }
}
