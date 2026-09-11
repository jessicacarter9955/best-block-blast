import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/block_blast_game.dart';
import 'game/palette.dart';

void main() {
  runApp(const ChocoBlockApp());
}

class ChocoBlockApp extends StatelessWidget {
  const ChocoBlockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChocoBlock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: BlockPalette.blockColors[1],
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
  late final BlockBlastGame _game;

  @override
  void initState() {
    super.initState();
    _game = BlockBlastGame();
  }

  @override
  void dispose() {
    _game.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlockPalette.bg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: GameWidget(game: _game),
      ),
    );
  }
}
