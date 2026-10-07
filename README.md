# Block Rush — Flutter + Flame

Puzzle game sviluppato con Flutter e Flame per Android e Web. Offre una griglia 8×8, pezzi da posizionare, combo, salvataggio del record, suggerimenti e replay delle mosse.

La logica di generazione verifica una sequenza valida per ogni nuovo vassoio. Le scelte del giocatore possono comunque portare al game over; il replay mostra una sequenza valida disponibile prima della sconfitta.

## Avvio e build

```bash
flutter pub get
flutter run -d chrome       # Web
flutter run                 # dispositivo collegato
flutter build web --release
flutter build apk --release
```

Il workflow GitHub Actions prepara l’APK Android e il pacchetto Web. Per le istruzioni Playgama consulta [docs/PLAYGAMA.md](docs/PLAYGAMA.md); per lo stato generale della distribuzione consulta [docs/RELEASE-READINESS.md](docs/RELEASE-READINESS.md).

## Struttura

- `lib/game/`: logica, rendering, controlli, layout e persistenza.
- `assets/`: immagini, audio, font e dati usati dal gioco.
- `test/`: test di generazione dei vassoi e geometria del trascinamento.
- `web/`: configurazione e punto d’ingresso per la build web.

Il progetto usa Flame per il rendering del gioco e adatta l'interfaccia all'orientamento dello schermo: griglia a sinistra e vassoi e comandi nel pannello laterale in orizzontale.
