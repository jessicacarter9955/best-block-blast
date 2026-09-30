import 'dart:math';
import 'package:chocoblock/game/fair_deal.dart';
import 'package:chocoblock/game/block_blast_game.dart';
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

  test(
      '500 deals survive arbitrary legal choices and keep verified continuations',
      () {
    final rng = Random(2026);
    var board = List<int?>.filled(64, null);
    for (var turn = 0; turn < 500; turn++) {
      final generated = dealFair(board, [0, 1, 2], rng);
      final remaining = {for (final move in generated) move.slot: move.shape};
      while (remaining.isNotEmpty) {
        var proof = solveFair(board, remaining, budget: 300);
        if (proof == null) {
          proof = dealFair(board, remaining.keys.toList(), rng);
          for (final m in proof) {
            remaining[m.slot] = m.shape;
          }
        }
        var check = List<int?>.of(board);
        for (final move in proof) {
          check = applyFair(check, move);
        }
        final legal = <FairMove>[];
        for (final p in remaining.entries) {
          for (var i = 0; i < 64; i++) {
            if (fitsFair(board, p.value, i ~/ 8, i % 8))
              legal.add(FairMove(p.key, p.value, i ~/ 8, i % 8));
          }
        }
        expect(legal, isNotEmpty);
        final chosen = legal[rng.nextInt(legal.length)];
        board = applyFair(board, chosen);
        remaining.remove(chosen.slot);
      }
    }
  });

  test(
      'game replaces an impossible remaining tray without changing board or score',
      () {
    final game = BlockBlastGame();
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
    expect(game.fairRefreshed, isTrue);
    expect(game.score, 123);
    expect(game.grid.expand((r) => r).toList(), before);
    expect(game.tray[2]!.placed, isTrue);
    var next = before;
    for (final move in game.solution) {
      next = applyFair(next, move);
    }
    expect(game.solution.length, 2);
  });
}
