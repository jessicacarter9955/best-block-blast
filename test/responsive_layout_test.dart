import 'package:block_rush/game/block_blast_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('responsive layout selects a playable composition by available aspect',
      () {
    expect(BlockBlastGame.usesLandscapeLayout(390, 844), isFalse);
    expect(BlockBlastGame.usesLandscapeLayout(768, 1024), isFalse);
    expect(BlockBlastGame.usesLandscapeLayout(1024, 768), isTrue);
    expect(BlockBlastGame.usesLandscapeLayout(1080, 1080), isTrue);
  });
}
