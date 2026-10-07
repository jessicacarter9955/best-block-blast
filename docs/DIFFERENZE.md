# Block Blast — Differenze tra porting Flutter e originale (Construct 3)

> Basato sul decompilamento completo dell'originale (event sheet, layout, geometria misurata live sul gioco in esecuzione).
> Riferimenti: `download/original-decompiled.txt` (logica), `download/original-layouts.txt` (posizioni).

---

## A. Identità visiva / assets

| # | Elemento | Porting attuale | Originale | Azione |
|---|----------|-----------------|-----------|--------|
| 1 | Colori blocchi | Palette "cioccolato" ricolorata via `recolor_blocks.py` (viola, marrone, oro, crema…) | 8 colori originali: viola `(141,95,215)`, ciano `(54,178,225)`, verde `(59,180,59)`, blu `(72,100,231)`, oro `(237,182,50)`, arancio `(237,120,33)`, rosso `(201,49,49)`, magenta `(211,95,215)` | ripristinare `block-sheet0.png` originale |
| 2 | Home | Titolo "BLOCK BLAST" disegnato con TextPainter + BEST | Logo immagine `Sprite2` 837×888 a `(540,532)`, sfondo `LightBlueBg`, `BtnPlay` 625×216 a `(540,1295)`, `BtnRanking`/`BtnMusic2`/`BtnSFX2` 130–170×… a `y=1770` | layout Home identico |
| 3 | HUD | Pannello custom: corona + score centrato + BEST sotto | `txtScore` (540,211.5) spritefont 620×169, `txtBestScore` (158,82) + `CupIcon` (97,76) 104×104 in alto a sinistra, `BtnPause` (974,88) 100×100 | layout HUD identico |
| 4 | Pausa | Popup generico con 5 bottoni in fila orizzontale + testo "PAUSED" | `PausePopup` 886×1113 con bottoni **verticali**: BtnClose(899,482), BtnSFX(794,654), BtnMusic(794,817), BtnHome(761,994), BtnReset(761,1164), BtnShowRanking(761,1344); slide-down dall'alto 0.5s + `BlackBg` fade a 70% | popup identico + animazione |
| 5 | Game Over | Banner + bottoni disegnati a mano | Layer `LightBlueBg` 1277×2094, banner `GameOver` (540,506) 940×156, `TLabel` "SCORE" (540,761), `txtGOScore` count-up 0.8s (540,905) 800×261, `TLabel` "BEST" (540,1113), `CupIcon` (407,1205) 140×140 + `txtGOBestScore` raggruppati in `GOCupParent`, `BtnGOReset` (540,1598) 510×177 | schermata identica |
| 6 | Revive | Cerchio + bottoni custom, timer 5→0 con timer.periodic | `ReviveCircle` (540,779) 570×570 con `txtReviveTimer` dentro, `RadialProgress` con tween proporzionale, `BtnRevive` (533,1362) 544×188, countdown 5→0 con **beep** a ogni secondo | identica + beep + progress |
| 7 | Ranking | 5 nomi hardcoded in popup pausa | `LeaderboardPopup2` 928×1535, 10 righe `ItemBg` 733×103 (y 478.5→1556.5, step 120), `txtItemRank/Name/Score`, dati da `ranking.json` (9 giocatori) con **decadimento temporale** dei punteggi, riga "You" evidenziata (ItemBg frame 1), `BtnClose` (918,275) | implementazione completa |
| 8 | Banner "No space left" | **ASSENTE** | `NoSpaceLeft` 998×295 appare a (540,1630) con pop-in (scala 0→998×295, opacità 0→100, 0.3s) prima del revive | aggiungere |
| 9 | Logo + TLabel | **ASSENTI** | `Sprite2` (logo) e `TLabel` SCORE/BEST | estrarre dagli sheet originali |

## B. Geometria

