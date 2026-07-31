# brand/

The KASBON mark, and the pipeline that turns it into every icon the project
ships.

**The icons under `app/` are build outputs.** Do not retouch a PNG — edit the
geometry and re-run the generator, or the next run will overwrite you.

```bash
python3 brand/generate.py
```

## What it needs

| Requirement | Why |
|---|---|
| Python 3.10+ with `Pillow` and `fontTools` | resampling; outlining the wordmark |
| Google Chrome at `/Applications/Google Chrome.app` | the only SVG rasteriser on a stock macOS box |

`render.py` drives Chrome headless because macOS ships no `rsvg-convert`,
ImageMagick or Inkscape. Each artwork is rasterised once at 1024px and reduced
with Lanczos for every delivered size — a Chrome launch costs seconds, so
per-size shelling out would make a full run minutes long instead of one.

## Layout

| File | Role |
|---|---|
| `geometry.py` | the glyph, the palette, the tile. **The source of truth.** |
| `wordmark.py` | `KASBON` outlined from Plus Jakarta Sans ExtraBold |
| `generate.py` | composes the masters, writes them into every platform slot |
| `render.py` | the Chrome rasteriser |
| `kasbon-*.svg` | generated masters — also outputs, also not hand-edited |

## The masters

| File | Used for |
|---|---|
| `kasbon-mark.svg` / `kasbon-mark-white.svg` | the bare glyph, tightly cropped |
| `kasbon-icon.svg` | rounded tile — PWA, Windows, favicon |
| `kasbon-icon-square.svg` | full-bleed square — iOS, which masks its own corners |
| `kasbon-icon-maskable.svg` | PWA maskable, glyph pulled into the 80% safe circle |
| `kasbon-adaptive-foreground/background.svg` | Android adaptive layers |
| `kasbon-icon-macos.svg` | inset on the macOS icon grid |
| `kasbon-wordmark.svg` | the wordmark alone |
| `kasbon-logo-horizontal/stacked.svg` | the lockups — decks, README, the web |

## Where the output lands

- `app/web/` — `favicon.png`, `favicon.svg`, PWA icons, `apple-touch-icon-180.png`
- `app/android/app/src/main/res/mipmap-*/` — legacy launcher, adaptive
  foreground/background/monochrome, and `mipmap-anydpi-v26/ic_launcher.xml`
- `app/ios/Runner/Assets.xcassets/AppIcon.appiconset/` — 15 slots, **flattened
  to RGB**: the App Store rejects an icon carrying an alpha channel, even an
  opaque one
- `app/macos/Runner/Assets.xcassets/AppIcon.appiconset/` — 7 slots
- `app/windows/runner/resources/app_icon.ico` — 7 sizes in one `.ico`

## Two things that must stay in step

The mark is drawn twice. `geometry.py` draws it for the icons;
`app/lib/shared/brand/kasbon_mark.dart` redraws it as a `CustomPainter` for the
running app, so the logo inside the app is crisp at any size and can be tinted
without shipping a PNG ladder. Change one, change the other.

`app/test/widget/shared/brand/kasbon_mark_test.dart` pins the constants they
share — the glyph's aspect ratio, the corner fraction, the glyph's share of the
tile. It cannot catch a changed *path*, so re-run `generate.py` and look at the
result whenever you touch `STEM_PATH` or the arms.

Design rationale, clear space and misuse rules: `docs/BRAND.md`.
