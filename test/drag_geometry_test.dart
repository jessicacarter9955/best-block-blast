import 'dart:math' as math;

import 'package:block_rush/game/block_blast_game.dart';
import 'package:block_rush/game/layout_constants.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BlockBlastGame game;

  setUp(() {
    // Exercise the game logic without loading art or starting native audio.
    game = BlockBlastGame();
    game.storage
      ..sfx = 0
      ..music = 0
      ..tut = 0;
    game.state = GameState.hud;
  });

  void addPiece(int slot, int shape) {
    game.tray[slot] = TraySlot(shape, 0)..popT = 1;
  }

  void moveToBoardCenter(int column, int row) {
    final fingerTarget = Vector2(
      Design.gridOriginX + column * Design.bigSize,
      Design.gridOriginY + row * Design.cellHeight + 200,
    );
    game.onDragDelta(fingerTarget - game.finger);
  }

  for (final shape in [0, 21, 23, 24]) {
    test('shape $shape grows smoothly to a board cell without overshoot', () {
      addPiece(1, shape);
      game.onDragStart(game.slotCenter(1));
      expect(game.dragSlot, 1);

      var previousCellSize = Design.smallSize * game.dragScale;
      for (var frame = 0; frame < 30; frame++) {
        game.update(1 / 60);
        final cellSize = Design.smallSize * game.dragScale;
        expect(cellSize, greaterThanOrEqualTo(previousCellSize));
        expect(cellSize, lessThanOrEqualTo(Design.bigSize + 0.000001));
        previousCellSize = cellSize;
      }

      expect(previousCellSize, closeTo(Design.bigSize, 0.000001));
      expect(previousCellSize, closeTo(Design.bigSize, 0.000001));
    });
  }

  test('a five-cell tray piece keeps its compacted size on pickup', () {
    addPiece(1, 23);
    game.onDragStart(game.slotCenter(1));

    expect(game.dragSlot, 1);
    expect(game.dragScale, lessThan(1));
    expect(5 * Design.smallSize * game.dragScale, closeTo(300, 0.000001));
  });

  test('landscape drag coordinates snap to the rendered board cells', () {
    game.isLandscape = true;
    addPiece(1, 0);
    final trayCenter = game.slotCenter(1);
    game.onDragStart(trayCenter);
    expect(game.dragSlot, 1);

    const column = 4;
    const row = 3;
    final cellX = BlockBlastGame.landscapeBoardX +
        (Design.gridOriginX + column * Design.bigSize) *
            BlockBlastGame.landscapeBoardScale;
    final cellY = BlockBlastGame.landscapeBoardY +
        (Design.gridOriginY + row * Design.cellHeight) *
            BlockBlastGame.landscapeBoardScale;
    game.onDragDelta(Vector2(cellX - game.finger.x,
        cellY + 120 - game.finger.y));

    expect(game.dragValid, isTrue);
    expect(game.dragTargets, contains(math.Point(column, row)));
  });

  test('early release captures its current scale for the return animation', () {
    addPiece(0, 23);
    addPiece(2, 0);
    game.onDragStart(game.slotCenter(0));
    final pickupScale = game.dragScale;
    game.update(0.04);
    final releaseScale = game.dragScale;
    final releasePosition = game.dragPos.clone();
    expect(releaseScale, greaterThan(pickupScale));
    expect(Design.smallSize * releaseScale, lessThan(Design.bigSize));

    game.onDragEnd();

    expect(game.dragSlot, -1);
    expect(game.returningSlot, 0);
    expect(game.dragReturnT, 0);
    expect(game.returnScale, releaseScale);
    expect(game.returnFrom, releasePosition);

    // A new grab must not change the size captured for the previous piece.
    game.onDragStart(game.slotCenter(2));
    game.update(0.04);
    expect(game.dragSlot, 2);
    expect(game.returnScale, releaseScale);
  });

  test('cancel returns a valid preview without placing or scoring it', () {
    addPiece(1, 0);
    game.onDragStart(game.slotCenter(1));
    moveToBoardCenter(3, 3);
    expect(game.dragValid, isTrue);
    expect(game.dragTargets, [const math.Point(3, 3)]);

    game.onDragCancel();

    expect(game.grid.expand((row) => row), everyElement(isNull));
    expect(game.score, 0);
    expect(game.tray[1]!.placed, isFalse);
    expect(game.dragSlot, -1);
    expect(game.returningSlot, 1);
    expect(game.dragValid, isFalse);
    expect(game.dragTargets, isEmpty);
    expect(game.dragMarkedLines, isEmpty);
  });

  test('a compacted piece drops into the same cells as its board preview', () {
    addPiece(1, 23);
    game.onDragStart(game.slotCenter(1));
    game.update(0.2);
    moveToBoardCenter(4, 3);
    final expected = [for (var x = 2; x <= 6; x++) math.Point(x, 3)];
    expect(game.dragValid, isTrue);
    expect(game.dragTargets, expected);

    game.onDragEnd();

    final occupied = [
      for (var y = 0; y < Design.gridSize; y++)
        for (var x = 0; x < Design.gridSize; x++)
          if (game.grid[y][x] != null) math.Point(x, y),
    ];
    expect(occupied, expected);
    expect(game.score, 5);
    expect(game.tray[1]!.placed, isTrue);
  });

  test('restart clears an active drag and a piece still returning', () {
    addPiece(0, 0);
    addPiece(2, 0);
    game.onDragStart(game.slotCenter(0));
    game.onDragEnd();
    game.onDragStart(game.slotCenter(2));
    moveToBoardCenter(3, 3);
    expect(game.returningSlot, 0);
    expect(game.dragSlot, 2);
    expect(game.dragTargets, isNotEmpty);

    game.startGame();

    expect(game.dragSlot, -1);
    expect(game.returningSlot, -1);
    expect(game.dragReturnT, -1);
    expect(game.dragValid, isFalse);
    expect(game.dragTargets, isEmpty);
    expect(game.dragMarkedLines, isEmpty);
    expect(game.grid.expand((row) => row), everyElement(isNull));
  });
}
