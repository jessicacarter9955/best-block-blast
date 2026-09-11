import 'dart:async' as async;
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui' show Canvas, Color, Offset, Paint, PaintingStyle, RRect, Radius, Rect, Image;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart' as flutter show TextPainter, TextSpan, TextStyle, FontWeight, TextDirection, Color, TextDecoration;

import 'audio.dart';
import 'palette.dart';
import 'shapes.dart';
import 'sprite_cache.dart';

/// Game state enum — matches the original Construct 3 GameState variable.
enum GameState { home, playing, paused, revive, gameOver, ranking }

/// The full Block Blast game — native Flame port using original sprites.
class BlockBlastGame extends FlameGame with PanDetector {
  static const int kGridSize = 8;
  static const int kTraySize = 3;

  late SpriteCache _sprites;
  late GameAudio _audio;

  // Layout
  late double _gridPx, _gridX, _gridY, _boardPx, _boardX, _boardY;
  late double _trayY, _traySlotPx;

  // State
  late List<List<int?>> _grid;
  final List<Piece?> _tray = List.filled(kTraySize, null);
  int _score = 0;
  int _bestScore = 0;
  GameState _state = GameState.home;

  // Drag state
  _DragState? _drag;
  Vector2? _lastDragPos;

  // Visuals
  final Set<_Cell> _flashing = {};
  double _flashT = 0;
  bool _tutorialActive = false;
  double _tutorialT = 0;

  // Combo state
  int? _comboCheerfulFrame;
  int? _comboBonus;
  double _comboT = 0;
  static const double _comboDuration = 1.6;

  // Revive state
  double _reviveTimeLeft = 5.0;
  async.Timer? _reviveTimer;

  // Callbacks
  void Function(int score, int best)? onScoreChanged;
  void Function(GameState state)? onStateChanged;
  void Function(bool music, bool sfx)? onAudioTogglesChanged;

  @override
  Future<void> onLoad() async {
    _sprites = await SpriteCache.load();
    _audio = GameAudio();
    await _audio.init();
    _grid = List.generate(kGridSize, (_) => List<int?>.filled(kGridSize, null));

    add(_BackgroundComponent(_sprites));
    add(_ScorePanelComponent(this, _sprites));
    add(_BoardComponent(this, _sprites));
    add(_TrayComponent(this, _sprites));
    add(_DragPreviewComponent(this, _sprites));
    add(_TutorialHandComponent(this, _sprites));
    add(_ComboTextComponent(this, _sprites));
    add(_ComboHeartComponent(this, _sprites));
    add(_HomeScreenComponent(this, _sprites));
    add(_PausePopupComponent(this, _sprites));
    add(_GameOverComponent(this, _sprites));
    add(_ReviveComponent(this, _sprites));
    add(_RankingPopupComponent(this, _sprites));
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final w = size.x;
    final h = size.y;
    final padding = 16.0;
    final gap = 16.0;
    final headerReserve = 70.0;
    final footerReserve = 30.0;

    final trayW = w - padding * 2;
    _traySlotPx = (trayW - gap * 2) / 3;

    final availableForGrid = h - headerReserve - footerReserve - gap * 2 - _traySlotPx - gap;
    final maxGridW = w - padding * 2;
    _boardPx = maxGridW < availableForGrid ? maxGridW : availableForGrid;
    _boardX = (w - _boardPx) / 2;
    _boardY = headerReserve + gap;

    final inset = _boardPx * 0.04;
    _gridX = _boardX + inset;
    _gridY = _boardY + inset;
    _gridPx = (_boardPx - inset * 2) / kGridSize;

    _trayY = _boardY + _boardPx + gap;
  }

  // Public getters
  double get gridPx => _gridPx;
  double get gridX => _gridX;
  double get gridY => _gridY;
  double get boardPx => _boardPx;
  double get boardX => _boardX;
  double get boardY => _boardY;
  double get trayY => _trayY;
  double get traySlotPx => _traySlotPx;
  double get trayOriginX => 16;
  SpriteCache get sprites => _sprites;
  GameAudio get audio => _audio;
  GameState get state => _state;
  int? cellAt(int x, int y) => _grid[y][x];
  List<Piece?> get traySnapshot => List.unmodifiable(_tray);
  int get score => _score;
  int get bestScore => _bestScore;
  bool get musicOn => _audio.musicOn;
  bool get sfxOn => _audio.sfxOn;
  bool get isPlaying => _state == GameState.playing;
  bool get isHome => _state == GameState.home;
  bool get isPaused => _state == GameState.paused;
  bool get isGameOver => _state == GameState.gameOver;
  bool get isRevive => _state == GameState.revive;
  bool get isRanking => _state == GameState.ranking;
  double get reviveTimeLeft => _reviveTimeLeft;

  // State transitions
  void startGame() {
    _grid = List.generate(kGridSize, (_) => List<int?>.filled(kGridSize, null));
    _score = 0;
    for (int i = 0; i < kTraySize; i++) _tray[i] = null;
    refillTray();
    _tutorialActive = true;
    _tutorialT = 0;
    _flashing.clear();
    _comboCheerfulFrame = null;
    _comboBonus = null;
    _state = GameState.playing;
    onScoreChanged?.call(_score, _bestScore);
    onStateChanged?.call(_state);
    _audio.startMusic();
  }

