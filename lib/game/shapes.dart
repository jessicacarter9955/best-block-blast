/// Piece shapes for Block Blast — 22 shapes total, matching the
/// original game's piece set.

const List<List<List<int>>> kShapes = [
  // 1-cell
  [[1]],
  // 2-cell
  [[1, 1]],
  [[1], [1]],
  // 3-cell
  [[1, 1, 1]],
  [[1], [1], [1]],
  [[1, 1], [1, 0]],
  [[1, 1], [0, 1]],
  [[1, 0], [1, 1]],
  [[0, 1], [1, 1]],
  // 4-cell
  [[1, 1, 1, 1]],
  [[1], [1], [1], [1]],
  [[1, 1], [1, 1]],
  [[1, 1, 1], [0, 1, 0]], // T
  [[1, 1, 1], [1, 0, 0]],
  [[1, 1, 1], [0, 0, 1]],
  [[1, 0], [1, 1], [1, 0]],
  [[0, 1], [1, 1], [0, 1]],
  // 5-cell
  [[1, 1, 1, 1, 1]],
  [[1], [1], [1], [1], [1]],
  [[1, 1, 1], [1, 0, 0], [1, 0, 0]], // L
  [[1, 1, 1], [0, 0, 1], [0, 0, 1]],
  [[1, 0, 0], [1, 0, 0], [1, 1, 1]],
  [[0, 0, 1], [0, 0, 1], [1, 1, 1]],
];

class Piece {
  final List<List<int>> shape;
  final int colorIdx; // 0..7 — index into Block sprite frames

  const Piece({required this.shape, required this.colorIdx});

  int get cellCount => shape.expand((r) => r).fold<int>(0, (a, b) => a + b);
  int get rows => shape.length;
  int get cols => shape[0].length;
}
