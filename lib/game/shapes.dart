/// Piece shapes for Block Blast — ported from the original game.
///
/// Each shape is a 2D matrix of 0/1 indicating which sub-cells of the
/// piece are filled. The original game uses 22 shapes ranging from
/// 1x1 to 5x1, plus L/T/square variants.

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