  void goHome() {
    _state = GameState.home;
    _audio.pauseMusic();
    onStateChanged?.call(_state);
  }

  void openPause() {
    if (_state != GameState.playing) return;
    _state = GameState.paused;
    _audio.pauseMusic();
    onStateChanged?.call(_state);
  }

  void closePause() {
    if (_state != GameState.paused) return;
    _state = GameState.playing;
    _audio.resumeMusic();
    onStateChanged?.call(_state);
  }

  void openRanking() {
    _state = GameState.ranking;
    onStateChanged?.call(_state);
  }

  void closeRanking() {
    _state = GameState.playing;
    onStateChanged?.call(_state);
  }

  void toggleMusic() {
    _audio.toggleMusic();
    onAudioTogglesChanged?.call(_audio.musicOn, _audio.sfxOn);
  }

  void toggleSfx() {
    _audio.toggleSfx();
    onAudioTogglesChanged?.call(_audio.musicOn, _audio.sfxOn);
  }

  void refillTray() {
    final rng = Random();
    for (int i = 0; i < kTraySize; i++) {
      _tray[i] = Piece(
        shape: kShapes[rng.nextInt(kShapes.length)],
        colorIdx: rng.nextInt(BlockPalette.kBlockVariants),
      );
    }
  }

  @override
  void onPanStart(DragStartInfo info) {
    if (_state != GameState.playing) return;
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

    final fullRows = <int>[];
    final fullCols = <int>[];
    for (int y = 0; y < kGridSize; y++) {
      if (_grid[y].every((c) => c != null)) fullRows.add(y);
    }
    for (int x = 0; x < kGridSize; x++) {
      bool full = true;
      for (int y = 0; y < kGridSize; y++) {
        if (_grid[y][x] == null) { full = false; break; }
      }
      if (full) fullCols.add(x);
    }

    if (fullRows.isNotEmpty || fullCols.isNotEmpty) {
      final lines = fullRows.length + fullCols.length;
      final bonus = (lines * (lines + 1) * 5) ~/ 2;
      _score += bonus;
      if (_score > _bestScore) _bestScore = _score;
      onScoreChanged?.call(_score, _bestScore);
      _comboCheerfulFrame = _cheerfulFrameFor(lines);
      _comboBonus = bonus;
      _comboT = 0;

      final toClear = <_Cell>{};
      for (final y in fullRows) {
        for (int x = 0; x < kGridSize; x++) toClear.add(_Cell(x, y));
      }
      for (final x in fullCols) {
        for (int y = 0; y < kGridSize; y++) toClear.add(_Cell(x, y));
      }
      _flashing.addAll(toClear);
      _flashT = 0;

      Future<void>.delayed(const Duration(milliseconds: 320), () {
        for (final c in toClear) _grid[c.y][c.x] = null;
        _flashing.clear();
        _audio.sfxScore();
      });
    }

    _tray[slotIdx] = null;
    if (_tray.every((p) => p == null)) refillTray();

    if (!anyPieceFits()) _triggerGameOver();
  }

  int _cheerfulFrameFor(int lines) {
    if (lines <= 1) return 2;
    if (lines == 2) return 3;
    if (lines == 3) return 4;
    if (lines == 4) return 5;
    return 6;
  }

  void _triggerGameOver() {
    _state = GameState.revive;
    _reviveTimeLeft = 5.0;
    onStateChanged?.call(_state);
    _reviveTimer?.cancel();
    _reviveTimer = async.Timer.periodic(const Duration(milliseconds: 100), (t) {
      _reviveTimeLeft -= 0.1;
      if (_reviveTimeLeft <= 0) {
        t.cancel();
        _state = GameState.gameOver;
        _audio.sfxLose();
        _audio.stopMusic();
        onStateChanged?.call(_state);
      }
    });
  }

  void revive() {
    _reviveTimer?.cancel();
    for (int y = 5; y < kGridSize; y++) {
      for (int x = 0; x < kGridSize; x++) _grid[y][x] = null;
    }
    _state = GameState.playing;
    onStateChanged?.call(_state);
    _audio.resumeMusic();
  }

