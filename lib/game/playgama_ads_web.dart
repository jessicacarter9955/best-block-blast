// Implementazione WEB del wrapper Playgama Bridge: caricamento CDN, init
// col config, rewarded + interstitial con eventi e watchdog — specchio 1:1
// di src/lib/playgama.ts del port Next.js (block-rush).
//
// Usa dart:js_util (interop dinamica stabile su dart2js) per parlare con
// window.bridge. Fuori dalle piattaforme (dev locale, hosting normale) il
// bridge risponde con valori sicuri: nessun annuncio, gioco giocabile al
// 100%. Se la CDN è bloccata (AdBlock/rete) l'init fallisce in silenzio.

import 'dart:async';
import 'dart:js_util' as js;

/// Esito di un annuncio rewarded (specchio di src/lib/playgama.ts).
enum AdOutcome { completed, cancelled, unavailable }

const String _cdnSrc =
    'https://bridge.playgama.com/v2/stable/playgama-bridge.js';
const bool isYoutubePlayablesBuild =
    bool.fromEnvironment('YOUTUBE_PLAYABLES_BUILD');

Object? get _youtube => js.getProperty(js.globalThis, 'ytgame');

Future<bool> initYoutubePlayables() async => isYoutubePlayablesBuild && _youtube != null;

Future<void> sendYoutubeScore(int value) async {
  if (!isYoutubePlayablesBuild || value < 0) return;
  try {
    final engagement = js.getProperty(_youtube!, 'engagement');
    final score = js.newObject();
    js.setProperty(score, 'value', value);
    await js.promiseToFuture<dynamic>(
        js.callMethod(engagement, 'sendScore', [score]));
  } catch (_) {}
}

Future<String> youtubeLanguage() async {
  try {
    final system = js.getProperty(_youtube!, 'system');
    final result = await js.promiseToFuture<dynamic>(
        js.callMethod(system, 'getLanguage', []));
    return (result as String).toLowerCase().split(RegExp('[-_]')).first;
  } catch (_) {
    return 'en';
  }
}

// Watchdog di rete: se dopo 30s non è successo nulla, scongella il gioco.
const Duration _watchdog = Duration(seconds: 30);

// Stati interni del modulo advertisement (specchio di REWARDED_STATE).
const String _loading = 'loading';
const String _opened = 'opened';
const String _closed = 'closed';
const String _failed = 'failed';
const String _rewarded = 'rewarded';

Completer<void>? _scriptCompleter;
Future<bool>? _initFuture;

Object? get _bridge => js.getProperty(js.globalThis, 'bridge');

Object? get _advertisement =>
    _bridge == null ? null : js.getProperty(_bridge!, 'advertisement');

String? get _platformId {
  final b = _bridge;
  if (b == null) return null;
  final platform = js.getProperty(b, 'platform');
  if (platform == null) return null;
  return js.getProperty(platform, 'id') as String?;
}

/// True se siamo dentro una piattaforma della rete Playgama (non standalone).
bool get isPlaygamaPlatform {
  final id = _platformId;
  return id != null && id != 'standalone' && id != 'mock';
}

// -- caricamento + inizializzazione (una sola volta per pagina) -----------

Future<void> _loadBridgeScript() {
  if (_bridge != null) return Future.value();
  final existing = _scriptCompleter;
  if (existing != null) return existing.future;
  final completer = Completer<void>();
  _scriptCompleter = completer;
  try {
    final doc = js.getProperty(js.globalThis, 'document');
    final head = js.getProperty(doc, 'head');
    final script = js.callMethod(doc, 'createElement', ['script']);
    js.setProperty(script, 'src', _cdnSrc);
    js.setProperty(script, 'async', true);
    js.setProperty(
        script,
        'onload',
        js.allowInterop((_) {
          if (!completer.isCompleted) completer.complete();
        }));
    js.setProperty(
        script,
        'onerror',
        js.allowInterop((_) {
          if (!completer.isCompleted) {
            completer.completeError(
                StateError('Playgama bridge CDN non raggiungibile'));
          }
        }));
    js.callMethod(head, 'appendChild', [script]);
  } catch (e) {
    if (!completer.isCompleted) completer.completeError(e);
  }
  return completer.future.timeout(const Duration(seconds: 8));
}

/// Language chosen by the hosting platform. Resolve after Bridge init.
String get playgamaLanguage {
  final platform = _bridge == null ? null : js.getProperty(_bridge!, 'platform');
  return platform == null
      ? 'en'
      : ((js.getProperty(platform, 'language') as String?) ?? 'en')
          .toLowerCase()
          .split(RegExp('[-_]'))
          .first;
}

/// Loads the saved player payload through Bridge Storage where available.
Future<String?> loadBridgeSave() async {
  if (isYoutubePlayablesBuild) {
    try {
      final game = js.getProperty(_youtube!, 'game');
      return await js.promiseToFuture<String>(js.callMethod(game, 'loadData', []));
    } catch (_) {
      return null;
    }
  }
  final bridge = _bridge;
  if (bridge == null) return null;
  try {
    final storage = js.getProperty(bridge, 'storage');
    final result = await js.promiseToFuture<dynamic>(
        js.callMethod(storage, 'get', [['_block_rush_save']]));
    final value = js.getProperty(result, '0');
    return value is String ? value : null;
  } catch (_) {
    return null;
  }
}

