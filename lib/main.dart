import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/block_blast_game.dart';

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
          seedColor: const Color(0xFF9B5738),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A1119),
      body: GameWidget.controlled(
        gameFactory: BlockBlastGame.new,
      ),
    );
  }
}