  void skipRevive() {
    _reviveTimer?.cancel();
    _state = GameState.gameOver;
    _audio.sfxLose();
    _audio.stopMusic();
    onStateChanged?.call(_state);
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
  int? get comboCheerfulFrame => _comboCheerfulFrame;
  int? get comboBonus => _comboBonus;
  bool get tutorialActive => _tutorialActive;

  @override
  void update(double dt) {
    super.update(dt);
    if (_flashing.isNotEmpty) _flashT += dt;
    if (_tutorialActive) _tutorialT += dt;
    if (_comboCheerfulFrame != null) {
      _comboT += dt;
      if (_comboT >= _comboDuration) {
        _comboCheerfulFrame = null;
        _comboBonus = null;
      }
    }
  }
}

// === Data classes ===
class _Cell {
  final int x, y;
  const _Cell(this.x, this.y);
  @override
  bool operator ==(Object o) => o is _Cell && o.x == x && o.y == y;
  @override
  int get hashCode => Object.hash(x, y);
}

class _DragState {
  final int slotIdx;
  final Piece piece;
  Vector2 pos;
  _DragState({required this.slotIdx, required this.piece, required this.pos});
}

// === Background ===
class _BackgroundComponent extends PositionComponent with HasGameRef<BlockBlastGame> {
  final SpriteCache sprites;
  late Sprite _bg;
  _BackgroundComponent(this.sprites);
  @override
  Future<void> onLoad() async => _bg = sprites.get('Bg');
  @override
  void render(Canvas canvas) {
    final w = gameRef.size.x;
    final h = gameRef.size.y;
    final srcW = _bg.srcSize.x;
    final srcH = _bg.srcSize.y;
    final scaleY = h / srcH;
    final tileW = srcW * scaleY;
    int n = (w / tileW).ceil();
    for (int i = 0; i < n; i++) {
      _bg.render(canvas, position: Vector2(i * tileW, 0), size: Vector2(tileW + 1, h));
    }
  }
}

// === Score panel ===
class _ScorePanelComponent extends PositionComponent with HasGameRef<BlockBlastGame> {
  final BlockBlastGame game_;
  final SpriteCache sprites;
  late Sprite _crown;
  _ScorePanelComponent(this.game_, this.sprites);
  @override
  Future<void> onLoad() async => _crown = sprites.get('CupIcon');
  @override
  void render(Canvas canvas) {
    if (gameRef.state == GameState.home) return;
    final w = gameRef.size.x;
    _crown.render(canvas, position: Vector2(16, 20), size: Vector2(44, 44));
    final scoreTp = flutter.TextPainter(
      text: flutter.TextSpan(text: '${gameRef.score}',
        style: const flutter.TextStyle(color: flutter.Color(0xFFFFFFFF), fontSize: 30, fontWeight: flutter.FontWeight.w800, letterSpacing: 1.0)),
      textDirection: flutter.TextDirection.ltr,
    )..layout();
    scoreTp.paint(canvas, Offset((w - scoreTp.width) / 2, 24));
    final bestTp = flutter.TextPainter(
      text: flutter.TextSpan(text: 'BEST ${gameRef.bestScore}',
        style: const flutter.TextStyle(color: flutter.Color(0xFFFAB82A), fontSize: 11, fontWeight: flutter.FontWeight.w600, letterSpacing: 0.8)),
      textDirection: flutter.TextDirection.ltr,
    )..layout();
    bestTp.paint(canvas, Offset((w - bestTp.width) / 2, 58));
  }
}

// === Board + grid ===
class _BoardComponent extends PositionComponent with HasGameRef<BlockBlastGame> {
  final BlockBlastGame game_;
  final SpriteCache sprites;
  late Sprite _board;
  _BoardComponent(this.game_, this.sprites);
  @override
  Future<void> onLoad() async => _board = sprites.get('Board');
  @override
  void render(Canvas canvas) {
    if (gameRef.state == GameState.home) return;
    _board.render(canvas, position: Vector2(gameRef.boardX, gameRef.boardY), size: Vector2(gameRef.boardPx, gameRef.boardPx));
    final px = gameRef.gridPx;
    for (int y = 0; y < BlockBlastGame.kGridSize; y++) {
      for (int x = 0; x < BlockBlastGame.kGridSize; x++) {
        final cx = gameRef.gridX + x * px;
        final cy = gameRef.gridY + y * px;
        final colorIdx = gameRef.cellAt(x, y);
        final isFlashing = gameRef._flashing.contains(_Cell(x, y));
        if (colorIdx == null) {
          final r = Rect.fromLTWH(cx + 1, cy + 1, px - 2, px - 2);
          canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), Paint()..color = const Color(0xFF1F2A4E));
        } else if (isFlashing) {
          final t = (gameRef._flashT / 0.32).clamp(0.0, 1.0);
          final flash = Color.lerp(const Color(0xFFFFFFFF), const Color(0xFF1F2A4E), t)!;
          canvas.drawRect(Rect.fromLTWH(cx, cy, px, px), Paint()..color = flash);
        } else {
          sprites.get('Block', frame: colorIdx).render(canvas, position: Vector2(cx, cy), size: Vector2(px, px));
        }
      }
    }
  }
}

