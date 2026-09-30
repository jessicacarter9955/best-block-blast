import 'dart:math';
import 'shapes.dart';

/// A replayable proof: slot and top-left board cell, before clearing lines.
class FairMove {
  final int slot, shape, row, col;
  const FairMove(this.slot, this.shape, this.row, this.col);
}

bool fitsFair(List<int?> board, int shape, int row, int col) {
  final cells = kShapes[shape];
  for (var r = 0; r < cells.length; r++) {
    for (var c = 0; c < cells[r].length; c++) {
      if (cells[r][c] == 0) continue;
      final y = row + r, x = col + c;
      if (y < 0 || x < 0 || y >= 8 || x >= 8 || board[y * 8 + x] != null) {
        return false;
      }
    }
  }
  return true;
}

List<int?> applyFair(List<int?> board, FairMove move) {
  if (!fitsFair(board, move.shape, move.row, move.col)) {
    throw StateError('Invalid solution move');
  }
  final next = List<int?>.of(board), shape = kShapes[move.shape];
  for (var r = 0; r < shape.length; r++) {
    for (var c = 0; c < shape[r].length; c++) {
      if (shape[r][c] == 1) next[(move.row + r) * 8 + move.col + c] = 0;
    }
  }
  final rows = <int>[], cols = <int>[];
  for (var i = 0; i < 8; i++) {
    if (List.generate(8, (j) => next[i * 8 + j]).every((v) => v != null)) {
      rows.add(i);
    }
    if (List.generate(8, (j) => next[j * 8 + i]).every((v) => v != null)) {
      cols.add(i);
    }
  }
  for (var r = 0; r < 8; r++) {
    for (var c = 0; c < 8; c++) {
      if (rows.contains(r) || cols.contains(c)) next[r * 8 + c] = null;
    }
  }
  return next;
}

/// Construct a deal by actually playing all its pieces on a private board.
/// A single cell is a valid fallback: a legal post-clear board always has room.
List<FairMove> dealFair(List<int?> board, List<int> slots, Random rng) {
  var simulated = List<int?>.of(board);
  final proof = <FairMove>[];
  for (final slot in slots) {
    final shapes = List.generate(kShapes.length - 1, (i) => i + 1)
      ..shuffle(rng);
    shapes.add(0);
    FairMove? selected;
    for (final shape in shapes) {
      final positions = List.generate(64, (i) => i)..shuffle(rng);
      for (final p in positions) {
        if (fitsFair(simulated, shape, p ~/ 8, p % 8)) {
          selected = FairMove(slot, shape, p ~/ 8, p % 8);
          break;
        }
      }
      if (selected != null) break;
    }
    if (selected == null) {
      throw StateError('Board must be cleared before dealing');
    }
    proof.add(selected);
    simulated = applyFair(simulated, selected);
  }
  return proof;
}

/// Bounded search for the remaining tray, including all orders and line clears.
/// Null means no proof found within budget, never a reason to force game over.
List<FairMove>? solveFair(List<int?> board, Map<int, int> pieces,
    {int budget = 1600}) {
  var visited = 0;
  List<FairMove>? visit(List<int?> b, Map<int, int> left) {
    if (left.isEmpty) return [];
    if (++visited > budget) return null;
    for (final entry in left.entries) {
      for (var pos = 0; pos < 64; pos++) {
        if (!fitsFair(b, entry.value, pos ~/ 8, pos % 8)) continue;
        final move = FairMove(entry.key, entry.value, pos ~/ 8, pos % 8);
        final rest = Map<int, int>.of(left)..remove(entry.key);
        final tail = visit(applyFair(b, move), rest);
        if (tail != null) return [move, ...tail];
        if (visited > budget) return null;
      }
    }
    return null;
  }

  return visit(board, pieces);
}
