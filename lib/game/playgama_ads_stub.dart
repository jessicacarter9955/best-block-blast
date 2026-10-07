// Fallback nativo (APK Android / iOS / desktop): nessuna piattaforma
// Playgama, nessun annuncio — ogni chiamata degrada in modo sicuro.
// Regola d'oro 1:1 col port web: mai crash, mai blocco per colpa degli ads.

/// Esito di un annuncio rewarded (specchio di src/lib/playgama.ts).
enum AdOutcome { completed, cancelled, unavailable }

/// Init del bridge: sempre false sulle build native.
const bool isYoutubePlayablesBuild = false;
Future<bool> initPlaygama() async => false;
Future<bool> initYoutubePlayables() async => false;
Future<String> youtubeLanguage() async => 'en';
Future<void> sendYoutubeScore(int value) async {}
String get playgamaLanguage => 'en';
Future<String?> loadBridgeSave() async => null;
Future<bool> saveBridgeData(String value) async => false;
void sendGameReady() {}
void listenToPlatform({
  required void Function(bool paused) onPause,
  required void Function(bool enabled) onAudio,
}) {}

/// True se la piattaforma supporta i rewarded (mai su native).
Future<bool> isRewardedSupported() async => false;

/// True solo dentro una piattaforma della rete Playgama (mai su native).
bool get isPlaygamaPlatform => false;

/// True se un rewarded è pronto all'uso (mai su native).
Future<bool> isRewardedAdReady() async => false;

/// Mostra un rewarded; su native è sempre [AdOutcome.unavailable].
Future<AdOutcome> showRewardedAd(String placement) async =>
    AdOutcome.unavailable;

/// Mostra un interstitial; su native risolve sempre false.
Future<bool> showInterstitialAd(String placement) async => false;