// === Tray ===
class _TrayComponent extends PositionComponent with HasGameRef<BlockBlastGame> {
  final BlockBlastGame game_;
  final SpriteCache sprites;
  _TrayComponent(this.game_, this.sprites);
  @override
  void render(Canvas canvas) {
    if (gameRef.state == GameState.home) return;
    final gap = 8.0;
    for (int i = 0; i < BlockBlastGame.kTraySize; i++) {
      final ox = gameRef.trayOriginX + i * (gameRef.traySlotPx + gap);
      final r = Rect.fromLTWH(ox, gameRef.trayY, gameRef.traySlotPx, gameRef.traySlotPx);
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(14));
      canvas.drawRRect(rr, Paint()..color = const Color(0x731F2A4E));
      canvas.drawRRect(rr, Paint()
        ..color = const Color(0xFF3E559F).withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4);
      final piece = gameRef.traySnapshot[i];
      if (piece == null) continue;
      final isDragging = gameRef.isDraggingSlot(i);
      final rows = piece.rows, cols = piece.cols;
      final maxCell = (gameRef.traySlotPx - 16) / max(rows, cols);
      final pw = cols * maxCell, ph = rows * maxCell;
      final sx = ox + (gameRef.traySlotPx - pw) / 2;
      final sy = gameRef.trayY + (gameRef.traySlotPx - ph) / 2;
      final bs = sprites.get('Block', frame: piece.colorIdx);
      if (isDragging) canvas.saveLayer(r, Paint()..color = const Color.fromRGBO(0, 0, 0, 0.25));
      for (int r2 = 0; r2 < rows; r2++) {
        for (int c2 = 0; c2 < cols; c2++) {
          if (piece.shape[r2][c2] == 0) continue;
          bs.render(canvas, position: Vector2(sx + c2 * maxCell, sy + r2 * maxCell), size: Vector2(maxCell, maxCell));
        }
      }
      if (isDragging) canvas.restore();
    }
  }
}

// === Drag preview ===
class _DragPreviewComponent extends PositionComponent with HasGameRef<BlockBlastGame> {
  final BlockBlastGame game_;
  final SpriteCache sprites;
  _DragPreviewComponent(this.game_, this.sprites);
  @override
  void render(Canvas canvas) {
    final piece = gameRef.draggedPiece;
    if (piece == null) return;
    final dc = gameRef.getDragCell();
    if (dc != null) {
      final fits = gameRef.pieceFits(piece, dc.x, dc.y);
      final pc = fits ? BlockPalette.blockColors[piece.colorIdx] : const Color(0xFFC93131);
      final px = gameRef.gridPx;
      for (int r = 0; r < piece.rows; r++) {
        for (int c = 0; c < piece.cols; c++) {
          if (piece.shape[r][c] == 0) continue;
          final gx = dc.x + c, gy = dc.y + r;
          if (gx < 0 || gx >= BlockBlastGame.kGridSize || gy < 0 || gy >= BlockBlastGame.kGridSize) continue;
          final cx = gameRef.gridX + gx * px, cy = gameRef.gridY + gy * px;
          final rr = RRect.fromRectAndRadius(Rect.fromLTWH(cx, cy, px, px), const Radius.circular(4));
          canvas.drawRRect(rr, Paint()..color = pc.withOpacity(0.30));
          canvas.drawRRect(rr, Paint()
            ..color = pc.withOpacity(0.75)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0);
        }
      }
    }
    final pos = gameRef.dragPos;
    if (pos != null) {
      final cp = gameRef.gridPx;
      final pw = piece.cols * cp, ph = piece.rows * cp;
      final sx = pos.x - pw / 2, sy = pos.y - ph / 2;
      final bs = sprites.get('Block', frame: piece.colorIdx);
      for (int r = 0; r < piece.rows; r++) {
        for (int c = 0; c < piece.cols; c++) {
          if (piece.shape[r][c] == 0) continue;
          bs.render(canvas, position: Vector2(sx + c * cp, sy + r * cp), size: Vector2(cp, cp));
        }
      }
    }
  }
}

// === Tutorial hand ===
class _TutorialHandComponent extends PositionComponent with HasGameRef<BlockBlastGame> {
  final BlockBlastGame game_;
  final SpriteCache sprites;
  late Sprite _hand;
  _TutorialHandComponent(this.game_, this.sprites);
  @override
  Future<void> onLoad() async => _hand = sprites.get('Hand');
  @override
  void render(Canvas canvas) {
    if (!gameRef.tutorialActive || gameRef.state != GameState.playing) return;
    final t = gameRef._tutorialT;
    final cycle = (t % 2.0) / 2.0;
    double p = cycle < 0.5 ? cycle * 2 : 2 - cycle * 2;
    p = p.clamp(0.0, 1.0);
    final sx = gameRef.trayOriginX + gameRef.traySlotPx / 2;
    final sy = gameRef.trayY + gameRef.traySlotPx / 2;
    final ex = gameRef.gridX + gameRef.gridPx * 4;
    final ey = gameRef.gridY + gameRef.gridPx * 4;
    final x = sx + (ex - sx) * p, y = sy + (ey - sy) * p;
    _hand.render(canvas, position: Vector2(x - 36, y - 70), size: Vector2(72, 60));
  }
}