| # | Elemento | Porting | Originale (misurato live) |
|---|----------|---------|---------------------------|
| 10 | Sistema coordinate | Layout responsive custom (padding 16, calcoli relativi) | Design fisso **1080×1920** (viewport a risoluzione fissa), Board (540,831) 1000×1000 → griglia `Spot(x,y)` centro = **(120+120x, 411+120y)**, celle **120px** (`BigSize`) |
| 11 | Tray | 3 slot calcolati | 3 `PlaceHolder` 250×250 a `(196.5, 539.5, 883.5, y=1626)`, pezzi con celle **60px** (`SmallSize`) centrati sul placeholder |
| 12 | Drag | Pezzo centrato sul dito, dimensione fissa | `ShapesParent` segue il dito con **offset Y−200** e **scala ×2** (60→120), ombra nascosta durante drag, ritorno con tween 0.3s + SFX "return" |
| 13 | Anteprima piazzamento | Riquadri colorati trasparenti | `BlockBelow` (sprite blocco 30% opacità) su ogni cella target + **righe/colonne completate marcate durante il drag** (i blocchi della riga si ricolorano al colore del pezzo trascinato) |

## C. Logica di gioco

| # | Elemento | Porting | Originale |
|---|----------|---------|-----------|
| 14 | Generazione pezzi | 3 forme casuali indipendenti, colori anche ripetuti | Pool di **5 forme piazzabili** (su 37 mescolate, verificate con `ShapeCheckPlace`), 3 forme **distinte** (pop), 3 colori **distinti** (da 8 mescolati, pop) |
| 15 | Punteggio | +blocchi + `linee*(linee+1)*5/2` | +blocchi + **`EarnedScore = Combo × 10 × linee × max(1, linee−1)`** (Combo già incrementato: 1ª riga=Combo1 → 10×linee) |
| 16 | Combo | Cheerful frame per righe simultanee, durata fissa 1.6s | `Combo` conta le giocate **consecutive** che puliscono righe; suono `score/s{min(15,Combo+1)}` (15 varianti!); UI: glow `ComboSprite` (Combo==1), + testo "×N" con glows e **shake schermo (5px, 0.2s)** da Combo>1; timer 0.9s → shrink → mostra punteggio guadagnato |
| 17 | Heart | Cuore pulsante generico | `Heart` 240×240 **dietro lo score** (540,210), visibile da Combo>1, comportamenti Sine, nascosto al reset |
| 18 | Reset combo | ASSENTE | **3 giocate consecutive senza punti** (con cuore attivo) → Combo=−1, cuore nascosto, contatore azzerato |
| 19 | Line clear | Flash bianco→scuro 320ms, rimozione dopo 320ms | Righe marcate durante il drag; al drop: `LineEffect` ninepatch **colorata col colore del pezzo** (opacità 30→100, larghezza→board−45, altezza→120, fade-out), `GlowEffect`, **20 particelle `SquareEffect`** che volano ±220px con durata casuale 1.5–3.3s, blocchi distrutti |
| 20 | Game over flow | Revive immediato 5s | `GameState="Waiting"` → music fadeout (−100dB, 0.1s) → SFX `no_space` → **banner NoSpaceLeft pop-in** → wait 1s → RevivePage (countdown 5→0 con beep + RadialProgress) → GameOver layer (lose SFX, count-up 0.8s) |
| 21 | Revive | Pulisce righe 5-7 della board | **Distrugge i blocchi che sovrappongono i PlaceHolder** (i pezzi in tray!), reset `ShapePlaced`, `PutShapeCount=0`, `CreateShapes(1)`, music fade-in; il revive "vero" avviene col rewarded ad (GD) |
| 22 | Persistenza | **ASSENTE** (best score perso a ogni riavvio) | LocalStorage `"Block Blast_Data"`: `{SFX, Music, BestScore, Tut}` — best salvato **live** durante la partita |
| 23 | Tutorial | Mano animata generica su qualsiasi partita | **3 step scriptati** (solo se `Tut==1`): step1 colonne 3-5 righe≠4 (righe colorate per indice), pezzo 1×3; step2 righe 3-5 colonne≠4, pezzo 3×1 verticale; step3 croce (colonne 3-4 rows≠3,4 + righe 3-4 cols≠3,4), pezzo 2×2; vincoli drag per cella, `Hand`+`TutBlock` ghost che si muove verso il target (tween 0.5s), timer 1.2s; alla fine `Tut=0` salvato |
| 24 | Audio | 9 file base, volumi fissi | 14 varianti score (s1–s15 senza s12), 5 cheerful (c2–c6), beep countdown, volumi precisi (beep vol 5, cheerful −10), music a −5dB con fade in/out |
| 25 | Ranking dati | Hardcoded | `ranking.json` con formula decadimento: `score + int((1100 − giorniDa(2025-09-12)) × 8.5 × (index+1))`, inserimento "You" con BestScore, sort, top 10, rank >10 mostrato calcolato |
| 26 | Pausa musica | `pauseMusic()` alla pausa | Il gioco si ferma per timescale, **la musica continua** |
| 27 | Loader | ASSENTE | Layout Loader: carica `shapes.json`, conta i blocchi per forma (`ArrayBlocksCount`), poi check LocalStorage → Game |
| 28 | GD SDK | ASSENTE | Preload rewarded ad, pause/resume con timescale+volume — non applicabile nativamente, ma il flusso revive/reward è implementato in modo equivalente |