Future<bool> saveBridgeData(String value) async {
  if (isYoutubePlayablesBuild) {
    try {
      final game = js.getProperty(_youtube!, 'game');
      await js.promiseToFuture<dynamic>(js.callMethod(game, 'saveData', [value]));
      return true;
    } catch (_) {
      return false;
    }
  }
  final bridge = _bridge;
  if (bridge == null) return false;
  try {
    final storage = js.getProperty(bridge, 'storage');
    await js.promiseToFuture<dynamic>(js.callMethod(
        storage, 'set', [['_block_rush_save'], [value]]));
    return true;
  } catch (_) {
    return false;
  }
}

void sendGameReady() {
  try {
    if (isYoutubePlayablesBuild) {
      final game = js.getProperty(_youtube!, 'game');
      js.callMethod(game, 'firstFrameReady', []);
      js.callMethod(game, 'gameReady', []);
      return;
    }
    final platform = js.getProperty(_bridge!, 'platform');
    js.callMethod(platform, 'sendMessage', ['game_ready']);
  } catch (_) {}
}

/// Connect host lifecycle controls after initialization.
void listenToPlatform({
  required void Function(bool paused) onPause,
  required void Function(bool enabled) onAudio,
}) {
  try {
    if (isYoutubePlayablesBuild) {
      final system = js.getProperty(_youtube!, 'system');
      js.callMethod(system, 'onPause', [js.allowInterop(() => onPause(true))]);
      js.callMethod(system, 'onResume', [js.allowInterop(() => onPause(false))]);
      js.callMethod(system, 'onAudioEnabledChange', [
        js.allowInterop((dynamic enabled) => onAudio(enabled == true))
      ]);
      onAudio(js.callMethod(system, 'isAudioEnabled', []) == true);
      return;
    }
    final bridge = _bridge!;
    final platform = js.getProperty(bridge, 'platform');
    final events = js.getProperty(bridge, 'EVENT_NAME');
    final pauseEvent = js.getProperty(events, 'PAUSE_STATE_CHANGED');
    final audioEvent = js.getProperty(events, 'AUDIO_STATE_CHANGED');
    js.callMethod(platform, 'on', [pauseEvent,
      js.allowInterop((dynamic value) => onPause(value == true))]);
    js.callMethod(platform, 'on', [audioEvent,
      js.allowInterop((dynamic value) => onAudio(value == true))]);
    onAudio(js.getProperty(platform, 'isAudioEnabled') != false);
  } catch (_) {}
}

/// Percorso del config derivato dall'URL della pagina (l'equivalente del
/// basePath BP del port web: funziona a root, in sottocartelle e con
/// index.html esplicito nell'URL).
String _configFilePath() {
  try {
    final location = js.getProperty(js.globalThis, 'location');
    final pathname = js.getProperty(location, 'pathname') as String? ?? '/';
    final base = pathname.endsWith('/')
        ? pathname
        : pathname.substring(0, pathname.lastIndexOf('/') + 1);
    return '${base}playgama-bridge-config.json';
  } catch (_) {
    return './playgama-bridge-config.json';
  }
}

/// Inizializza il bridge; risolve false se CDN/config non raggiungibili.
Future<bool> initPlaygama() {
  if (isYoutubePlayablesBuild) return Future.value(false);
  final existing = _initFuture;
  if (existing != null) return existing;
  _initFuture = (() async {
    try {
      await _loadBridgeScript();
      final bridge = _bridge;
      if (bridge == null) return false;
      final initialized =
          js.getProperty(bridge, 'isInitialized') as bool? ?? false;
      if (!initialized) {
        final options = js.newObject();
        js.setProperty(options, 'configFilePath', _configFilePath());
        final promise = js.callMethod(bridge, 'initialize', [options]);
        if (promise != null) await js.promiseToFuture(promise);
      }
      return true;
    } catch (_) {
      // Silenzioso: fuori rete o con la CDN bloccata il gioco resta
      // giocabile al 100% senza annunci.
      return false;
    }
  })();
  return _initFuture!;
}

// -- rewarded ---------------------------------------------------------------

/// True se la piattaforma supporta i rewarded (capability pura, usata per la
/// registrazione del provider — specchio di isRewardedSupported del web).
Future<bool> isRewardedSupported() async {
  if (isYoutubePlayablesBuild) {
    try {
      return js.getProperty(_youtube!, 'IN_PLAYABLES_ENV') == true;
    } catch (_) {
      return false;
    }
  }
  await initPlaygama();
  final ad = _advertisement;
  if (ad == null) return false;
  return js.getProperty(ad, 'isRewardedSupported') as bool? ?? false;
}

