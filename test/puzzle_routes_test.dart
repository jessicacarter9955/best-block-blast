import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_loom/lumen_loom.dart';

void main() {
  group('authored light routes', () {
    for (var index = 0; index < puzzleLevels.length; index++) {
      final level = puzzleLevels[index];
      test('level ${index + 1} has a reachable exit and every crystal', () {
        final solution = <int, bool>{
          for (var i = 0; i < level.mirrors.length; i++)
            i: level.mirrors[i].solution,
        };

        final result = level.trace(solution);

        expect(result.solved, isTrue);
        expect(result.litCrystals, hasLength(level.crystals.length));
        expect(level.trace().solved, isFalse,
            reason: 'the opening mirror layout should need player input');
      });
    }

    test('a single mirror turn solves the one-mirror route', () {
      final level = puzzleLevels[2];
      final result = level.trace({0: level.mirrors.single.solution});

      expect(result.solved, isTrue);
    });
  });
}
