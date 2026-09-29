import 'package:flutter/material.dart' show Color;

/// Geometria Block Rush 1:1 — misurata pixel per pixel dai due screenshot
/// reference dell'utente (home 942x1670 + gameplay 941x1672).
/// La griglia (slot 0,0) parte a (74.5, 385); slot 115.8125 x 117.9375;
/// frame board (bordo neon + interno) a (26,343)-(1045,1374).
class Rush {
  Rush._();

  // === griglia ===
  static const double gridX0 = 74.5;
  static const double gridY0 = 385.0;
  static const double pitchX = 115.8125;
  static const double pitchY = 117.9375;
  static const int gridSize = 8;
  /// centro dello slot (r,c)
  static double slotCx(int c) => gridX0 + pitchX * (c + 0.5);
  static double slotCy(int r) => gridY0 + pitchY * (r + 0.5);

  // === frame board ===
  static const double frameL = 26.0;
  static const double frameT = 343.0;
  static const double frameW = 1019.0;
  static const double frameH = 1031.0;

  // === vassoio ===
  static const double trayY = 1600.0;
  static const List<double> trayX = [190, 540, 890];
  static const double trayCell = 89.0;
  static const double trayClamp = 310.0;

  // === HUD ===
  static const double scoreY = 254.0;
  static const double crownX = 114.0;
  static const double crownY = 131.5;
  static const double crownW = 140.0;
  static const double crownH = 125.0;
  static const double bestY = 278.0;
  static const double pauseX = 951.0;
  static const double pauseY = 130.0;
  static const double pauseSize = 123.0;

  // === home ===
  static const double playX = 541.0;
  static const double playY = 1315.0;
  static const double playW = 682.0;
  static const double playH = 282.0;
  static const double iconY = 1642.0;
  static const List<double> iconX = [205, 550, 896];
  static const double iconSize = 226.0;

  // === palette candy viola (pannelli/pillole) ===
  static const panelTop = Color(0xFF4A3499);
  static const panelBottom = Color(0xFF150C36);
  static const pillTop = Color(0xFF9F6BFF);
  static const pillBottom = Color(0xFF5B2BD0);
  static const strokeBlue = Color(0xFF1D4FE8);
  static const glowBlue = Color(0xFF4D9BFF);
  static const bestYellow = Color(0xFFFDF303);
  static const bestStroke = Color(0xFF5A1A66);
  static const medalGold = Color(0xFFFFD54A);
  static const medalSilver = Color(0xFFD7DCE8);
  static const medalBronze = Color(0xFFE8A05C);
}

/// Exact geometry constants of the original Block Blast (Construct 3).
///
/// The original project uses a fixed 1080x1920 design. All values below were
/// extracted from data.json (layout instances) and verified against the live
/// game (pixel measurements at scale 0.3889, fit-width letterboxed).
///
/// Grid derivation (matches the original's CreateSpots + PutSpotsCenter
/// re-parenting math):
///   Board sprite: center (540, 831), size 1000x1000  ->  spans 40..1040, 331..1331
///   Spot(x, y) center = (120 + 120x, 411 + 120y)     ->  grid spans 62..1018, 353..1309
class Design {
  Design._();

  static const double width = 1080;
  static const double height = 1920;

  // === Board & grid ===
  // 1:1 dai reference: celle ref x 64-864 (8×100), y 332-1154 (8×102.7)
  // → app 1080: board center (532, 854), celle 120px, origine spot (112, 434).
  static const double boardX = 532;
  static const double boardY = 854;
  static const double boardSize = 1000;
  // Frame = board COMPLETA (bordo neon + interno): rettangolo 1104×1063
  // a (-13, 319) assoluti (mappato dal ref (10,285)-(930,1195) sulle celle).
  static const double boardArtL = -13;
  static const double boardArtT = 319;
  static const double boardArtW = 1104;
  static const double boardArtH = 1063;
  static const double bigSize = 120; // cell size on the board (BigSize)
  static const double smallSize = 89; // cell size in the tray (1:1 ref: 78px→89)
  static const double gridOriginX = 112; // spot(0,0) center x
  static const double gridOriginY = 434; // spot(0,0) center y
  static const int gridSize = 8;

  // === Tray (PlaceHolders) — 1:1 web: slot fissi ben distanziati,
  // niente pezzo attaccato (gap ampio tra i 3 slot) ===
  static const double trayY = 1600;
  static const double trayGap = 4;
  static const double trayCenterX = 538;
  static const double traySlot0X = 190; // slot centers: 190 / 540 / 890
  static const double traySlotStep = 350;
  static const double phSize = 250;

