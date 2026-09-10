import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// ChocoBlock — Flutter app that loads the original Construct 3 Block
/// Blast game (with chocolate-recolor applied to the block sprites) in
/// a fullscreen WebView. All game logic, audio, animations, UI, and
/// gameplay are the original game's — we just wrap it natively for
/// Android so it can be published to the Play Store.
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

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final WebViewController _controller;
  bool _loaded = false;
  bool _errored = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0A1119))
      ..enableZoom(false)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => setState(() => _loaded = true),
          onWebResourceError: (e) {
            if (mounted) setState(() => _errored = true);
          },
        ),
      )
      ..loadFlutterAsset('assets/game/index.html');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1119),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            WebViewWidget(controller: _controller),
            if (!_loaded)
              Container(
                color: const Color(0xFF0A1119),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/game/icons/icon-256.png',
                        width: 96,
                        height: 96,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'ChocoBlock',
                        style: TextStyle(
                          color: Color(0xFFFAB82A),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Color(0xFF3E559F),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_errored && !_loaded)
              Container(
                color: const Color(0xFF0A1119),
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFC93131),
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Failed to load the game',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () {
                          setState(() => _errored = false);
                          _controller.reload();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
