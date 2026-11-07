#!/usr/bin/env node
/**
 * Generate faithful Block Rush artwork previews in six device resolutions.
 *
 * Requires Node >= 20 and sharp (`npm install --no-save sharp`).
 * The original game sprites are never modified; 4K exports are raster
 * enlargements of original art, NOT newly painted/native 4K sprites.
 *
 * Usage: node scripts/build_resolution_pack.mjs
 * Outputs: artwork/resolution-pack/{previews,backgrounds,catalog,inventory.json}
 */
import { createRequire } from 'node:module';
import { readFile, readdir, mkdir, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { join, dirname, relative, resolve, basename } from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
let sharp;
try {
  sharp = require('sharp');
} catch {
  if (!process.env.BLOCKRUSH_SHARP) {
    throw new Error('Install sharp with `npm install --no-save sharp`, or set BLOCKRUSH_SHARP to its absolute module path.');
  }
  sharp = require(process.env.BLOCKRUSH_SHARP);
}

sharp.cache(false);
sharp.concurrency(2);
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const src = (p) => join(root, p);
const out = src('artwork/resolution-pack');
const manifest = JSON.parse(await readFile(src('assets/sprites-named/manifest.json'), 'utf8'));

const formats = [
  { name: 'portrait-full-hd', w: 1080, h: 1920, key: 'portrait' },
  { name: 'portrait-4k', w: 2160, h: 3840, key: 'portrait', upscale: 2 },
  { name: 'landscape-full-hd', w: 1920, h: 1080, key: 'landscape' },
  { name: 'landscape-4k', w: 3840, h: 2160, key: 'landscape', upscale: 2 },
  { name: 'ultrawide', w: 3440, h: 1440, key: 'ultrawide', upscale: 2 },
  { name: 'square', w: 2048, h: 2048, key: 'square', upscale: 2 },
];

const layouts = {
  portrait: {
    w: 1080, h: 1920, board: [26, 343, 1019],
    crown: [148, 107, 158], score: [560, 243, 160], best: [148, 258, 92],
    pause: [981, 115, 142], help: [805, 115, 120],
    tray: [[190, 1600], [540, 1600], [890, 1600]], trayCell: 89,
    home: { play: [533, 1319, 670, 220], icons: [[204, 1664], [539, 1664], [882, 1664]], iconSize: 176 },
  },
  landscape: {
    w: 1920, h: 1080, board: [465, 115, 880],
    crown: [220, 104, 150], score: [220, 335, 138], best: [220, 251, 78],
    pause: [1816, 105, 125], help: [1665, 105, 120],
    tray: [[1550, 298], [1550, 564], [1550, 827]], trayCell: 79,
    home: { logo: [220, 25, 880, 955], play: [1430, 510, 565, 232], icons: [[1240, 850], [1495, 850], [1750, 850]], iconSize: 205 },
  },
  ultrawide: {
    w: 1720, h: 720, board: [526, 40, 625],
    crown: [190, 62, 118], score: [190, 265, 100], best: [190, 183, 64],
    pause: [1612, 77, 108], help: [1479, 77, 101],
    tray: [[1390, 187], [1390, 372], [1390, 559]], trayCell: 56,
    home: { logo: [280, 10, 680, 695], play: [1265, 350, 450, 184], icons: [[1090, 585], [1330, 585], [1570, 585]], iconSize: 164 },
  },
  square: {
    w: 1024, h: 1024, board: [32, 228, 655],
    crown: [115, 53, 120], score: [438, 117, 124], best: [115, 175, 65],
    pause: [943, 95, 103], help: [805, 95, 100],
    tray: [[857, 310], [857, 548], [857, 780]], trayCell: 55,
    home: { logo: [40, 40, 600, 650], play: [815, 490, 348, 145], icons: [[655, 820], [820, 820], [955, 820]], iconSize: 124 },
  },
};

function asset(object, frame = 0) {
  const items = manifest.filter((item) => item.object === object);
  if (!items.length) throw new Error(`Missing sprite ${object}`);
  return src(items[Math.min(frame, items.length - 1)].file);
}

function esc(text) {
  return String(text).replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&apos;',
  })[c]);
}

