import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'playgama_ads.dart';

/// Persistence layer — 1:1 equivalent of the original game's LocalStorage
/// usage. The original stores a single JSON item under the key
/// `"Block Blast_Data"` with the fields `{SFX, Music, BestScore, Tut}`.
///
/// - SFX / Music: 1 = on, 0 = off (saved live when toggled)
/// - BestScore:   saved live during play (whenever Score > BestScore)
/// - Tut:         1 = tutorial not yet completed, 0 = completed
class GameStorage {
  GameStorage();

  static const String storageKey = 'Block Blast_Data';

  int sfx = 1;
  int music = 1;
  int bestScore = 0;
  int tut = 1;

  bool get sfxOn => sfx == 1;
  bool get musicOn => music == 1;

  /// Loads the stored data; if missing, applies the original defaults
  /// (SFX=1, Music=1, BestScore=0, Tut=1) and persists them.
  Future<void> load() async {
    if (isYoutubePlayablesBuild || isPlaygamaPlatform) {
      final raw = await loadBridgeSave();
      if (raw != null && raw.isNotEmpty) {
        try {
          _apply(jsonDecode(raw) as Map<String, dynamic>);
          return;
        } catch (_) {}
      }
      sfx = 1;
      music = 1;
      bestScore = 0;
      tut = 1;
      await _save();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      sfx = 1;
      music = 1;
      bestScore = 0;
      tut = 1;
      await _save();
      return;
    }
    try {
      _apply(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      sfx = 1;
      music = 1;
      bestScore = 0;
      tut = 1;
    }
  }

  Future<void> _save() async {
    final encoded = jsonEncode(toJson());
    if (isYoutubePlayablesBuild || isPlaygamaPlatform) {
      await saveBridgeData(encoded);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, encoded);
  }

  Future<void> saveNow() => _save();

  void _apply(Map<String, dynamic> data) {
    sfx = (data['SFX'] as num?)?.toInt() ?? 1;
    music = (data['Music'] as num?)?.toInt() ?? 1;
    bestScore = (data['BestScore'] as num?)?.toInt() ?? 0;
    tut = (data['Tut'] as num?)?.toInt() ?? 1;
  }

  Map<String, dynamic> toJson() => {
        'SFX': sfx,
        'Music': music,
        'BestScore': bestScore,
        'Tut': tut,
      };

  Future<void> setSfx(bool on) async {
    sfx = on ? 1 : 0;
    await _save();
  }

  Future<void> setMusic(bool on) async {
    music = on ? 1 : 0;
    await _save();
  }

  Future<void> setBestScore(int value) async {
    bestScore = value;
    await _save();
  }

  Future<void> setTutCompleted() async {
    tut = 0;
    await _save();
  }
}
