# Playgama Bridge — Ads & multi-piattaforma (Flutter)

Block Rush integra [Playgama Bridge](https://github.com/Playgama/bridge)
(CDN `bridge.playgama.com`): **un'unica integrazione per pubblicare su 20+
piattaforme**, tra cui **YouTube Playables**, CrazyGames, Poki,
GameDistribution, Telegram, TikTok, Yandex Games, Facebook, Discord, Reddit,
MSN, GameSnacks, Samsung, Huawei, VK e altre.

Il port Flutter è specchio 1:1 dell'integrazione del port web
(`block-rush` → `src/lib/playgama.ts`): stesse logiche, stessi fallback,
stessi placement.

## Cosa è integrato

| Punto del gioco | Formato | Note |
| --- | --- | --- |
| Suggerimento (`?` in partita) | **Rewarded** | `GUARDA ANNUNCIO` → mostra il pezzo da piazzare e le celle |
| Revive (`ONE MORE CHANCE`) | **Rewarded** | `WATCH AD & CONTINUE` con countdown in pausa durante l'annuncio; senza ads → `FREE CONTINUE` |
| `PLAY AGAIN` dal game over | **Interstitial** | delay minimo 90s gestito dall'SDK |

File chiave:

- `lib/game/playgama_ads.dart` — barrel: export condizionale web/stub
- `lib/game/playgama_ads_web.dart` — wrapper web: caricamento CDN, init,
  `showRewardedAd()`, `showInterstitialAd()`, `isRewardedAdReady()`,
  watchdog 30s, degradazione graceful (via `dart:js_util`)
- `lib/game/playgama_ads_stub.dart` — no-op per le build native (APK):
  nessun annuncio, mai crash
- `web/playgama-bridge-config.json` — config SDK (safe-area, delay
  interstitial, preload dei placement `hint` / `game_over`)
- `lib/game/audio.dart` — `duckMusicOn()`/`duckMusicOff()`: la musica tace
  durante gli annunci e riprende dopo (specchio del port web)
- `lib/game/block_blast_game.dart` — provider `rewardedHintAd`, revive con
  ad gating, `_playAgainWithAd()` con interstitial
- `lib/game/rendering.dart` — label dinamiche del pannello revive

## Degradazione graceful (regola d'oro)

Sull'APK Android (build nativa) il wrapper è uno stub: zero annunci, zero
reti, zero crash. Su web fuori dalle piattaforme (dev locale, hosting
normale) il bridge risponde con valori sicuri: `isRewardedSupported =
false` → l'UI mostra i fallback (`Annunci non disponibili. Riprova più
tardi.` / `FREE CONTINUE`). Se la CDN è bloccata (AdBlock/rete) il gioco
parte comunque al 100%. Mai bloccare il gioco per colpa degli ads.

## Pubblicare su Playgama (e YouTube Playables)

1. Scarica **`block-rush-web-latest.zip`** dalla Release
   https://github.com/jessicacarter9955/best-block-blast/releases/latest
   (lo pubblica il workflow `Build Playgama Web Bundle` a ogni push:
   `index.html` alla radice, config e asset inclusi, base href `/`).
2. Crea/entra nel cabinet su **https://developer.playgama.com**.
3. Nuovo gioco → carica lo zip + cover/screenshot.
4. Scegli le piattaforme di destinazione (YouTube Playables, CrazyGames,
   Poki, ...): il bridge rileva da solo la piattaforma e attiva gli
   annunci giusti.
5. Sandbox test → submit per review. Gli incassi arrivano nel cabinet.

Tool utili: [config editor](https://playgama.github.io/bridge-config-editor/),
[DevTools Chrome](https://chromewebstore.google.com/detail/playgama-bridge-devtools/mldhijegcmagkcchjmenafiipkhjlppo),
[wiki](https://wiki.playgama.com/playgama/bridge-sdk/getting-started),
[Discord](https://discord.gg/pzqd2upxr8).

## Test locali

```bash
flutter run -d chrome            # dev: bridge init in console, fallback ads
flutter build web --release --no-tree-shake-icons --base-href /
python3 -m http.server 8923 --directory build/web
```

In dev (`mock`/`standalone`) il rewarded non è supportato: il dialogo
suggerimento mostra il fallback e il revive resta `FREE CONTINUE` —
comportamento voluto, identico al port web.