function svg(w, h, body) {
  return Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${body}</svg>`);
}

async function sized(file, w, h, fit = 'fill') {
  return sharp(file).resize(Math.max(1, Math.round(w)), Math.max(1, Math.round(h)), { fit, kernel: 'lanczos3' }).png().toBuffer();
}

async function overlay(base, overlays, w, h) {
  return sharp(base).composite(overlays).png().toBuffer();
}

async function blank(w, h) {
  return sharp({ create: { width: w, height: h, channels: 4, background: '#00000000' } }).png().toBuffer();
}

function placed(input, x, y) {
  return { input, left: Math.round(x), top: Math.round(y) };
}

async function fadeCenter(file, w, h, featherX = 0.10, featherY = 0.06) {
  // The mask is built explicitly, avoiding accidental transparent stripes
  // introduced by intermediate SVG rasterizers.
  const horizontal = Buffer.alloc(w);
  for (let x = 0; x < w; x++) {
    horizontal[x] = Math.round(255 * Math.min(1, x / Math.max(1, w * featherX), (w - 1 - x) / Math.max(1, w * featherX)));
  }
  const raw = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) {
    const v = Math.min(1, y / Math.max(1, h * featherY), (h - 1 - y) / Math.max(1, h * featherY));
    for (let x = 0; x < w; x++) {
      const n = (y * w + x) * 4;
      raw[n] = 255; raw[n + 1] = 255; raw[n + 2] = 255;
      raw[n + 3] = Math.round(horizontal[x] * v);
    }
  }
  const mask = await sharp(raw, { raw: { width: w, height: h, channels: 4 } }).png().toBuffer();
  const layer = await sized(file, w, h);
  return sharp(layer).composite([{ input: mask, blend: 'dest-in' }]).png().toBuffer();
}

async function background(scene, layout, key) {
  const { w, h } = layout;
  const original = scene === 'game' ? asset('Bg') : asset('BgHome');
  if (key === 'portrait') return sized(original, w, h);
  const extension = src(`artwork/resolution-pack/source/${scene}-extended.png`);
  let base = await sharp(extension).resize(w, h, { fit: 'cover', position: 'centre' }).png().toBuffer();
  if (scene === 'game') {
    const marginW = Math.round(h * (941 / 1672));
    const center = await fadeCenter(original, marginW, h, 0.13, 0.01);
    base = await overlay(base, [placed(center, (w - marginW) / 2, 0)], w, h);
  } else {
    const [x, y, lw, lh] = layout.home.logo;
    const homeArt = await sharp(original).extract({ left: 0, top: 0, width: 941, height: 1032 }).png().toBuffer();
    const center = await fadeCenter(homeArt, lw, lh, 0.07, 0.06);
    base = await overlay(base, [placed(center, x, y)], w, h);
  }
  return base;
}

// The original Flutter renderer paints a navy inner field over the source Board
// sprite, followed by sixty-four 93%-sized rounded gradient slots.
async function boardLayer() {
  const w = 1019, h = 1031;
  const svgCells = [];
  svgCells.push(`<defs><linearGradient id="cell" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#12265B"/><stop offset="1" stop-color="#0A1755"/></linearGradient></defs>`);
  svgCells.push(`<rect x="48.5" y="42" width="926.5" height="943.5" fill="#050E32"/>`);
  for (let r = 0; r < 8; r++) {
    for (let c = 0; c < 8; c++) {
      const cx = 74.5 + 115.8125 * (c + 0.5) - 26;
      const cy = 385 + 117.9375 * (r + 0.5) - 343;
      const cw = 115.8125 * 0.93;
      const ch = 117.9375 * 0.93;
      svgCells.push(`<rect x="${cx - cw / 2}" y="${cy - ch / 2}" width="${cw}" height="${ch}" rx="14" fill="url(#cell)" stroke="#1C3263" stroke-width="2"/>`);
    }
  }
  let board = await overlay(await sized(asset('Board'), w, h), [{ input: svg(w, h, svgCells.join('')), left: 0, top: 0 }], w, h);
  // A reproducible sample state (static preview, not the player's saved game).
  const samples = [
    [0, 0, 1], [0, 1, 1], [1, 1, 1], [2, 1, 1],
    [2, 6, 6], [2, 7, 6], [3, 6, 6], [3, 7, 6],
    [4, 3, 2], [4, 4, 2], [5, 3, 2],
    [6, 0, 5], [6, 1, 5], [6, 2, 5], [7, 1, 5],
    [7, 5, 7], [7, 6, 7],
  ];
  const blocks = [];
  for (const [r, c, color] of samples) {
    const cw = 116, ch = 118;
    const cx = 74.5 + 115.8125 * (c + 0.5) - 26;
    const cy = 385 + 117.9375 * (r + 0.5) - 343;
    blocks.push(placed(await sized(asset('Block', color), cw, ch), cx - cw / 2, cy - ch / 2));
  }
  board = await overlay(board, blocks, w, h);
  return board;
}

