// Playgama Bridge — wrapper Dart per gli annunci e la multi-piattaforma.
//
// Un solo SDK per pubblicare su 20+ piattaforme web (YouTube Playables,
// CrazyGames, Poki, Telegram, TikTok, Yandex, ...): specchio 1:1 di
// src/lib/playgama.ts del port Next.js (block-rush).
//
// Su web il bridge viene caricato dalla CDN ufficiale e inizializzato col
// config in web/playgama-bridge-config.json; sulle build native (APK
// Android) tutto degrada a no-op: nessun annuncio, gioco al 100%.
export 'playgama_ads_stub.dart'
    if (dart.library.js_interop) 'playgama_ads_web.dart';