## D. Dettagli interazione

| # | Elemento | Porting | Originale |
|---|----------|---------|-----------|
| 29 | Feedback bottoni | Nessuno | Scale **0.95** al touch, reset al release |
| 30 | Ritorno pezzo | Istantaneo/nessun suono | Tween 0.3s ease-out verso il PlaceHolder + SFX `return` |
| 31 | Nascita pezzo | Nessuna animazione | `CircleGlow` (opacità 0→30, scala 0→300, 0.2–0.3s) + `Particles` al PlaceHolder, pezzo pop-in 0.3s (scala 0→1) |
| 32 | Piazzamento blocco | Istantaneo | Tween 0.1s verso lo spot, distruzione `ShapesParent` dopo 0.1s |
| 33 | Score | Aggiornamento istantaneo | **Count-up animato 0.5s** (tween "num") |
| 34 | Best score | Aggiornamento istantaneo | Count-up 0.5s + salvataggio live |
| 35 | Estrusione drag | Il pezzo resta dove è | Il pezzo si solleva a 200px sopra il dito (visibilità completa) |
| 36 | Ombra blocchi | Sempre visibile | `BlockShadow` offset (8,8) visibile nel tray e a riposo, **nascosta durante il drag**, visibile di nuovo al ritorno |

---

## Geometria di riferimento (misurata live, design 1080×1920)

```
Board            (540, 831) 1000×1000 (centro)
Spot(x,y)        centro = (120 + 120x, 411 + 120y), sprite 116×116, blocchi 120×120
PlaceHolder ×3   (196.5, 1626), (539.5, 1626), (883.5, 1626) 250×250
Pezzi in tray    celle 60×60, centrati sul PlaceHolder
txtScore         (540, 211.5) 620×169
CupIcon          (97, 76) 104×104
txtBestScore     (158, 82)
BtnPause         (974, 88) 100×100
Heart            (540, 210) 240×240 (nascosto, dietro lo score)
PausePopup       (540, 960.5) 886×1113
ReviveCircle     (540, 779) 570×570
BtnRevive        (533.4, 1362.1) 544×188.4
GameOver banner  (540.2, 506.4) 940×156
txtGOScore       (540, 905) 800×261
BtnGOReset       (540.1, 1597.9) 510×177
LeaderboardPopup (540, 966.5) 928×1535, righe y=478.5+i×120, 733×103
Home: logo       (540.5, 532) 837×888
Home: BtnPlay    (540, 1295) 625×216
Home: BtnRanking (540, 1770) 130×130 (round)
Home: BtnMusic2  (906, 1770) 130×130
Home: BtnSFX2    (175, 1770) 130×130
```

## Formule di riferimento

```
EarnedScore   = Combo_incr × 10 × linee × max(1, linee−1)
Suono score   = "score/s" + min(15, Combo_incr+1)
Cheerful      = frame = n° linee simultanee (2..6), suono "cheerful/c{linee}" vol −10
Ranking score = score + int((1100 − giorniDa(2025-09-12)) × 8.5 × (index+1))
Combo reset   = 3 giocate consecutive senza righe (con cuore attivo) → Combo = −1
ReviveTimer   = 5s, beep a ogni tick, game over quando RevivePassedTime ≥ ReviveTime
```