  // === HUD ===
  static const double txtScoreY = 243;
  static const double cupX = 111; // corona pulita 118×101 (sfondo rimosso) -> 158×135
  static const double cupY = 107;
  static const double cupSize = 158; // crown-only patch (senza lo 0 baked)
  static const double cupH = 135;
  static const double bestScoreX = 111; // centrato SOTTO la corona (richiesta utente)
  static const double bestScoreY = 258;
  static const double pauseBtnX = 981;
  static const double pauseBtnY = 115;
  static const double pauseBtnSize = 118; // hit box (squircle)
  static const double pauseImgW = 185; // squircle quadrata ricostruita 220×220
  static const double pauseImgH = 185;
  static const double heartX = 540;
  static const double heartY = 210;
  static const double heartSize = 240;

  // === Pause popup (layer positions, center-anchored) — 1:1 col web:
  // toggle circolari (non pill schiacciate) + righe rispaziate ===
  static const double pausePopupX = 540;
  static const double pausePopupY = 960.5;
  static const double pausePopupW = 886;
  static const double pausePopupH = 1113;
  static const double btnCloseX = 899;
  static const double btnCloseY = 482;
  static const double btnCloseSize = 80;
  static const double btnSfxX = 794;
  static const double btnSfxY = 655;
  static const double btnMusicX = 794;
  static const double btnMusicY = 830;
  static const double toggleSize = 165; // cerchi 165×165 (sprite quadrato 251×251)
  static const double btnHomeX = 761;
  static const double btnHomeY = 1005;
  static const double btnHomeW = 282;
  static const double btnHomeH = 115;
  static const double btnResetX = 761;
  static const double btnResetY = 1175;
  static const double btnResetW = 282;
  static const double btnResetH = 116;
  static const double btnShowRankingX = 761;
  static const double btnShowRankingY = 1345;
  static const double btnShowRankingW = 280;
  static const double btnShowRankingH = 114;

  // === Revive ===
  static const double reviveCircleX = 540;
  static const double reviveCircleY = 779;
  static const double reviveCircleSize = 570;
  static const double btnReviveX = 533.4;
  static const double btnReviveY = 1362.1;
  static const double btnReviveW = 544;
  static const double btnReviveH = 188.4;
  static const int reviveTime = 5; // seconds

  // === Game Over ===
  static const double goBannerX = 540.2;
  static const double goBannerY = 506.4;
  static const double goBannerW = 940.4;
  static const double goBannerH = 101; // banner 940×101 (crop padding basso)
  static const double goScoreLabelY = 761.3;
  static const double goScoreY = 905;
  static const double goBestLabelY = 1113;
  static const double goCupX = 407.5;
  static const double goCupY = 1205.5;
  static const double goCupSize = 136; // corona 118×101 (sfondo rimosso)
  static const double goCupH = 117;
  static const double goBestX = 482;
  static const double goBestY = 1223;
  static const double btnGOResetX = 540.1;
  static const double btnGOResetY = 1597.9;
  static const double btnGOResetW = 510.2;
  static const double btnGOResetH = 176.7;

  // === Ranking popup ===
  static const double lbPopupX = 540;
  static const double lbPopupY = 966.5;
  static const double lbPopupW = 928;
  static const double lbPopupH = 1535;
  static const double lbTitleX = 540;
  static const double lbTitleY = 283;
  static const double lbRowStartY = 490; // ItemBg y for row 0 (490 + i*120)
  static const double lbRowStep = 120;
  static const double lbRowW = 733;
  static const double lbRowH = 103;
  static const double lbCloseX = 918;
  static const double lbCloseY = 275;
  static const double lbCloseSize = 89.3;

  // === Home (1:1 reference: play 722×298 a (533,1319); bottoni sfx 204 ·
  // ranking 539 · music 882 @1664, disco 202 → patch 288 = 202/0.70) ===
  static const double logoX = 540.5;
  static const double logoY = 580;
  static const double logoW = 820;
  static const double logoH = 888;
  static const double btnPlayX = 533;
  static const double btnPlayY = 1319;
  static const double btnPlayW = 722;
  static const double btnPlayH = 298;
  static const double homeMusicX = 882;
  static const double homeSfxX = 204;
  static const double homeBtnY = 1664;
  static const double homeBtnSize = 202; // hit box (disco)
  static const double homeBtnArtSize = 288; // patch 251×251 (disco 70%)

  // === No space left banner ===
  static const double noSpaceX = 540;
  static const double noSpaceY = 1630;
  static const double noSpaceW = 998;
  static const double noSpaceH = 295;

  // === Block sizes on sheets (natural art size) ===
  static const double blockSpriteSize = 125;
}
