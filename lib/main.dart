import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/block_blast_game.dart';
import 'game/palette.dart';

void main() {
  runApp(const BlockRushApp());
}

class BlockRushApp extends StatelessWidget {
  const BlockRushApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Block Rush',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Letterbox fill matching the original background gradient tone.
      backgroundColor: BlockPalette.bg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: GameWidget(game: _game),
      ),
    );
  }
}