/// True se un rewarded è pronto (piattaforma lo supporta + non occupato).
Future<bool> isRewardedAdReady() async {
  if (isYoutubePlayablesBuild) return isRewardedSupported();
  await initPlaygama();
  final ad = _advertisement;
  if (ad == null) return false;
  if ((js.getProperty(ad, 'isRewardedSupported') as bool? ?? false) == false) {
    return false;
  }
  final state = js.getProperty(ad, 'rewardedState') as String? ?? '';
  return state != _loading && state != _opened;
}

/// Mostra un annuncio rewarded e risolve quando è finito.
/// - completed  : annuncio visto intero → dai la ricompensa
/// - cancelled  : chiuso prima della fine o fallito → niente ricompensa
/// - unavailable: piattaforma senza rewarded / bridge assente
Future<AdOutcome> showRewardedAd(String placement) async {
  if (isYoutubePlayablesBuild) {
    if (!await isRewardedSupported()) return AdOutcome.unavailable;
    try {
      final ads = js.getProperty(_youtube!, 'ads');
      final result = await js.promiseToFuture<dynamic>(
          js.callMethod(ads, 'requestRewardedAd', [placement]));
      return result == true ? AdOutcome.completed : AdOutcome.cancelled;
    } catch (_) {
      return AdOutcome.unavailable;
    }
  }
  await initPlaygama();
  final ad = _advertisement;
  if (ad == null) return AdOutcome.unavailable;
  if ((js.getProperty(ad, 'isRewardedSupported') as bool? ?? false) == false) {
    return AdOutcome.unavailable;
  }
  final state = js.getProperty(ad, 'rewardedState') as String? ?? '';
  if (state == _loading || state == _opened) return AdOutcome.unavailable;

  final completer = Completer<AdOutcome>();
  var rewarded = false;
  Timer? watchdog;
  Object? handler;

  void finish(AdOutcome outcome) {
    if (completer.isCompleted) return;
    watchdog?.cancel();
    if (handler != null) {
      try {
        js.callMethod(ad, 'off', ['rewarded_state_changed', handler]);
      } catch (_) {/* best effort */ }
    }
    completer.complete(outcome);
  }

  handler = js.allowInterop((dynamic s) {
    final value = s == null
        ? (js.getProperty(ad, 'rewardedState') as String? ?? '')
        : s.toString();
    if (value == _rewarded) {
      rewarded = true;
    } else if (value == _closed || value == _failed) {
      finish(rewarded ? AdOutcome.completed : AdOutcome.cancelled);
    }
  });

  try {
    js.callMethod(ad, 'on', ['rewarded_state_changed', handler]);
  } catch (_) {
    return AdOutcome.unavailable;
  }
  // Rete lenta: se dopo 30s non è successo nulla, scongella il gioco.
  watchdog = Timer(_watchdog, () => finish(AdOutcome.unavailable));
  try {
    js.callMethod(ad, 'showRewarded', [placement]);
  } catch (_) {
    finish(AdOutcome.unavailable);
  }
  return completer.future;
}

// -- interstitial -----------------------------------------------------------

/// Mostra un interstitial (fuori dal gameplay, p.es. tra una run e l'altra).
/// L'SDK applica da solo il minimumDelayBetweenInterstitial del config.
/// Risolve true se l'annuncio è stato mostrato e chiuso.
Future<bool> showInterstitialAd(String placement) async {
  if (isYoutubePlayablesBuild) {
    if (!await isRewardedSupported()) return false;
    try {
      final ads = js.getProperty(_youtube!, 'ads');
      await js.promiseToFuture<dynamic>(
          js.callMethod(ads, 'requestInterstitialAd', []));
      return true;
    } catch (_) {
      return false;
    }
  }
  await initPlaygama();
  final ad = _advertisement;
  if (ad == null) return false;
  if ((js.getProperty(ad, 'isInterstitialSupported') as bool? ?? false) ==
      false) {
    return false;
  }
  final state = js.getProperty(ad, 'interstitialState') as String? ?? '';
  if (state == _loading || state == _opened) return false;

  final completer = Completer<bool>();
  Timer? watchdog;
  Object? handler;

  void finish(bool shown) {
    if (completer.isCompleted) return;
    watchdog?.cancel();
    if (handler != null) {
      try {
        js.callMethod(ad, 'off', ['interstitial_state_changed', handler]);
      } catch (_) {/* best effort */ }
    }
    completer.complete(shown);
  }

  handler = js.allowInterop((dynamic s) {
    final value = s == null
        ? (js.getProperty(ad, 'interstitialState') as String? ?? '')
        : s.toString();
    if (value == _closed) {
      finish(true);
    } else if (value == _failed) {
      finish(false);
    }
  });

  try {
    js.callMethod(ad, 'on', ['interstitial_state_changed', handler]);
  } catch (_) {
    return false;
  }
  watchdog = Timer(_watchdog, () => finish(false));
  try {
    js.callMethod(ad, 'showInterstitial', [placement]);
  } catch (_) {
    finish(false);
  }
  return completer.future;
}
