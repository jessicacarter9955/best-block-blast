import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'lumen_loom.dart';
import 'platform/playables.dart';

void main() => runApp(const LumenLoomApp());

class LumenLoomApp extends StatelessWidget {
  const LumenLoomApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Lumen Loom',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xff070a21),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xff63e7ff),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const LumenLoomScreen(),
      );
}

class LumenLoomScreen extends StatefulWidget {
  const LumenLoomScreen({super.key});

  @override
  State<LumenLoomScreen> createState() => _LumenLoomScreenState();
}

class _LumenLoomScreenState extends State<LumenLoomScreen>
    with WidgetsBindingObserver {
  static const _saveKey = 'lumen_loom_progress_v1';
  static const _cyan = Color(0xff56e8ff);
  static const _violet = Color(0xffb58aff);

  int _level = 0;
  int _bestLevel = 0;
  int _moves = 0;
  late List<bool> _orientations;
  bool _loaded = false;
  bool _paused = false;
  bool _savingAvailable = false;
  bool _rewardBusy = false;
  String _language = 'en';
  final Set<int> _shownMilestone = {};

  PuzzleLevel get _puzzle => puzzleLevels[_level % puzzleLevels.length];
  RayResult get _ray => _puzzle.trace({
        for (var i = 0; i < _orientations.length; i++) i: _orientations[i],
      });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _orientations = _puzzle.mirrors.map((mirror) => mirror.initial).toList();
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveProgress();
    }
  }

  Future<void> _initialize() async {
    bool platformReady = false;
    try {
      platformReady = await initYoutubePlayables();
      if (platformReady) _language = await youtubeLanguage();
    } catch (_) {}

    String? saved;
    if (platformReady) {
      saved = await loadBridgeSave()
          .timeout(const Duration(seconds: 6), onTimeout: () => null);
      _savingAvailable = saved != null;
    }
    try {
      if (saved == null) {
        final preferences = await SharedPreferences.getInstance();
        saved = preferences.getString(_saveKey);
      }
    } catch (_) {
      // Saving is optional; the puzzle remains playable if browser storage is off.
    }

    if (saved != null) {
      try {
        final data = jsonDecode(saved) as Map<String, dynamic>;
        _level = ((data['level'] as num?)?.toInt() ?? 0)
            .clamp(0, 999999)
            .toInt();
        _bestLevel = ((data['best'] as num?)?.toInt() ?? _level)
            .clamp(0, 999999)
            .toInt();
      } catch (_) {}
    }
    _orientations = _puzzle.mirrors.map((mirror) => mirror.initial).toList();
    if (!mounted) return;
    setState(() => _loaded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) sendGameReady();
    });
    listenToPlatform(
      onPause: (paused) {
        if (mounted) setState(() => _paused = paused);
      },
      onAudio: (_) {},
    );
  }

  Future<void> _saveProgress() async {
    final data = jsonEncode({'level': _level, 'best': _bestLevel});
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_saveKey, data);
    } catch (_) {}
    if (_savingAvailable) await saveBridgeData(data);
  }

  void _tapBoard(Offset local, Size size) {
    if (_paused || !_loaded || _ray.solved) return;
    final side = math.min(size.width, size.height).toDouble();
    final left = (size.width - side) / 2;
    final top = (size.height - side) / 2;
    final cell = side / PuzzleLevel.size;
    final column = ((local.dx - left) / cell).floor();
    final row = ((local.dy - top) / cell).floor();
    final index = _puzzle.mirrors.indexWhere(
      (mirror) => mirror.row == row && mirror.column == column,
    );
    if (index < 0) return;
    HapticFeedback.selectionClick();
    setState(() {
      _orientations[index] = !_orientations[index];
      _moves++;
    });
    if (_ray.solved) _completeLevel();
  }

  Future<void> _completeLevel() async {
    final completed = _level;
    _bestLevel = math.max(_bestLevel, completed + 1).toInt();
    await _saveProgress();
    if (mounted && (completed + 1) % 3 == 0 &&
        _shownMilestone.add(completed)) {
      await showInterstitialAd('level_complete');
    }
  }

  void _nextLevel() {
    setState(() {
      _level++;
      _moves = 0;
      _orientations = _puzzle.mirrors.map((mirror) => mirror.initial).toList();
    });
    _saveProgress();
  }

  Future<void> _hint() async {
    if (_rewardBusy || _ray.solved) return;
    setState(() => _rewardBusy = true);
    final outcome = await showRewardedAd('mirror_hint');
    if (mounted) {
      setState(() => _rewardBusy = false);
      if (outcome == AdOutcome.completed) {
        final movesToHint = _orientations
            .asMap()
            .entries
            .where((entry) => entry.value != _puzzle.mirrors[entry.key].solution)
            .length;
        setState(() {
          _orientations = _puzzle.mirrors.map((m) => m.solution).toList();
          _moves += movesToHint;
        });
        if (_ray.solved) _completeLevel();
      } else if (outcome == AdOutcome.unavailable) {
        _snack(_text('adsUnavailable'));
      }
    }
  }

  void _resetLevel() {
    setState(() {
      _moves = 0;
      _orientations = _puzzle.mirrors.map((mirror) => mirror.initial).toList();
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
  }

  String _text(String key) {
    const translations = <String, Map<String, String>>{
      'en': {
        'tagline': 'WEAVE LIGHT. FIND THE WAY.',
        'level': 'LEVEL',
        'moves': 'MOVES',
        'crystals': 'CRYSTALS',
        'instruction': 'Tap a mirror to turn it and guide the beam.',
        'hint': 'HINT',
        'reset': 'RESET',
        'next': 'NEXT LEVEL',
        'complete': 'BRILLIANT!',
        'completeBody': 'Every crystal found. The path is yours.',
        'paused': 'PAUSED',
        'resume': 'RESUME',
        'adsUnavailable': 'Hints are not available on this platform.',
        'hintLoading': 'LOADING…',
      },
      'it': {
        'tagline': 'INTRECCIA LA LUCE. TROVA LA VIA.',
        'level': 'LIVELLO',
        'moves': 'MOSSE',
        'crystals': 'CRISTALLI',
        'instruction': 'Tocca uno specchio per ruotarlo e guidare il raggio.',
        'hint': 'AIUTO',
        'reset': 'RIPETI',
        'next': 'PROSSIMO',
        'complete': 'FANTASTICO!',
        'completeBody': 'Hai raccolto tutti i cristalli.',
        'paused': 'IN PAUSA',
        'resume': 'RIPRENDI',
        'adsUnavailable': 'Gli aiuti non sono disponibili su questa piattaforma.',
        'hintLoading': 'CARICAMENTO…',
      },
      'ru': {
        'tagline': 'СОЕДИНИ СВЕТ. НАЙДИ ПУТЬ.',
        'level': 'УРОВЕНЬ',
        'moves': 'ХОДЫ',
        'crystals': 'КРИСТАЛЛЫ',
        'instruction': 'Нажми на зеркало, чтобы повернуть луч.',
        'hint': 'ПОДСКАЗКА',
        'reset': 'СБРОС',
        'next': 'ДАЛЕЕ',
        'complete': 'ПРЕКРАСНО!',
        'completeBody': 'Все кристаллы собраны.',
        'paused': 'ПАУЗА',
        'resume': 'ПРОДОЛЖИТЬ',
        'adsUnavailable': 'Подсказки недоступны на этой платформе.',
        'hintLoading': 'ЗАГРУЗКА…',
      },
    };
    final language = translations.containsKey(_language) ? _language : 'en';
    return translations[language]![key] ?? translations['en']![key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const _LoadingScreen();
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        final landscape = constraints.maxWidth > constraints.maxHeight * 1.05;
        return Stack(children: [
          const Positioned.fill(child: _Starfield()),
          SafeArea(
            child: landscape
                ? _buildLandscape(constraints)
                : _buildPortrait(constraints),
          ),
          if (_paused) _buildPauseOverlay(),
          if (_ray.solved && !_paused) _buildSolvedOverlay(),
        ]);
      }),
    );
  }

  Widget _buildPortrait(BoxConstraints constraints) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Column(children: [
          _header(),
          const SizedBox(height: 8),
          _statsRow(),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: _board(),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(_text('instruction'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(.69), fontSize: 12)),
          const SizedBox(height: 10),
          _buttons(compact: constraints.maxWidth < 370),
        ]),
      );

  Widget _buildLandscape(BoxConstraints constraints) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
        child: Row(children: [
          Expanded(
            flex: 7,
            child: Center(
              child: AspectRatio(aspectRatio: 1, child: _board()),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(compact: true),
                const SizedBox(height: 20),
                _statsRow(),
                const SizedBox(height: 18),
                Text(_text('instruction'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(.7), fontSize: 13)),
                const SizedBox(height: 20),
                _buttons(compact: false),
              ],
            ),
          ),
        ]),
      );

  Widget _header({bool compact = false}) => Row(
        children: [
          Container(
            width: compact ? 42 : 46,
            height: compact ? 42 : 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: const LinearGradient(colors: [_cyan, _violet]),
              boxShadow: [BoxShadow(color: _cyan.withOpacity(.25), blurRadius: 22)],
            ),
            child: const Icon(Icons.auto_awesome, color: Color(0xff11142f)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('LUMEN LOOM',
                  style: TextStyle(fontSize: compact ? 18 : 20,
                      fontWeight: FontWeight.w900, letterSpacing: 1.1)),
              Text(_text('tagline'),
                  style: TextStyle(fontSize: 9, color: _cyan.withOpacity(.8),
                      fontWeight: FontWeight.w700, letterSpacing: 1.4)),
            ]),
          ),
          _roundButton(Icons.pause_rounded, () {
            setState(() => _paused = true);
          }),
        ],
      );

  Widget _statsRow() => Row(children: [
        _stat(_text('level'), '${_level + 1}', _violet),
        const SizedBox(width: 8),
        _stat(_text('moves'), '$_moves', _cyan),
        const SizedBox(width: 8),
        _stat(_text('crystals'), '${_ray.litCrystals.length}/${_puzzle.crystals.length}',
            const Color(0xffffcf68)),
      ]);

  Widget _stat(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xff111735).withOpacity(.86),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withOpacity(.27)),
          ),
          child: Column(children: [
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: color)),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 8, letterSpacing: .8,
                    fontWeight: FontWeight.w700, color: Colors.white.withOpacity(.65))),
          ]),
        ),
      );

  Widget _board() => LayoutBuilder(builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => _tapBoard(details.localPosition, size),
          child: CustomPaint(
            size: size,
            painter: _BoardPainter(
              puzzle: _puzzle,
              orientations: _orientations,
              ray: _ray,
              cyan: _cyan,
              violet: _violet,
            ),
          ),
        );
      });

  Widget _buttons({required bool compact}) => Row(children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.refresh_rounded,
            label: _text('reset'),
            onPressed: _resetLevel,
            muted: true,
            compact: compact,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            icon: _rewardBusy ? Icons.hourglass_top_rounded : Icons.auto_awesome,
            label: _rewardBusy ? _text('hintLoading') : _text('hint'),
            onPressed: _hint,
            compact: compact,
          ),
        ),
      ]);

  Widget _roundButton(IconData icon, VoidCallback onPressed) => InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xff111735),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(.1)),
          ),
          child: Icon(icon, color: Colors.white.withOpacity(.9)),
        ),
      );

  Widget _buildPauseOverlay() => Positioned.fill(
        child: ColoredBox(
          color: const Color(0xdd06091e),
          child: Center(
            child: Container(
              width: 300,
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: const Color(0xff111735),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _violet.withOpacity(.6)),
                boxShadow: [BoxShadow(color: _violet.withOpacity(.16), blurRadius: 38)],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.pause_circle_filled_rounded, size: 56, color: _violet),
                const SizedBox(height: 8),
                Text(_text('paused'), style: const TextStyle(
                    fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 18),
                _ActionButton(
                  icon: Icons.play_arrow_rounded,
                  label: _text('resume'),
                  onPressed: () => setState(() => _paused = false),
                ),
              ]),
            ),
          ),
        ),
      );

  Widget _buildSolvedOverlay() => Positioned.fill(
        child: ColoredBox(
          color: const Color(0xbb06091e),
          child: Center(
            child: Container(
              width: 310,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: const Color(0xff111735),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _cyan.withOpacity(.63)),
                boxShadow: [BoxShadow(color: _cyan.withOpacity(.2), blurRadius: 42)],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.auto_awesome_rounded, size: 54, color: Color(0xffffd36f)),
                const SizedBox(height: 9),
                Text(_text('complete'), style: const TextStyle(
                    fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 7),
                Text(_text('completeBody'), textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(.72))),
                const SizedBox(height: 19),
                _ActionButton(
                  icon: Icons.arrow_forward_rounded,
                  label: _text('next'),
                  onPressed: _nextLevel,
                ),
              ]),
            ),
          ),
        ),
      );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.muted = false,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool muted;
  final bool compact;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            height: compact ? 46 : 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: muted ? const Color(0xff121a3b) : null,
              gradient: muted
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xff61e9ff), Color(0xffad83ff)]),
              border: Border.all(
                  color: muted ? Colors.white.withOpacity(.13) : Colors.white.withOpacity(.3)),
              boxShadow: muted
                  ? null
                  : [BoxShadow(color: const Color(0xff8a8dff).withOpacity(.22), blurRadius: 18)],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: compact ? 17 : 19,
                  color: muted ? Colors.white70 : const Color(0xff10132f)),
              const SizedBox(width: 7),
              Flexible(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: compact ? 11 : 13,
                        fontWeight: FontWeight.w900, letterSpacing: .6,
                        color: muted ? Colors.white : const Color(0xff10132f))),
              ),
            ]),
          ),
        ),
      );
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xff56e8ff))),
      );
}

