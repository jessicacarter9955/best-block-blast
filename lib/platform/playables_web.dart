import 'dart:async';
import 'dart:js_util' as js;

enum AdOutcome { completed, cancelled, unavailable }

const bool isYoutubePlayablesBuild =
    bool.fromEnvironment('YOUTUBE_PLAYABLES_BUILD');

Object? get _ytgame => js.getProperty(js.globalThis, 'ytgame');

Future<bool> initYoutubePlayables() async =>
    isYoutubePlayablesBuild && _ytgame != null;

Future<String> youtubeLanguage() async {
  try {
    final system = js.getProperty(_ytgame!, 'system');
    final result = await js.promiseToFuture<dynamic>(
        js.callMethod(system, 'getLanguage', []));
    return (result as String).toLowerCase().split(RegExp('[-_]')).first;
  } catch (_) {
    return 'en';
  }
}

Future<String?> loadBridgeSave() async {
  try {
    final game = js.getProperty(_ytgame!, 'game');
    return await js.promiseToFuture<String>(js.callMethod(game, 'loadData', []));
  } catch (_) {
    return null;
  }
}

Future<bool> saveBridgeData(String value) async {
  try {
    final game = js.getProperty(_ytgame!, 'game');
    await js.promiseToFuture<dynamic>(js.callMethod(game, 'saveData', [value]));
    return true;
  } catch (_) {
    return false;
  }
}

void sendGameReady() {
  try {
    final game = js.getProperty(_ytgame!, 'game');
    js.callMethod(game, 'firstFrameReady', []);
    js.callMethod(game, 'gameReady', []);
  } catch (_) {}
}

void listenToPlatform({
  required void Function(bool paused) onPause,
  required void Function(bool enabled) onAudio,
}) {
  try {
    final system = js.getProperty(_ytgame!, 'system');
    js.callMethod(system, 'onPause', [js.allowInterop(() => onPause(true))]);
    js.callMethod(system, 'onResume', [js.allowInterop(() => onPause(false))]);
    js.callMethod(system, 'onAudioEnabledChange', [
      js.allowInterop((dynamic enabled) => onAudio(enabled == true))
    ]);
    onAudio(js.callMethod(system, 'isAudioEnabled', []) == true);
  } catch (_) {}
}

Future<AdOutcome> showRewardedAd(String placement) async {
  try {
    final ads = js.getProperty(_ytgame!, 'ads');
    final result = await js.promiseToFuture<dynamic>(
        js.callMethod(ads, 'requestRewardedAd', [placement]));
    return result == true ? AdOutcome.completed : AdOutcome.cancelled;
  } catch (_) {
    return AdOutcome.unavailable;
  }
}

Future<bool> showInterstitialAd(String placement) async {
  try {
    final ads = js.getProperty(_ytgame!, 'ads');
    await js.promiseToFuture<dynamic>(
        js.callMethod(ads, 'requestInterstitialAd', []));
    return true;
  } catch (_) {
    return false;
  }
}
