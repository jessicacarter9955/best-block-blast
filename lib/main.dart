import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/block_blast_game.dart';
import 'game/palette.dart';
import 'game/responsive_frame.dart';

void main() {
  runApp(const ChocoBlockApp());
}

class ChocoBlockApp extends StatelessWidget {
  const ChocoBlockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Block Blast',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: BlockPalette.blockColors[3],
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final BlockBlastGame _game = BlockBlastGame();
  late final Timer _sceneRefresh;
  bool _homeScene = true;

  @override
  void initState() {
    super.initState();
    // Only rebuild the static outer artwork when the game changes scenes.
    // The Flame canvas itself continues to render on its own frame schedule.
    _sceneRefresh = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      final home = _game.state == GameState.home;
      if (home != _homeScene) setState(() => _homeScene = home);
    });
  }

  @override
  void dispose() {
    _sceneRefresh.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fallback while the single full-bleed wallpaper decodes.
      backgroundColor: BlockPalette.bg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(builder: (context, constraints) {
          final plan = ResponsiveGameFrame.forSize(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            home: _homeScene,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              // The wallpaper is the sole scene background. Flame draws only
              // gameplay and UI on top with a transparent canvas, so no
              // duplicated image edges appear above/below the 9:16 viewport
              // on taller phones or beside it on wider displays.
              Image.asset(
                plan.backgroundAsset,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                filterQuality: FilterQuality.medium,
              ),
              Positioned(
                left: plan.gameLeft,
                top: plan.gameTop,
                width: plan.gameWidth,
                height: plan.gameHeight,
                // Flame receives its own unmodified logical viewport so
                // drag distances and hitboxes remain pixel-accurate.
                child: ClipRect(child: GameWidget(game: _game)),
              ),
            ],
          );
        }),
      ),
    );
  }
}