class _Starfield extends StatelessWidget {
  const _Starfield();

  @override
  Widget build(BuildContext context) => CustomPaint(
        foregroundPainter: _StarfieldPainter(),
        child: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-.7, -.7),
              radius: 1.35,
              colors: [Color(0xff1a2450), Color(0xff070a21), Color(0xff070a21)],
            ),
          ),
        ),
      );
}

class _StarfieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(81);
    final paint = Paint();
    for (var i = 0; i < 75; i++) {
      paint.color = const Color(0xffa7c9ff).withOpacity(.12 + random.nextDouble() * .4);
      final point = Offset(random.nextDouble() * size.width, random.nextDouble() * size.height);
      canvas.drawCircle(point, .5 + random.nextDouble() * 1.1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.puzzle,
    required this.orientations,
    required this.ray,
    required this.cyan,
    required this.violet,
  });

  final PuzzleLevel puzzle;
  final List<bool> orientations;
  final RayResult ray;
  final Color cyan;
  final Color violet;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height).toDouble();
    final origin = Offset((size.width - side) / 2, (size.height - side) / 2);
    final cell = side / PuzzleLevel.size;
    final board = Rect.fromLTWH(origin.dx, origin.dy, side, side);
    final rrect = RRect.fromRectAndRadius(board, Radius.circular(cell * .26));
    canvas.drawRRect(rrect, Paint()..color = const Color(0xff0a102d).withOpacity(.92));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = cyan.withOpacity(.4),
    );

    final gridPaint = Paint()
      ..color = const Color(0xff8a9acb).withOpacity(.13)
      ..strokeWidth = 1;
    for (var i = 1; i < PuzzleLevel.size; i++) {
      final p = origin.dx + cell * i;
      canvas.drawLine(Offset(p, origin.dy + cell * .08),
          Offset(p, origin.dy + side - cell * .08), gridPaint);
      final q = origin.dy + cell * i;
      canvas.drawLine(Offset(origin.dx + cell * .08, q),
          Offset(origin.dx + side - cell * .08, q), gridPaint);
    }

    for (final crystal in puzzle.crystals) {
      final center = _center(crystal.x, crystal.y, cell, origin);
      final active = ray.litCrystals.contains(crystal);
      final path = Path()
        ..moveTo(center.dx, center.dy - cell * .19)
        ..lineTo(center.dx + cell * .13, center.dy)
        ..lineTo(center.dx, center.dy + cell * .19)
        ..lineTo(center.dx - cell * .13, center.dy)
        ..close();
      if (active) {
        canvas.drawCircle(center, cell * .28,
            Paint()..color = const Color(0xffffd36f).withOpacity(.18));
      }
      canvas.drawPath(path, Paint()
        ..color = active ? const Color(0xffffdb7a) : const Color(0xff647091)
        ..style = active ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 1.6);
      if (active) {
        canvas.drawCircle(center, cell * .065, Paint()..color = Colors.white);
      }
    }

    final beamPath = Path();
    for (var i = 0; i < ray.points.length; i++) {
      final point = ray.points[i];
      final offset = Offset(origin.dx + (point.x + .5) * cell,
          origin.dy + (point.y + .5) * cell);
      if (i == 0) {
        beamPath.moveTo(offset.dx, offset.dy);
      } else {
        beamPath.lineTo(offset.dx, offset.dy);
      }
    }
    canvas.drawPath(
      beamPath,
      Paint()
        ..color = cyan.withOpacity(.17)
        ..strokeWidth = cell * .3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawPath(
      beamPath,
      Paint()
        ..color = cyan.withOpacity(.9)
        ..strokeWidth = cell * .055
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    final source = _center(0, puzzle.sourceRow, cell, origin);
    canvas.drawCircle(source, cell * .21, Paint()..color = const Color(0xfff5fcff));
    canvas.drawCircle(source, cell * .36,
        Paint()..color = cyan.withOpacity(.22));
    for (var i = 0; i < puzzle.mirrors.length; i++) {
      final mirror = puzzle.mirrors[i];
      final rect = Rect.fromLTWH(origin.dx + mirror.column * cell + cell * .13,
          origin.dy + mirror.row * cell + cell * .13, cell * .74, cell * .74);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(cell * .2));
      final active = orientations[i] == mirror.solution;
      final color = active ? cyan : violet;
      canvas.drawRRect(rr, Paint()..color = color.withOpacity(.15));
      canvas.drawRRect(rr, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = color.withOpacity(.78));
      final slash = orientations[i];
      final mirrorLine = Path()
        ..moveTo(rect.left + cell * .16, slash ? rect.bottom - cell * .14 : rect.top + cell * .14)
        ..lineTo(rect.right - cell * .16, slash ? rect.top + cell * .14 : rect.bottom - cell * .14);
      canvas.drawPath(mirrorLine, Paint()
        ..color = color
        ..strokeWidth = cell * .075
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * .025));
      canvas.drawPath(mirrorLine, Paint()
        ..color = Colors.white.withOpacity(.95)
        ..strokeWidth = cell * .026
        ..strokeCap = StrokeCap.round);
    }
  }

  Offset _center(int column, int row, double cell, Offset origin) =>
      Offset(origin.dx + (column + .5) * cell, origin.dy + (row + .5) * cell);

  @override
  bool shouldRepaint(covariant _BoardPainter oldDelegate) =>
      oldDelegate.puzzle != puzzle ||
      oldDelegate.ray != ray ||
      !listEquals(oldDelegate.orientations, orientations);
}
