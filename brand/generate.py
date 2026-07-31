#!/usr/bin/env python3
"""Generate every KASBON brand asset from the geometry in `geometry.py`.

Run from anywhere:

    python3 brand/generate.py

Writes the SVG masters into `brand/` and rasterises them into the platform
slots under `app/`. It is idempotent — the icons in the repo are outputs, so
edit `geometry.py` and re-run rather than retouching a PNG.

Requires Pillow and fontTools, and Google Chrome (the only vector rasteriser on
a stock macOS box). See `brand/README.md`.
"""

from pathlib import Path

from PIL import Image

import geometry as G
from render import emit, master
from wordmark import wordmark

ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / "brand"
APP = ROOT / "app"

# How much of a tile's height the glyph inks. 0.50 fills the tile confidently
# without crowding the corners; see brand/README.md.
TILE_FRAC = 0.50

# Maskable (PWA) and adaptive (Android) art is cropped by a mask the platform
# chooses, so the glyph pulls back inside the guaranteed-visible zone: a circle
# of 80% diameter for maskable, the central 66 of 108dp for adaptive.
MASKABLE_FRAC = 0.40
ADAPTIVE_FRAC = 0.42

# macOS draws icons on its own grid, with the art inset from the tile's edge.
MACOS_FRAC = 0.82

DENSITIES = {           # Android suffix -> scale factor
    "mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4,
}

# Every iOS slot named by the existing Contents.json, mapped to its pixel size.
IOS_ICONS = {
    "Icon-App-20x20@1x.png": 20, "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60, "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58, "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40, "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120, "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180, "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152, "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

MACOS_ICONS = [16, 32, 64, 128, 256, 512, 1024]
WINDOWS_ICO = [16, 24, 32, 48, 64, 128, 256]


# ---------------------------------------------------------------------------
# SVG masters
# ---------------------------------------------------------------------------
def mark_svg(colour: str) -> str:
    """The bare glyph on a transparent, tightly-cropped canvas."""
    x0, y0, x1, y1 = G.GLYPH_BBOX
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" '
        f'viewBox="{x0:g} {y0:g} {G.GLYPH_W:g} {G.GLYPH_H:g}" '
        f'width="{G.GLYPH_W:g}" height="{G.GLYPH_H:g}">{G.glyph(colour)}</svg>'
    )


def adaptive_foreground_svg() -> str:
    return G.svg(432, G.place(432, ADAPTIVE_FRAC, "#fff"))


def adaptive_background_svg() -> str:
    return G.svg(
        432, '<rect width="432" height="432" fill="url(#g)"/>', G.gradient_def()
    )


def macos_svg() -> str:
    """The rounded tile inset on a transparent canvas, per the macOS grid."""
    canvas, art = 1024.0, 1024.0 * MACOS_FRAC
    off = (canvas - art) / 2
    rx = art * G.CORNER_FRAC
    body = (
        f'<g transform="translate({off:g},{off:g})">'
        f'<rect width="{art:g}" height="{art:g}" rx="{rx:g}" fill="url(#g)"/>'
        f"{G.place(art, TILE_FRAC)}</g>"
    )
    return G.svg(canvas, body, G.gradient_def())


def wordmark_svg() -> str:
    body, w, h = wordmark(100.0, G.PRIMARY)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w:.2f} {h:.2f}" '
        f'width="{w:.2f}" height="{h:.2f}">{body}</svg>'
    )


def lockup_svg(stacked: bool) -> str:
    """Mark plus wordmark.

    The gap between the two is a third of the tile, comfortably clear of the
    quarter-tile minimum in `docs/BRAND.md`. Baking it in means the lockup you
    get by default is already a correct one.
    """
    tile = 200.0
    gap = tile * 0.32
    cap = tile * 0.34
    body, w, _ = wordmark(cap, G.PRIMARY)
    rx = tile * G.CORNER_FRAC
    art = (
        f'<rect width="{tile:g}" height="{tile:g}" rx="{rx:g}" fill="url(#g)"/>'
        f"{G.place(tile, TILE_FRAC)}"
    )

    if stacked:
        cw, ch = max(tile, w), tile + gap + cap
        parts = (
            f'<g transform="translate({(cw - tile) / 2:.2f},0)">{art}</g>'
            f'<g transform="translate({(cw - w) / 2:.2f},{tile + gap:.2f})">{body}</g>'
        )
    else:
        cw, ch = tile + gap + w, tile
        # Optically centre the caps against the tile rather than the box.
        parts = (
            f"{art}"
            f'<g transform="translate({tile + gap:.2f},{(tile - cap) / 2:.2f})">'
            f"{body}</g>"
        )

    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {cw:.2f} {ch:.2f}" '
        f'width="{cw:.2f}" height="{ch:.2f}">'
        f"<defs>{G.gradient_def()}</defs>{parts}</svg>"
    )