// === Combo text (Cheerful sprite) ===
class _ComboTextComponent extends PositionComponent with HasGameRef<BlockBlastGame> {
  final BlockBlastGame game_;
  final SpriteCache sprites;
  _ComboTextComponent(this.game_, this.sprites);
  @override
  void render(Canvas canvas) {
    final frame = gameRef.comboCheerfulFrame;
    if (frame == null) return;
    final t = gameRef._comboT;
    final dur = BlockBlastGame._comboDuration;
    final floatUp = (t / dur).clamp(0.0, 1.0) * 40;
    final opacity = t > dur - 0.5 ? (1.0 - (t - (dur - 0.5)) / 0.5).clamp(0.0, 1.0) : 1.0;
    final w = gameRef.size.x;
    final cx = w / 2;
    final cy = gameRef.gridY + gameRef.gridPx * 3 - floatUp;

    final sprite = sprites.get('Cheerful', frame: frame);
    final srcSize = sprite.srcSize;
    final maxW = w * 0.7;
    final maxH = 140.0;
    final scaleW = maxW / srcSize.x;
    final scaleH = maxH / srcSize.y;
    final scale = scaleW < scaleH ? scaleW : scaleH;
    final drawW = srcSize.x * scale, drawH = srcSize.y * scale;

    canvas.saveLayer(Rect.fromLTWH(0, cy - 20, w, drawH + 60), Paint()..color = Color.fromRGBO(255, 255, 255, opacity));
    sprite.render(canvas, position: Vector2(cx - drawW / 2, cy), size: Vector2(drawW, drawH));
    canvas.restore();

    final bonus = gameRef.comboBonus;
    if (bonus != null) {
      final bp = flutter.TextPainter(
        text: flutter.TextSpan(text: '+$bonus',
          style: flutter.TextStyle(color: flutter.Color(0xFFFFFFFF).withOpacity(opacity), fontSize: 22, fontWeight: flutter.FontWeight.w700)),
        textDirection: flutter.TextDirection.ltr,
      )..layout();
      bp.paint(canvas, Offset(cx - bp.width / 2, cy + drawH + 6));
    }
  }
}

// === Combo heart ===
class _ComboHeartComponent extends PositionComponent with HasGameRef<BlockBlastGame> {
  final BlockBlastGame game_;
  final SpriteCache sprites;
  late Sprite _heart;
  _ComboHeartComponent(this.game_, this.sprites);
  @override
  Future<void> onLoad() async => _heart = sprites.get('Heart');
  @override
  void render(Canvas canvas) {
    final frame = gameRef.comboCheerfulFrame;
    if (frame == null || frame < 3) return;
    final t = gameRef._comboT;
    final dur = BlockBlastGame._comboDuration;
    final opacity = t > dur - 0.5 ? (1.0 - (t - (dur - 0.5)) / 0.5).clamp(0.0, 1.0) : 1.0;
    final pulse = 1.0 + 0.1 * (0.5 + 0.5 * sin(t * 8));
    final size = 50.0 * pulse;
    canvas.saveLayer(Rect.fromLTWH(0, 0, gameRef.size.x, 100), Paint()..color = Color.fromRGBO(255, 255, 255, opacity));
    _heart.render(canvas, position: Vector2(20, 18), size: Vector2(size, size));
    canvas.restore();
  }
}

// === Home screen ===
class _HomeScreenComponent extends PositionComponent with HasGameRef<BlockBlastGame>, TapCallbacks {
  final BlockBlastGame game_;
  final SpriteCache sprites;
  late Sprite _btnPlay;
  late Sprite _btnRanking;
  late Rect _playRect;
  late Rect _rankingRect;
  _HomeScreenComponent(this.game_, this.sprites);
  @override
  Future<void> onLoad() async {
    _btnPlay = sprites.get('BtnPlay');
    _btnRanking = sprites.get('BtnShowRanking');
  }
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final w = size.x;
    final playW = w * 0.6, playH = playW * (115.0 / 332);
    _playRect = Rect.fromLTWH((w - playW) / 2, size.y * 0.55, playW, playH);
    final rankW = w * 0.4, rankH = rankW * (115.0 / 332);
    _rankingRect = Rect.fromLTWH((w - rankW) / 2, _playRect.bottom + 30, rankW, rankH);
  }
  @override
  void render(Canvas canvas) {
    if (!gameRef.isHome) return;
    final w = gameRef.size.x;
    final tp = flutter.TextPainter(
      text: flutter.TextSpan(
        children: [
          flutter.TextSpan(text: 'BLOCK ', style: flutter.TextStyle(color: flutter.Color(0xFFFFFFFF), fontSize: 42, fontWeight: flutter.FontWeight.w800, letterSpacing: 2.0)),
          flutter.TextSpan(text: 'BLAST', style: flutter.TextStyle(color: flutter.Color(0xFFFAB82A), fontSize: 42, fontWeight: flutter.FontWeight.w800, letterSpacing: 2.0)),
        ],
      ),
      textDirection: flutter.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, gameRef.size.y * 0.25));

    if (gameRef.bestScore > 0) {
      final bp = flutter.TextPainter(
        text: flutter.TextSpan(text: 'BEST: ${gameRef.bestScore}',
          style: flutter.TextStyle(color: flutter.Color(0xFFFAB82A), fontSize: 18, fontWeight: flutter.FontWeight.w600, letterSpacing: 1.0)),
        textDirection: flutter.TextDirection.ltr,
      )..layout();
      bp.paint(canvas, Offset((w - bp.width) / 2, gameRef.size.y * 0.25 + tp.height + 12));
    }

    _btnPlay.render(canvas, position: Vector2(_playRect.left, _playRect.top), size: Vector2(_playRect.width, _playRect.height));
    _btnRanking.render(canvas, position: Vector2(_rankingRect.left, _rankingRect.top), size: Vector2(_rankingRect.width, _rankingRect.height));
  }
  @override
  bool containsLocalPoint(Vector2 p) {
    if (!gameRef.isHome) return false;
    return _playRect.contains(p.toOffset()) || _rankingRect.contains(p.toOffset());
  }
  @override
  void onTapDown(TapDownEvent info) {
    if (!gameRef.isHome) return;
    final p = info.globalPosition;
    if (_playRect.contains(p.toOffset())) {
      gameRef.startGame();
    } else if (_rankingRect.contains(p.toOffset())) {
      gameRef.openRanking();
    }
  }
}

