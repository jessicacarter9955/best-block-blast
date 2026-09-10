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
  bool _gameOver = false;
  bool _paused = false;
  bool _musicOn = true;
  bool _sfxOn = true;

  @override
  void initState() {
    super.initState();
    _game = BlockBlastGame();
    _game.onGameOverChanged = (over) {
      if (mounted) setState(() => _gameOver = over);
    };
    _game.onPausedChanged = (paused) {
      if (mounted) setState(() => _paused = paused);
    };
    _game.onAudioTogglesChanged = (m, s) {
      if (mounted) setState(() { _musicOn = m; _sfxOn = s; });
    };
  }

  @override
  void dispose() {
    _game.onGameOverChanged = null;
    _game.onPausedChanged = null;
    _game.onAudioTogglesChanged = null;
    _game.dispose();
    super.dispose();
  }

  void _restart() => _game.restart();
  void _togglePause() => _game.togglePause();
  void _toggleMusic() => _game.toggleMusic();
  void _toggleSfx() => _game.toggleSfx();

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
            GameWidget(game: _game),

            // Top-right buttons only (score panel is rendered in Flame)
            Positioned(
              top: 12,
              right: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IconBtn(icon: _paused ? Icons.play_arrow : Icons.pause, onTap: _togglePause),
                  const SizedBox(width: 6),
                  _IconBtn(icon: _musicOn ? Icons.music_note : Icons.music_off, onTap: _toggleMusic),
                  const SizedBox(width: 6),
                  _IconBtn(icon: _sfxOn ? Icons.volume_up : Icons.volume_mute, onTap: _toggleSfx),
                ],
              ),
            ),

            // Pause overlay
            if (_paused && !_gameOver)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _togglePause,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    color: BlockPalette.bg.withOpacity(0.85),
                    alignment: Alignment.center,
                    child: _PauseCard(onResume: _togglePause, onRestart: _restart),
                  ),
                ),
              ),

            // Game over overlay
            if (_gameOver)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _restart,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    color: BlockPalette.bg.withOpacity(0.92),
                    alignment: Alignment.center,
                    child: _GameOverCard(
                      finalScore: _game.score,
                      bestScore: _game.bestScore,
                      onRestart: _restart,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BlockPalette.gridCell.withOpacity(0.55),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: BlockPalette.gridBorder, width: 1.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: BlockPalette.text, size: 18),
        ),
      ),
    );
  }
}

class _PauseCard extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onRestart;
  const _PauseCard({required this.onResume, required this.onRestart});

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
          Text('Paused', style: TextStyle(color: BlockPalette.blockColors[2], fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onResume,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Resume', style: TextStyle(fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(
              backgroundColor: BlockPalette.blockColors[2],
              foregroundColor: BlockPalette.bg,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: onRestart, child: Text('Restart game', style: TextStyle(color: BlockPalette.textMuted, fontSize: 12))),
          const SizedBox(height: 8),
          Text('or tap anywhere', style: TextStyle(color: BlockPalette.textMuted, fontSize: 10, letterSpacing: 0.4)),
        ],
      ),
    );
  }
}

class _GameOverCard extends StatelessWidget {
  final int finalScore;
  final int bestScore;
  final VoidCallback onRestart;
  const _GameOverCard({required this.finalScore, required this.bestScore, required this.onRestart});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
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
          Text('GAME OVER', style: TextStyle(color: BlockPalette.blockColors[2], fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 1.6)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('SCORE', style: TextStyle(color: BlockPalette.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.0)),
                const SizedBox(height: 4),
                Text('$finalScore', style: TextStyle(color: BlockPalette.text, fontSize: 26, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(width: 24),
              Container(width: 1, height: 40, color: BlockPalette.gridBorder.withOpacity(0.6)),
              const SizedBox(width: 24),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('BEST', style: TextStyle(color: BlockPalette.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.0)),
                const SizedBox(height: 4),
                Text('$bestScore', style: TextStyle(color: BlockPalette.blockColors[2], fontSize: 26, fontWeight: FontWeight.w800)),
              ]),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRestart,
            icon: const Icon(Icons.refresh),
            label: const Text('Play again', style: TextStyle(fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(
              backgroundColor: BlockPalette.blockColors[2],
              foregroundColor: BlockPalette.bg,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 8),
          Text('or tap anywhere', style: TextStyle(color: BlockPalette.textMuted, fontSize: 10, letterSpacing: 0.4)),
        ],
      ),
    );
  }
}
