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
          seedColor: BlockPalette.blockColors[1], // brown
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
  int _bestScore = 0;
  bool _gameOver = false;
  bool _paused = false;
  bool _musicOn = true;
  bool _sfxOn = true;

  @override
  void initState() {
    super.initState();
    _game = BlockBlastGame();
    _game.onScoreChanged = (score, best) {
      if (mounted) setState(() { _score = score; _bestScore = best; });
    };
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
    _game.onScoreChanged = null;
    _game.onGameOverChanged = null;
    _game.onPausedChanged = null;
    _game.onAudioTogglesChanged = null;
    _game.dispose();
    super.dispose();
  }

  void _restart() {
    _game.restart();
  }

  void _togglePause() {
    _game.togglePause();
  }

  void _toggleMusic() {
    _game.toggleMusic();
  }

  void _toggleSfx() {
    _game.toggleSfx();
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

            // Header: title + score panel + buttons
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: _Header(
                score: _score,
                bestScore: _bestScore,
                paused: _paused,
                musicOn: _musicOn,
                sfxOn: _sfxOn,
                onTogglePause: _togglePause,
                onToggleMusic: _toggleMusic,
                onToggleSfx: _toggleSfx,
              ),
            ),

            // Footer hint
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Drag pieces onto the grid · clear rows and columns to score',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: BlockPalette.textMuted,
                    fontSize: 11,
                    letterSpacing: 0.4,
                  ),
                ),
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
                      finalScore: _score,
                      bestScore: _bestScore,
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

// =============================================================================
// Header (title + score panel + pause/music/sfx buttons)
// =============================================================================

class _Header extends StatelessWidget {
  final int score;
  final int bestScore;
  final bool paused;
  final bool musicOn;
  final bool sfxOn;
  final VoidCallback onTogglePause;
  final VoidCallback onToggleMusic;
  final VoidCallback onToggleSfx;

  const _Header({
    required this.score,
    required this.bestScore,
    required this.paused,
    required this.musicOn,
    required this.sfxOn,
    required this.onTogglePause,
    required this.onToggleMusic,
    required this.onToggleSfx,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Title
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'BLOCK',
                    style: TextStyle(
                      color: BlockPalette.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: 'BLAST',
                    style: TextStyle(
                      color: BlockPalette.blockColors[2], // gold
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'BEST: $bestScore',
              style: TextStyle(
                color: BlockPalette.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const Spacer(),
        // Score pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: BlockPalette.gridCell.withOpacity(0.55),
            border: Border.all(color: BlockPalette.gridBorder, width: 1.4),
            borderRadius: BorderRadius.circular(10),
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
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '$score',
                style: TextStyle(
                  color: BlockPalette.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Buttons
        _IconBtn(
          icon: paused ? Icons.play_arrow : Icons.pause,
          onTap: onTogglePause,
        ),
        _IconBtn(
          icon: musicOn ? Icons.music_note : Icons.music_off,
          onTap: onToggleMusic,
        ),
        _IconBtn(
          icon: sfxOn ? Icons.volume_up : Icons.volume_mute,
          onTap: onToggleSfx,
        ),
      ],
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

// =============================================================================
// Pause overlay
// =============================================================================

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
          Text(
            'Paused',
            style: TextStyle(
              color: BlockPalette.blockColors[2], // gold
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
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
          TextButton(
            onPressed: onRestart,
            child: Text(
              'Restart game',
              style: TextStyle(color: BlockPalette.textMuted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'or tap anywhere',
            style: TextStyle(color: BlockPalette.textMuted, fontSize: 10, letterSpacing: 0.4),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Game over overlay
// =============================================================================

class _GameOverCard extends StatelessWidget {
  final int finalScore;
  final int bestScore;
  final VoidCallback onRestart;
  const _GameOverCard({
    required this.finalScore,
    required this.bestScore,
    required this.onRestart,
  });

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
          Text(
            'GAME OVER',
            style: TextStyle(
              color: BlockPalette.blockColors[2], // gold
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('SCORE', style: TextStyle(color: BlockPalette.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.0)),
                  const SizedBox(height: 4),
                  Text('$finalScore', style: TextStyle(color: BlockPalette.text, fontSize: 26, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(width: 24),
              Container(
                width: 1, height: 40,
                color: BlockPalette.gridBorder.withOpacity(0.6),
              ),
              const SizedBox(width: 24),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('BEST', style: TextStyle(color: BlockPalette.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.0)),
                  const SizedBox(height: 4),
                  Text('$bestScore', style: TextStyle(color: BlockPalette.blockColors[2], fontSize: 26, fontWeight: FontWeight.w800)),
                ],
              ),
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
          Text(
            'or tap anywhere',
            style: TextStyle(color: BlockPalette.textMuted, fontSize: 10, letterSpacing: 0.4),
          ),
        ],
      ),
    );
  }
}