const shapes = [
  [[1, 1, 1], [0, 1, 0]],
  [[1, 0], [1, 0], [1, 1]],
  [[1, 1], [1, 1]],
];
async function trayPiece(shape, color, cell) {
  const rows = shape.length, cols = shape[0].length;
  const w = Math.round(cols * cell), h = Math.round(rows * cell);
  const sprite = await sized(asset('Block', color), cell, cell);
  const placements = [];
  for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) {
    if (shape[r][c]) placements.push(placed(sprite, c * cell, r * cell));
  }
  return overlay(await blank(w, h), placements, w, h);
}

async function textImage(word, fontPx, fill, stroke, strokePx) {
  // Render with the *actual* bundled LuckiestGuy.ttf. SVG/Pango would silently
  // substitute a generic sans-serif font on some operating systems.
  return execFileSync('convert', [
    '-background', 'none', '-font', src('assets/fonts/LuckiestGuy.ttf'),
    '-pointsize', String(fontPx), '-stroke', stroke,
    '-strokewidth', String(strokePx), '-fill', fill,
    `label:${word}`, 'png:-',
  ], { maxBuffer: 16 * 1024 * 1024 });
}

async function graphicAt(file, cx, cy, size, naturalRatio = 1) {
  const w = Math.round(size), h = Math.round(size * naturalRatio);
  return placed(await sized(file, w, h), cx - w / 2, cy - h / 2);
}

async function gamePreview(layout, key, boardMaster) {
  const { w, h } = layout;
  let base = await background('game', layout, key);
  const [bx, by, bw] = layout.board;
  const bh = Math.round(bw * (1031 / 1019));
  const placements = [placed(await sized(boardMaster, bw, bh), bx, by)];
  // Three source-game pieces, with non-deformed source sprites.
  for (let i = 0; i < 3; i++) {
    const cell = layout.trayCell;
    const item = await trayPiece(shapes[i], [3, 2, 5][i], cell);
    const m = await sharp(item).metadata();
    placements.push(placed(item, layout.tray[i][0] - m.width / 2, layout.tray[i][1] - m.height / 2));
  }
  const [cx, cy, cw] = layout.crown;
  const crown = asset('CrownHD');
  placements.push(await graphicAt(crown, cx, cy, cw));
  const [sx, sy, ss] = layout.score;
  const score = await textImage('0', ss, '#FFFFFF', '#174E91', Math.max(5, ss * 0.085));
  const scoreMeta = await sharp(score).metadata();
  placements.push(placed(score, sx - scoreMeta.width / 2, sy - scoreMeta.height / 2));
  const [bestX, bestY, bestSize] = layout.best;
  const best = await textImage('0', bestSize, '#FFD34E', '#5A1A66', Math.max(3, bestSize * 0.08));
  const bestMeta = await sharp(best).metadata();
  placements.push(placed(best, bestX - bestMeta.width / 2, bestY - bestMeta.height / 2));
  // Both control glyphs exist as original art in assets/rush; use the original
  // pause bitmap. The runtime help control is vector-drawn, reproduced in SVG.
  const [px, py, ps] = layout.pause;
  placements.push(await graphicAt(src('assets/rush/btn-pause.png'), px, py, ps));
  const [hx, hy, hs] = layout.help;
  const question = svg(Math.round(hs), Math.round(hs), `<defs><linearGradient id="b" x2="0" y2="1"><stop stop-color="#4967C4"/><stop offset="1" stop-color="#253A82"/></linearGradient></defs><circle cx="${hs / 2}" cy="${hs / 2}" r="${hs * 0.46}" stroke="#89AEFF" stroke-width="3" fill="url(#b)"/><text x="50%" y="53%" font-size="${hs * 0.55}" font-weight="900" font-family="sans-serif" fill="#FFF" dominant-baseline="central" text-anchor="middle">?</text>`);
  placements.push(placed(question, hx - hs / 2, hy - hs / 2));
  base = await overlay(base, placements, w, h);
  return base;
}

async function homePreview(layout, key) {
  let base = await background('home', layout, key);
  const { w, h } = layout;
  const { play, icons, iconSize } = layout.home;
  const placements = [];
  placements.push(placed(await sized(src('assets/rush/play.png'), play[2], play[3]), play[0] - play[2] / 2, play[1] - play[3] / 2));
  for (let i = 0; i < 3; i++) {
    const icon = [src('assets/rush/btn-sfx.png'), src('assets/rush/btn-ranking.png'), src('assets/rush/btn-music.png')][i];
    placements.push(await graphicAt(icon, icons[i][0], icons[i][1], iconSize));
  }
  base = await overlay(base, placements, w, h);
  return base;
}