// === Pause popup ===
class _PausePopupComponent extends PositionComponent with HasGameRef<BlockBlastGame>, TapCallbacks {
  final BlockBlastGame game_;
  final SpriteCache sprites;
  late Sprite _popup;
  late Rect _popupRect;
  late Rect _homeRect, _resetRect, _rankingRect, _musicRect, _sfxRect;
  _PausePopupComponent(this.game_, this.sprites);
  @override
  Future<void> onLoad() async => _popup = sprites.get('PausePopup');
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final w = size.x;
    final popW = w * 0.85;
    final popH = popW * (1113.0 / 886);
    _popupRect = Rect.fromLTWH((w - popW) / 2, (size.y - popH) / 2, popW, popH);
    final btnSize = popW * 0.14;
    final gap = (popW - btnSize * 5) / 6;
    final btnY = _popupRect.bottom - btnSize - 30;
    _homeRect = Rect.fromLTWH(_popupRect.left + gap, btnY, btnSize, btnSize);
    _resetRect = Rect.fromLTWH(_homeRect.right + gap, btnY, btnSize, btnSize);
    _rankingRect = Rect.fromLTWH(_resetRect.right + gap, btnY, btnSize, btnSize);
    _musicRect = Rect.fromLTWH(_rankingRect.right + gap, btnY, btnSize, btnSize);
    _sfxRect = Rect.fromLTWH(_musicRect.right + gap, btnY, btnSize, btnSize);
  }
  @override
  void render(Canvas canvas) {
    if (!gameRef.isPaused) return;
    canvas.drawRect(Rect.fromLTWH(0, 0, gameRef.size.x, gameRef.size.y), Paint()..color = const Color(0xCC0A1119));
    _popup.render(canvas, position: Vector2(_popupRect.left, _popupRect.top), size: Vector2(_popupRect.width, _popupRect.height));
    final tp = flutter.TextPainter(
      text: flutter.TextSpan(text: 'PAUSED',
        style: flutter.TextStyle(color: flutter.Color(0xFFFFFFFF), fontSize: 32, fontWeight: flutter.FontWeight.w800, letterSpacing: 2.0)),
      textDirection: flutter.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(_popupRect.center.dx - tp.width / 2, _popupRect.top + 60));
    sprites.get('BtnHome').render(canvas, position: Vector2(_homeRect.left, _homeRect.top), size: Vector2(_homeRect.width, _homeRect.height));
    sprites.get('BtnReset').render(canvas, position: Vector2(_resetRect.left, _resetRect.top), size: Vector2(_resetRect.width, _resetRect.height));
    sprites.get('BtnShowRanking').render(canvas, position: Vector2(_rankingRect.left, _rankingRect.top), size: Vector2(_rankingRect.width, _rankingRect.height));
    sprites.get('BtnMusic', frame: gameRef.musicOn ? 0 : 1).render(canvas, position: Vector2(_musicRect.left, _musicRect.top), size: Vector2(_musicRect.width, _musicRect.height));
    sprites.get('BtnSFX', frame: gameRef.sfxOn ? 0 : 1).render(canvas, position: Vector2(_sfxRect.left, _sfxRect.top), size: Vector2(_sfxRect.width, _sfxRect.height));
  }
  @override
  bool containsLocalPoint(Vector2 p) => gameRef.isPaused;
  @override
  void onTapDown(TapDownEvent info) {
    if (!gameRef.isPaused) return;
    final p = info.globalPosition;
    if (_homeRect.contains(p.toOffset())) {
      gameRef.goHome();
    } else if (_resetRect.contains(p.toOffset())) {
      gameRef.startGame();
    } else if (_rankingRect.contains(p.toOffset())) {
      gameRef.openRanking();
    } else if (_musicRect.contains(p.toOffset())) {
      gameRef.toggleMusic();
    } else if (_sfxRect.contains(p.toOffset())) {
      gameRef.toggleSfx();
    } else if (!_popupRect.contains(p.toOffset())) {
      gameRef.closePause();
    }
  }
}

