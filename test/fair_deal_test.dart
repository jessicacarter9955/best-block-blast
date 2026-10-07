import 'dart:math';
import 'package:block_rush/game/fair_deal.dart';
import 'package:block_rush/game/block_blast_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a scarce board deals a complete replayable path, including clears', () {
    final board = List<int?>.generate(64, (i) => i ~/ 8 == i % 8 ? null : 1);
    var next = board;
    final proof = dealFair(board, [0, 1, 2], Random(7));
    expect(proof.length, 3);
    for (final move in proof) {
      expect(fitsFair(next, move.shape, move.row, move.col), isTrue);
      next = applyFair(next, move);
    }
    expect(board.where((v) => v == null).length, 8);
  });

  test('individually fitting pieces need not form a playable tray', () {
    final board = List<int?>.generate(64, (i) {
      final r = i ~/ 8, c = i % 8;
      return (r < 2 && c < 2) || (r + c) % 2 == 0 ? null : 0;
    });
    expect(fitsFair(board, 25, 0, 0), isTrue);
    expect(solveFair(board, {0: 25, 1: 25, 2: 25}), isNull);
    var next = board;
    for (final move in dealFair(board, [0, 1, 2], Random(4))) {
      next = applyFair(next, move);
    }
  });

  test('500 generated trays each have a complete replayable solution', () {
    final rng = Random(2026);
    var board = List<int?>.filled(64, null);
    for (var turn = 0; turn < 500; turn++) {
      final generated = dealFair(board, [0, 1, 2], rng);
      expect(generated.length, 3);
      expect(generated.map((m) => m.slot).toSet().length, 3);
      for (final move in generated) {
        expect(fitsFair(board, move.shape, move.row, move.col), isTrue);
        board = applyFair(board, move);
      }
    }
  });

  test('loss keeps the tray fixed and preserves the last valid replay', () {
    final game = BlockBlastGame();
    game.createShapes();
    final proofBoard = List<int?>.of(game.replayBoard);
    final proofMoves = List<FairMove>.of(game.replayMoves);
    game.score = 123;
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        game.grid[y][x] = y == x ? null : 0;
      }
    }
    game.tray[0] = TraySlot(28, 0);
    game.tray[1] = TraySlot(28, 1);
    game.tray[2] = TraySlot(28, 2)..placed = true;
    final before = game.grid.expand((r) => r).toList();
    game.ensureFairContinuation();
    expect(game.anyRemainingFits(), isFalse);
    expect(game.tray[0]!.shapeIdx, 28);
    expect(game.tray[1]!.shapeIdx, 28);
    expect(game.score, 123);
    expect(game.grid.expand((r) => r).toList(), before);
    expect(game.tray[2]!.placed, isTrue);
    expect(game.solution, isEmpty);
    expect(game.replayBoard, proofBoard);
    expect(game.replayMoves, proofMoves);
    var next = proofBoard;
    for (final move in game.replayMoves) {
      next = applyFair(next, move);
    }
    game.openReplay();
    expect(game.replayOpen, isTrue);
    expect(game.grid.expand((r) => r).toList(), before);
    expect(game.score, 123);
  });

  test('hint requires a completed rewarded ad; cancellation never grants it',
      () async {
    final game = BlockBlastGame();
    game.createShapes();
    game.openHint();
    await game.requestHintAd();
    expect(game.showSolution, isFalse);
    expect(game.hintDialog, isTrue);
    game.rewardedHintAd = () async => false;
    await game.requestHintAd();
    expect(game.showSolution, isFalse);
    game.rewardedHintAd = () async => true;
    await game.requestHintAd();
    expect(game.showSolution, isTrue);
    expect(game.hintDialog, isFalse);
    expect(game.hintBusy, isFalse);
  });
}