async function listImages(directory) {
  const result = [];
  for (const f of await readdir(src(directory), { withFileTypes: true })) {
    if (f.isDirectory()) result.push(...await listImages(`${directory}/${f.name}`));
    else if (/\.(png|jpg|jpeg|webp)$/i.test(f.name)) result.push(`${directory}/${f.name}`);
  }
  return result;
}

async function listFiles(directory) {
  const files = [];
  for (const item of await readdir(src(directory), { withFileTypes: true })) {
    const path = `${directory}/${item.name}`;
    if (item.isDirectory()) files.push(...await listFiles(path));
    else if (item.isFile()) files.push(path);
  }
  return files.sort();
}

function category(path) {
  const b = basename(path).toLowerCase();
  if (path.includes('assets/rush/')) {
    if (b.startsWith('bg-')) return 'rush: backgrounds';
    if (b.startsWith('block-')) return 'rush: colored blocks';
    if (b.startsWith('btn-') || b === 'play.png') return 'rush: button icons';
    if (b.startsWith('crown')) return 'rush: crown / score';
    return 'rush: board / frame';
  }
  const sprite = manifest.find((m) => m.file === path);
  return sprite ? `game sprite: ${sprite.object}` : 'game sprite: auxiliary';
}

async function makeInventory() {
  const imageFiles = [...await listImages('assets/rush'), ...await listImages('assets/sprites-named')].sort();
  const sprites = imageFiles.map((file) => manifest.filter((m) => m.file === file).map((m) => `${m.object}[${m.frame}]`));
  const entries = [];
  for (let i = 0; i < imageFiles.length; i++) {
    const f = imageFiles[i];
    const bytes = await readFile(src(f));
    const meta = await sharp(bytes).metadata();
    entries.push({ path: f, width: meta.width, height: meta.height, bytes: bytes.length, sha256: createHash('sha256').update(bytes).digest('hex'), usage: category(f), objects: sprites[i] });
  }
  const audio = await listFiles('assets/audio');
  const fonts = await listFiles('assets/fonts');
  const summary = {
    images: entries.length, rushImages: entries.filter((e) => e.path.startsWith('assets/rush/')).length,
    namedSpriteImages: entries.filter((e) => e.path.startsWith('assets/sprites-named/')).length,
    audioFiles: audio.length, fontFiles: fonts.length,
    manifestObjects: [...new Set(manifest.map((m) => m.object))].sort(),
    variants: formats.map(({ name, w, h }) => ({ name, width: w, height: h })),
  };
  await writeFile(join(out, 'inventory.json'), JSON.stringify({ summary, entries, audio, fonts }, null, 2) + '\n');
  return { summary, entries };
}

async function catalog(entries) {
  const ncol = 8, cellW = 200, cellH = 205, nrow = Math.ceil(entries.length / ncol);
  const w = ncol * cellW, h = nrow * cellH + 80;
  const pieces = [];
  for (const [index, item] of entries.entries()) {
    const i = index % ncol, j = Math.floor(index / ncol), x = i * cellW, y = j * cellH + 80;
    const thumb = await sharp(src(item.path)).resize(150, 150, { fit: 'contain', background: '#101d4e' }).png().toBuffer();
    pieces.push(placed(thumb, x + 25, y + 3));
  }
  const labels = entries.map((entry, index) => {
    const x = (index % ncol) * cellW + 100, y = Math.floor(index / ncol) * cellH + 80 + 171;
    const name = basename(entry.path);
    const short = name.length > 24 ? `${name.slice(0, 21)}…` : name;
    return `<text x="${x}" y="${y}" text-anchor="middle" font-size="16" fill="#F3F5FF">${esc(short)}</text><text x="${x}" y="${y + 18}" text-anchor="middle" font-size="12" fill="#A6B9DB">${entry.width}×${entry.height}</text>`;
  });
  pieces.push({ input: svg(w, h, `<text x="30" y="48" font-size="36" font-weight="bold" font-family="sans-serif" fill="#FFF">BLOCK RUSH — original sprite inventory (${entries.length})</text>${labels.join('')}`), left: 0, top: 0 });
  const sheet = await overlay(await sharp({ create: { width: w, height: h, channels: 3, background: '#101d4e' } }).png().toBuffer(), pieces, w, h);
  await sharp(sheet).webp({ quality: 87 }).toFile(join(out, 'catalog.webp'));
}