// === Game Over ===
class _GameOverComponent extends PositionComponent with HasGameRef<BlockBlastGame>, TapCallbacks {
  final BlockBlastGame game_;
  final SpriteCache sprites;
  late Sprite _banner;
  late Rect _restartRect;
  _GameOverComponent(this.game_, this.sprites);
  @override
  Future<void> onLoad() async => _banner = sprites.get('GameOver');
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final w = size.x;
    final bannerW = w * 0.7;
    final bannerH = bannerW * (78.0 / 469);
    final bannerY = size.y * 0.3;
    _restartRect = Rect.fromLTWH((w - 200) / 2, bannerY + bannerH + 80, 200, 50);
  }
  @override
  void render(Canvas canvas) {
    if (!gameRef.isGameOver) return;
    canvas.drawRect(Rect.fromLTWH(0, 0, gameRef.size.x, gameRef.size.y), Paint()..color = const Color(0xE60A1119));
    final w = gameRef.size.x;
    final bannerW = w * 0.7;
    final bannerH = bannerW * (78.0 / 469);
    final bannerY = gameRef.size.y * 0.3;
    _banner.render(canvas, position: Vector2((w - bannerW) / 2, bannerY), size: Vector2(bannerW, bannerH));
    final sp = flutter.TextPainter(
      text: flutter.TextSpan(text: '${gameRef.score}',
        style: flutter.TextStyle(color: flutter.Color(0xFFFFFFFF), fontSize: 48, fontWeight: flutter.FontWeight.w800)),
      textDirection: flutter.TextDirection.ltr,
    )..layout();
    sp.paint(canvas, Offset((w - sp.width) / 2, bannerY + bannerH + 20));
    final bp = flutter.TextPainter(
      text: flutter.TextSpan(text: 'BEST: ${gameRef.bestScore}',
        style: flutter.TextStyle(color: flutter.Color(0xFFFAB82A), fontSize: 16, fontWeight: flutter.FontWeight.w600)),
      textDirection: flutter.TextDirection.ltr,
    )..layout();
    bp.paint(canvas, Offset((w - bp.width) / 2, bannerY + bannerH + 80));
    final rr = RRect.fromRectAndRadius(_restartRect, const Radius.circular(8));
    canvas.drawRRect(rr, Paint()..color = const Color(0xFFFAB82A));
    final tp = flutter.TextPainter(
      text: flutter.TextSpan(text: 'PLAY AGAIN',
        style: flutter.TextStyle(color: flutter.Color(0xFF0A1119), fontSize: 16, fontWeight: flutter.FontWeight.w800, letterSpacing: 1.0)),
      textDirection: flutter.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(_restartRect.center.dx - tp.width / 2, _restartRect.center.dy - tp.height / 2));
    final hp = flutter.TextPainter(
      text: flutter.TextSpan(text: 'or tap anywhere',
        style: flutter.TextStyle(color: flutter.Color(0xFF6B7280), fontSize: 11)),
      textDirection: flutter.TextDirection.ltr,
    )..layout();
    hp.paint(canvas, Offset((w - hp.width) / 2, _restartRect.bottom + 12));
  }
  @override
  bool containsLocalPoint(Vector2 p) => gameRef.isGameOver;
  @override
  void onTapDown(TapDownEvent info) {
    if (!gameRef.isGameOver) return;
    gameRef.goHome();
  }
}

// === Revive ===
class _ReviveComponent extends PositionComponent with HasGameRef<BlockBlastGame>, TapCallbacks {
  final BlockBlastGame game_;
  final SpriteCache sprites;
  late Sprite _circle;
  late Rect _reviveRect;
  late Rect _skipRect;
  _ReviveComponent(this.game_, this.sprites);
  @override
  Future<void> onLoad() async => _circle = sprites.get('ReviveCircle');
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final w = size.x;
    final circleSize = w * 0.5;
    final circleY = size.y * 0.3;
    _reviveRect = Rect.fromLTWH((w - 200) / 2, circleY + circleSize + 30, 200, 50);
    _skipRect = Rect.fromLTWH((w - 100) / 2, _reviveRect.bottom + 12, 100, 30);
  }
  @override
  void render(Canvas canvas) {
    if (!gameRef.isRevive) return;
    canvas.drawRect(Rect.fromLTWH(0, 0, gameRef.size.x, gameRef.size.y), Paint()..color = const Color(0xE60A1119));
    final w = gameRef.size.x;
    final circleSize = w * 0.5;
    final circleY = gameRef.size.y * 0.3;
    _circle.render(canvas, position: Vector2((w - circleSize) / 2, circleY), size: Vector2(circleSize, circleSize));
    final num = gameRef.reviveTimeLeft.ceil();
    final tp = flutter.TextPainter(
      text: flutter.TextSpan(text: '$num',
        style: flutter.TextStyle(color: flutter.Color(0xFFFFFFFF), fontSize: 64, fontWeight: flutter.FontWeight.w800)),
      textDirection: flutter.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(w / 2 - tp.width / 2, circleY + circleSize / 2 - tp.height / 2));
    final rr = RRect.fromRectAndRadius(_reviveRect, const Radius.circular(8));
    canvas.drawRRect(rr, Paint()..color = const Color(0xFFFAB82A));
    final rp = flutter.TextPainter(
      text: flutter.TextSpan(text: 'REVIVE',
        style: flutter.TextStyle(color: flutter.Color(0xFF0A1119), fontSize: 16, fontWeight: flutter.FontWeight.w800)),
      textDirection: flutter.TextDirection.ltr,
    )..layout();
    rp.paint(canvas, Offset(_reviveRect.center.dx - rp.width / 2, _reviveRect.center.dy - rp.height / 2));
    final sp = flutter.TextPainter(
      text: flutter.TextSpan(text: 'Skip',
        style: flutter.TextStyle(color: flutter.Color(0xFF6B7280), fontSize: 14, decoration: flutter.TextDecoration.underline)),
      textDirection: flutter.TextDirection.ltr,
    )..layout();
    sp.paint(canvas, Offset(_skipRect.left, _skipRect.top));
  }
  @override
  bool containsLocalPoint(Vector2 p) => gameRef.isRevive;
  @override
  void onTapDown(TapDownEvent info) {
    if (!gameRef.isRevive) return;
    final p = info.globalPosition;
    if (_reviveRect.contains(p.toOffset())) {
      gameRef.revive();
    } else if (_skipRect.contains(p.toOffset())) {
      gameRef.skipRevive();
    }
  }
}