MASTERS = {
    "kasbon-mark.svg": lambda: mark_svg(G.PRIMARY),
    "kasbon-mark-white.svg": lambda: mark_svg("#fff"),
    "kasbon-icon.svg": lambda: G.tile(512, TILE_FRAC, rounded=True),
    "kasbon-icon-square.svg": lambda: G.tile(1024, TILE_FRAC, rounded=False),
    "kasbon-icon-maskable.svg": lambda: G.tile(1024, MASKABLE_FRAC, rounded=False),
    "kasbon-adaptive-foreground.svg": adaptive_foreground_svg,
    "kasbon-adaptive-background.svg": adaptive_background_svg,
    "kasbon-icon-macos.svg": macos_svg,
    "kasbon-wordmark.svg": wordmark_svg,
    "kasbon-logo-horizontal.svg": lambda: lockup_svg(stacked=False),
    "kasbon-logo-stacked.svg": lambda: lockup_svg(stacked=True),
}


# ---------------------------------------------------------------------------
# Rasterisation
# ---------------------------------------------------------------------------
def flatten(im: Image.Image) -> Image.Image:
    """Drop the alpha channel onto white.

    The App Store rejects an icon with an alpha channel outright, even a fully
    opaque one.
    """
    bg = Image.new("RGB", im.size, "#FFFFFF")
    bg.paste(im, mask=im.split()[-1])
    return bg


def main() -> None:
    BRAND.mkdir(exist_ok=True)
    for name, build in MASTERS.items():
        (BRAND / name).write_text(build() + "\n")
    print(f"svg      {len(MASTERS)} masters -> brand/")

    rounded = master(BRAND / "kasbon-icon.svg")
    square = master(BRAND / "kasbon-icon-square.svg")
    maskable = master(BRAND / "kasbon-icon-maskable.svg")
    fg = master(BRAND / "kasbon-adaptive-foreground.svg")
    bg = master(BRAND / "kasbon-adaptive-background.svg")
    mac = master(BRAND / "kasbon-icon-macos.svg")

    # --- web ---
    web = APP / "web"
    emit(rounded, web / "favicon.png", 32)
    (web / "favicon.svg").write_text((BRAND / "kasbon-icon.svg").read_text())
    for size in (192, 512):
        emit(rounded, web / f"icons/Icon-{size}.png", size)
        emit(maskable, web / f"icons/Icon-maskable-{size}.png", size)
    # Apple home screens do not round a touch icon that already has corners,
    # and they never composite alpha — so this slot is square and opaque.
    apple = web / "icons/apple-touch-icon-180.png"
    apple.parent.mkdir(parents=True, exist_ok=True)
    flatten(square.resize((180, 180), Image.LANCZOS)).save(apple)
    print("web      favicon, PWA icons, apple-touch-icon")

    # --- android ---
    res = APP / "android/app/src/main/res"
    for suffix, factor in DENSITIES.items():
        d = res / f"mipmap-{suffix}"
        emit(rounded, d / "ic_launcher.png", round(48 * factor))
        emit(fg, d / "ic_launcher_foreground.png", round(108 * factor))
        emit(bg, d / "ic_launcher_background.png", round(108 * factor))
        emit(fg, d / "ic_launcher_monochrome.png", round(108 * factor))
    anydpi = res / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@mipmap/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>\n'
        "</adaptive-icon>\n"
    )
    print(f"android  {len(DENSITIES)} densities, adaptive + monochrome")

    # --- ios ---
    ios = APP / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for name, size in IOS_ICONS.items():
        flatten(square.resize((size, size), Image.LANCZOS)).save(ios / name)
    print(f"ios      {len(IOS_ICONS)} slots, opaque")

    # --- macos ---
    mac_dir = APP / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    for size in MACOS_ICONS:
        emit(mac, mac_dir / f"app_icon_{size}.png", size)
    print(f"macos    {len(MACOS_ICONS)} slots")

    # --- windows ---
    ico = APP / "windows/runner/resources/app_icon.ico"
    rounded.resize((256, 256), Image.LANCZOS).save(
        ico, sizes=[(s, s) for s in WINDOWS_ICO]
    )
    print(f"windows  app_icon.ico, {len(WINDOWS_ICO)} sizes")


if __name__ == "__main__":
    main()