async function verifyPack() {
  const inventory = JSON.parse(await readFile(join(out, 'inventory.json'), 'utf8'));
  let count = 0;
  for (const item of inventory.entries) {
    const contents = await readFile(src(item.path));
    const hash = createHash('sha256').update(contents).digest('hex');
    if (hash !== item.sha256) throw new Error(`Original source was modified: ${item.path}`);
    count++;
  }
  for (const fmt of formats) {
    for (const family of ['previews', 'backgrounds']) {
      for (const scene of ['game', 'home']) {
        const file = join(out, family, `${scene}-${fmt.name}-${fmt.w}x${fmt.h}.webp`);
        const { width, height } = await sharp(file).metadata();
        if (width !== fmt.w || height !== fmt.h) {
          throw new Error(`Bad resolution ${file}: ${width}x${height}`);
        }
        count++;
      }
    }
  }
  console.log(`PASS — ${count} checks: 100 original asset SHA256 + 24 export sizes`);
}

if (process.argv.includes('--verify')) {
  await verifyPack();
  process.exit(0);
}

for (const d of [out, join(out, 'previews'), join(out, 'backgrounds')]) await mkdir(d, { recursive: true });
const { summary, entries } = await makeInventory();
console.log('Inventory:', summary);
await catalog(entries);
if (process.argv.includes('--inventory-only')) {
  console.log('Inventory and sprite contact sheet updated.');
  process.exit(0);
}
const board = await boardLayer();

for (const [key, layout] of Object.entries(layouts)) {
  console.log(`Rendering base ${key}: ${layout.w}×${layout.h}`);
  const game = await gamePreview(layout, key, board);
  const home = await homePreview(layout, key);
  const gameBackground = await background('game', layout, key);
  const homeBackground = await background('home', layout, key);
  for (const fmt of formats.filter((f) => f.key === key)) {
    const w = fmt.w, h = fmt.h;
    const resized = async (buffer) => fmt.upscale ? sharp(buffer).resize(w, h, { kernel: 'lanczos3' }) : sharp(buffer);
    for (const [scene, buffer] of [['game', game], ['home', home]]) {
      const file = join(out, 'previews', `${scene}-${fmt.name}-${w}x${h}.webp`);
      await (await resized(buffer)).webp({ quality: 92, effort: 5 }).toFile(file);
      console.log('  preview', relative(root, file));
    }
    for (const [scene, buffer] of [['game', gameBackground], ['home', homeBackground]]) {
      const file = join(out, 'backgrounds', `${scene}-${fmt.name}-${w}x${h}.webp`);
      await (await resized(buffer)).webp({ quality: 92, effort: 5 }).toFile(file);
    }
  }
}
await writeFile(join(out, 'README.md'), [
  '# Block Rush — six responsive artwork resolutions',
  '',
  'Generated using `node scripts/build_resolution_pack.mjs` (requires Node >=20 and sharp).',
  '',
  '| Name | Exact pixels | Preview gameplay | Preview home | Backgrounds |',
  '| --- | --- | --- | --- | --- |',
  ...formats.map((f) => `| ${f.name} | ${f.w}×${f.h} | [game](previews/game-${f.name}-${f.w}x${f.h}.webp) | [home](previews/home-${f.name}-${f.w}x${f.h}.webp) | [game](backgrounds/game-${f.name}-${f.w}x${f.h}.webp), [home](backgrounds/home-${f.name}-${f.w}x${f.h}.webp) |`),
  '',
  '## Fidelity and scope',
  '',
  '- All colored blocks, source board/frame, controls, crown and logo are resampled from original repository files (sha256 in `inventory.json`).',
  '- Board cell interiors are regenerated from the **actual** Flutter renderer math/gradient (not from AI imitation).',
  '- Portrait coordinates follow `lib/game/layout_constants.dart` exactly; horizontal and square layouts reflow HUD/tray without distorting the game board.',
  '- The widescreen decorative background **edges** are AI-assisted and the original center artwork is composited back on top. Original assets remain untouched.',
  '- 4K files have exact 4K dimensions, but their pixel detail is upscaled from lower-resolution originals; they are not native-4K illustrations.',
  '- These files are STATIC previews and bitmap backdrops, not Flutter gameplay screenshots, running app viewport changes, or separate APK/Steam builds.',
  '- `catalog.webp` and `inventory.json` cover every image, and the JSON includes all original filenames, dimensions, manifest object usages and SHA256.',
  '- No licensed content ownership is implied; rights must be checked before public distribution.',
  '',
  'The next production step is to apply the same landscape/square layout transforms to the running Flame canvas AND pointer-hit-test input, then test on real displays.',
  '',
].join('\n'));
console.log('Done:', out);
