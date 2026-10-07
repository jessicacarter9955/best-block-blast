import 'dart:math' as math;

enum BeamDirection { north, east, south, west }

class MirrorSpec {
  const MirrorSpec(this.row, this.column, this.solution, this.initial);

  final int row;
  final int column;
  final bool solution;
  final bool initial;
}

class PuzzleLevel {
  const PuzzleLevel({
    required this.sourceRow,
    required this.exit,
    required this.exitIndex,
    required this.mirrors,
    required this.crystals,
  });

  static const int size = 7;
  final int sourceRow;
  final BeamDirection exit;
  final int exitIndex;
  final List<MirrorSpec> mirrors;
  final List<math.Point<int>> crystals;

  RayResult trace([Map<int, bool>? orientations]) {
    final mirrorAt = <int, MirrorSpec>{
      for (var i = 0; i < mirrors.length; i++)
        mirrors[i].row * size + mirrors[i].column: mirrors[i],
    };
    var row = sourceRow;
    var column = 0;
    var direction = BeamDirection.east;
    final points = <math.Point<double>>[
      const math.Point<double>(-0.5, 0),
    ];
    points[0] = math.Point<double>(-0.5, sourceRow.toDouble());
    final lit = <math.Point<int>>{};
    final visited = <int>{};

    while (row >= 0 && row < size && column >= 0 && column < size) {
      final state = (row * size + column) * 4 + direction.index;
      if (!visited.add(state)) break;
      points.add(math.Point<double>(column.toDouble(), row.toDouble()));
      lit.add(math.Point<int>(column, row));
      final mirror = mirrorAt[row * size + column];
      if (mirror != null) {
        final slash = orientations?[mirrors.indexOf(mirror)] ?? mirror.initial;
        direction = _reflect(direction, slash);
      }
      switch (direction) {
        case BeamDirection.north:
          row--;
          break;
        case BeamDirection.east:
          column++;
          break;
        case BeamDirection.south:
          row++;
          break;
        case BeamDirection.west:
          column--;
          break;
      }
    }

    final last = points.last;
    switch (direction) {
      case BeamDirection.north:
        points.add(math.Point<double>(last.x, last.y - 0.5));
        break;
      case BeamDirection.east:
        points.add(math.Point<double>(last.x + 0.5, last.y));
        break;
      case BeamDirection.south:
        points.add(math.Point<double>(last.x, last.y + 0.5));
        break;
      case BeamDirection.west:
        points.add(math.Point<double>(last.x - 0.5, last.y));
        break;
    }

    final reachedExit = direction == exit && switch (exit) {
      BeamDirection.north => last.y == 0 && exitIndex == last.x.toInt(),
      BeamDirection.east => last.x == size - 1 && exitIndex == last.y.toInt(),
      BeamDirection.south => last.y == size - 1 && exitIndex == last.x.toInt(),
      BeamDirection.west => last.x == 0 && exitIndex == last.y.toInt(),
    };
    return RayResult(
      points: points,
      litCrystals: crystals.where(lit.contains).toSet(),
      solved: reachedExit && crystals.every(lit.contains),
    );
  }

  static BeamDirection _reflect(BeamDirection direction, bool slash) {
    if (slash) {
      return switch (direction) {
        BeamDirection.north => BeamDirection.east,
        BeamDirection.east => BeamDirection.north,
        BeamDirection.south => BeamDirection.west,
        BeamDirection.west => BeamDirection.south,
      };
    }
    return switch (direction) {
      BeamDirection.north => BeamDirection.west,
      BeamDirection.east => BeamDirection.south,
      BeamDirection.south => BeamDirection.east,
      BeamDirection.west => BeamDirection.north,
    };
  }
}

class RayResult {
  const RayResult({
    required this.points,
    required this.litCrystals,
    required this.solved,
  });

  final List<math.Point<double>> points;
  final Set<math.Point<int>> litCrystals;
  final bool solved;
}

const puzzleLevels = <PuzzleLevel>[
  PuzzleLevel(
    sourceRow: 5,
    exit: BeamDirection.east,
    exitIndex: 2,
    mirrors: [MirrorSpec(5, 2, true, false), MirrorSpec(2, 2, true, false)],
    crystals: [
      math.Point<int>(0, 5),
      math.Point<int>(1, 5),
      math.Point<int>(2, 4),
      math.Point<int>(4, 2),
      math.Point<int>(6, 2),
    ],
  ),
  PuzzleLevel(
    sourceRow: 1,
    exit: BeamDirection.east,
    exitIndex: 5,
    mirrors: [MirrorSpec(1, 2, false, true), MirrorSpec(5, 2, false, true)],
    crystals: [
      math.Point<int>(0, 1),
      math.Point<int>(1, 1),
      math.Point<int>(2, 2),
      math.Point<int>(2, 5),
      math.Point<int>(6, 5),
    ],
  ),
  PuzzleLevel(
    sourceRow: 5,
    exit: BeamDirection.north,
    exitIndex: 4,
    mirrors: [MirrorSpec(5, 4, true, false)],
    crystals: [
      math.Point<int>(0, 5),
      math.Point<int>(2, 5),
      math.Point<int>(4, 4),
      math.Point<int>(4, 1),
    ],
  ),
  PuzzleLevel(
    sourceRow: 3,
    exit: BeamDirection.west,
    exitIndex: 1,
    mirrors: [MirrorSpec(3, 3, true, false), MirrorSpec(1, 3, false, true)],
    crystals: [
      math.Point<int>(0, 3),
      math.Point<int>(3, 2),
      math.Point<int>(1, 1),
      math.Point<int>(2, 3),
    ],
  ),
];
