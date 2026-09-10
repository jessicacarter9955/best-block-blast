import 'package:flame_audio/flame_audio.dart';

/// Audio manager for Block Blast. Wraps FlameAudio with safe try/catch
/// so audio failures never crash the game. Provides:
///   - Background music loop (music.mp3)
///   - SFX for placement, line clear, game over
///   - Mute toggles for music and SFX
class GameAudio {
  bool _musicOn = true;
  bool _sfxOn = true;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await FlameAudio.audioCache.loadAll([
        'put.mp3', 'score.mp3', 'lose.mp3', 'whoosh.mp3',
        'beep.mp3', 'revive.mp3', 'return.mp3', 'no_space.mp3',
        'music.mp3',
      ]);
    } catch (_) {
      // Audio is best-effort.
    }
  }

  void startMusic() {
    if (!_musicOn) return;
    try {
      FlameAudio.bgm.initialize();
      FlameAudio.bgm.play('music.mp3', volume: 0.4);
    } catch (_) {}
  }

  void stopMusic() {
    try {
      FlameAudio.bgm.stop();
    } catch (_) {}
  }

  void pauseMusic() {
    try {
      FlameAudio.bgm.pause();
    } catch (_) {}
  }

  void resumeMusic() {
    if (!_musicOn) return;
    try {
      FlameAudio.bgm.resume();
    } catch (_) {}
  }

  void sfxPut() {
    if (!_sfxOn) return;
    try { FlameAudio.play('put.mp3', volume: 0.45); } catch (_) {}
  }

  void sfxScore() {
    if (!_sfxOn) return;
    try { FlameAudio.play('score.mp3', volume: 0.55); } catch (_) {}
  }

  void sfxLose() {
    if (!_sfxOn) return;
    try { FlameAudio.play('lose.mp3', volume: 0.65); } catch (_) {}
  }

  void sfxWhoosh() {
    if (!_sfxOn) return;
    try { FlameAudio.play('whoosh.mp3', volume: 0.35); } catch (_) {}
  }

  void sfxBeep() {
    if (!_sfxOn) return;
    try { FlameAudio.play('beep.mp3', volume: 0.4); } catch (_) {}
  }

  bool get musicOn => _musicOn;
  bool get sfxOn => _sfxOn;

  void toggleMusic() {
    _musicOn = !_musicOn;
    if (_musicOn) {
      startMusic();
    } else {
      stopMusic();
    }
  }

  void toggleSfx() {
    _sfxOn = !_sfxOn;
  }
}
