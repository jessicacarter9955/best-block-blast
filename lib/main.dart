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
      backgroundColor: BlockPalette.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: _ResponsiveBackdrop())),
          ),
          SafeArea(child: GameWidget(game: _game)),
        ],
      ),
    );
  }
}

/// Soft jewel-toned color fills the space outside Flame's aspect-preserving
/// game viewport on ultrawide, tall, and tablet-sized screens.
class _ResponsiveBackdrop extends CustomPainter {
  const _ResponsiveBackdrop();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF080D35), Color(0xFF10105A), Color(0xFF080D35)],
        ).createShader(bounds),
    );

    void glow(Offset center, double radius, Color color) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withAlpha(0)],
          ).createShader(rect),
      );
    }

    final span = size.shortestSide;
    glow(Offset(size.width * 0.08, size.height * 0.12), span * 0.68,
        const Color(0x384D3CEB));
    glow(Offset(size.width * 0.94, size.height * 0.9), span * 0.72,
        const Color(0x2D0BBDEB));
    glow(Offset(size.width * 0.52, size.height * 0.48), span * 0.52,
        const Color(0x1D9C30F6));
  }

  @override
  bool shouldRepaint(covariant _ResponsiveBackdrop oldDelegate) => false;
}
