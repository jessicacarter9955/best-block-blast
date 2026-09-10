import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/block_blast_game.dart';
import 'game/palette.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
          seedColor: BlockPalette.blocks[1].base, // brown
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
  int _score = 0;
  bool _gameOver = false;
  int _finalScore = 0;

  @override
  void initState() {
    super.initState();
    _game = BlockBlastGame();
    _game.onScoreChanged = (s) => setState(() => _score = s);
    _game.onGameOverChanged = (over, finalScore) {
      setState(() {
        _gameOver = over;
        _finalScore = finalScore;
      });
    };
  }

  @override
  void dispose() {
    _game.onScoreChanged = null;
    _game.onGameOverChanged = null;
    _game.dispose();
    super.dispose();
  }

  void _restart() {
    _game.restart();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlockPalette.bg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The Flame game canvas.
            GameWidget(game: _game),

            // Header overlay (CHOCO BLOCK title + score box).
            Positioned(
              top: 14,
              left: 16,
              right: 16,
              child: _Header(score: _score),
            ),

            // Footer hint.
            Positioned(
              bottom: 14,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Drag pieces onto the grid · clear rows and columns to score',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: BlockPalette.textMuted,
                    fontSize: 12,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),

            // Game-over overlay.
            if (_gameOver)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _restart,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    color: BlockPalette.bg.withOpacity(0.85),
                    alignment: Alignment.center,
                    child: _GameOverCard(finalScore: _finalScore, onRestart: _restart),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int score;
  const _Header({required this.score});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Title
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'CHOCO ',
                style: TextStyle(
                  color: BlockPalette.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
              TextSpan(
                text: 'BLOCK',
                style: TextStyle(
                  color: BlockPalette.blocks[0].base, // gold
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // Score box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: BlockPalette.gridCell.withOpacity(0.55),
            border: Border.all(color: BlockPalette.gridBorder, width: 1.4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SCORE',
                style: TextStyle(
                  color: BlockPalette.textMuted,
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$score',
                style: TextStyle(
                  color: BlockPalette.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GameOverCard extends StatelessWidget {
  final int finalScore;
  final VoidCallback onRestart;
  const _GameOverCard({required this.finalScore, required this.onRestart});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: BlockPalette.bg,
        border: Border.all(color: BlockPalette.gridBorder, width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Game Over',
            style: TextStyle(
              color: BlockPalette.blocks[0].base, // gold
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Final score: $finalScore',
            style: TextStyle(
              color: BlockPalette.text,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onRestart,
            style: FilledButton.styleFrom(
              backgroundColor: BlockPalette.blocks[0].base, // gold
              foregroundColor: BlockPalette.bg,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Play again',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'or tap anywhere',
            style: TextStyle(
              color: BlockPalette.textMuted,
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
