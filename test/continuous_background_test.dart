import 'package:block_rush/game/block_blast_game.dart';
import 'package:block_rush/game/responsive_frame.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('OnePlus 8 letterbox stays transparent over one continuous wallpaper',
      () {
    // The screenshots show a 20:9 phone: a 9:16 interactive viewport must
    // leave top/bottom margins without rendering a second wallpaper there.
    final frame = ResponsiveGameFrame.forSize(
      width: 360,
      height: 800,
      devicePixelRatio: 3,
    );
    expect(frame.gameTop, greaterThan(0));
    expect(frame.gameTop + frame.gameHeight, lessThan(frame.height));

    // Flame's transparent canvas lets the full-screen Flutter artwork show
    // through both the home view and the tutorial/gameplay view.
    final game = BlockBlastGame();
    expect(game.backgroundColor().alpha, 0);
    game.state = GameState.hud;
    expect(game.backgroundColor().alpha, 0);
    game.state = GameState.home;
    expect(game.backgroundColor().alpha, 0);
  });

  test('home and tutorial/gameplay each select one full-bleed scene asset',
      () {
    for (final size in [
      (360.0, 800.0), // OnePlus 8 / 20:9
      (390.0, 844.0), // tall iPhone
      (1080.0, 1920.0), // original 9:16
      (1920.0, 1080.0), // landscape
    ]) {
      final home = ResponsiveGameFrame.forSize(
        width: size.$1,
        height: size.$2,
        home: true,
      );
      final gameplay = ResponsiveGameFrame.forSize(
        width: size.$1,
        height: size.$2,
        home: false,
      );
      expect(home.backgroundAsset, contains('/home-'));
      expect(gameplay.backgroundAsset, contains('/game-'));
      expect(home.gameLeft, gameplay.gameLeft);
      expect(home.gameTop, gameplay.gameTop);
    }
  });
}
