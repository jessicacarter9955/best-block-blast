enum AdOutcome { completed, cancelled, unavailable }

const bool isYoutubePlayablesBuild = false;
Future<bool> initYoutubePlayables() async => false;
Future<String> youtubeLanguage() async => 'en';
Future<String?> loadBridgeSave() async => null;
Future<bool> saveBridgeData(String value) async => false;
void sendGameReady() {}
void listenToPlatform({
  required void Function(bool paused) onPause,
  required void Function(bool enabled) onAudio,
}) {}
Future<AdOutcome> showRewardedAd(String placement) async =>
    AdOutcome.unavailable;
Future<bool> showInterstitialAd(String placement) async => false;