// === Ranking popup ===
class _RankingPopupComponent extends PositionComponent with HasGameRef<BlockBlastGame>, TapCallbacks {
  final BlockBlastGame game_;
  final SpriteCache sprites;
  late Sprite _popup;
  late Rect _popupRect;
  late Rect _closeRect;
  final List<Map<String, dynamic>> _ranking = [
    {'name': 'Kara', 'score': 1720},
    {'name': 'Philip', 'score': 1520},
    {'name': 'Gianni', 'score': 1378},
    {'name': 'Camila', 'score': 1240},
    {'name': 'Logan', 'score': 580},
  ];
  _RankingPopupComponent(this.game_, this.sprites);
  @override
  Future<void> onLoad() async => _popup = sprites.get('PausePopup');
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final w = size.x;
    final popW = w * 0.85;
    final popH = popW * (1113.0 / 886);
    _popupRect = Rect.fromLTWH((w - popW) / 2, (size.y - popH) / 2, popW, popH);
    _closeRect = Rect.fromLTWH(_popupRect.right - 50, _popupRect.top + 20, 40, 40);
  }
  @override
  void render(Canvas canvas) {
    if (!gameRef.isRanking) return;
    canvas.drawRect(Rect.fromLTWH(0, 0, gameRef.size.x, gameRef.size.y), Paint()..color = const Color(0xCC0A1119));
    _popup.render(canvas, position: Vector2(_popupRect.left, _popupRect.top), size: Vector2(_popupRect.width, _popupRect.height));
    final tp = flutter.TextPainter(
      text: flutter.TextSpan(text: 'RANKING',
        style: flutter.TextStyle(color: flutter.Color(0xFFFFFFFF), fontSize: 28, fontWeight: flutter.FontWeight.w800, letterSpacing: 1.5)),
      textDirection: flutter.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(_popupRect.center.dx - tp.width / 2, _popupRect.top + 50));
    double y = _popupRect.top + 110;
    for (int i = 0; i < _ranking.length; i++) {
      final entry = _ranking[i];
      final rp = flutter.TextPainter(
        text: flutter.TextSpan(
          children: [
            flutter.TextSpan(text: '${i + 1}. ', style: flutter.TextStyle(color: flutter.Color(0xFFFAB82A), fontSize: 18, fontWeight: flutter.FontWeight.w700)),
            flutter.TextSpan(text: entry['name'], style: flutter.TextStyle(color: flutter.Color(0xFFFFFFFF), fontSize: 18, fontWeight: flutter.FontWeight.w600)),
            flutter.TextSpan(text: '   ${entry['score']}', style: flutter.TextStyle(color: flutter.Color(0xFFE5E7EB), fontSize: 16)),
          ],
        ),
        textDirection: flutter.TextDirection.ltr,
      )..layout();
      rp.paint(canvas, Offset(_popupRect.left + 40, y));
      y += 36;
    }
    final cp = flutter.TextPainter(
      text: flutter.TextSpan(text: 'X', style: flutter.TextStyle(color: flutter.Color(0xFFFFFFFF), fontSize: 24)),
      textDirection: flutter.TextDirection.ltr,
    )..layout();
    cp.paint(canvas, Offset(_closeRect.left + 8, _closeRect.top + 4));
  }
  @override
  bool containsLocalPoint(Vector2 p) => gameRef.isRanking;
  @override
  void onTapDown(TapDownEvent info) {
    if (!gameRef.isRanking) return;
    final p = info.globalPosition;
    if (_closeRect.contains(p.toOffset()) || !_popupRect.contains(p.toOffset())) {
      gameRef.closeRanking();
    }
  }
}
