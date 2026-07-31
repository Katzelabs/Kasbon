"""The KASBON mark, defined once.

Every icon this repo ships — Android, iOS, macOS, Windows, web, PWA — is a
placement of the single glyph described here. Nothing downstream redraws it, so
a change to these constants moves every asset at once.

The mark is a geometric `K` whose stem is a receipt slip torn off at the foot:
the paper *kasbon* the app replaces. The tear is deliberately small. At a phone
home-screen size it is a texture you notice on a second look, and by 16px it has
dissolved into a plain stem — which is the point. The mark had to stay a legible
`K` at favicon size, so the storytelling detail is the part allowed to vanish.
"""

# ---------------------------------------------------------------------------
# Palette — mirrors AppColors in app/lib/config/theme/app_colors.dart.
# ---------------------------------------------------------------------------
BLUE_LIGHT = "#3B82F6"  # AppColors.primaryHover — gradient start
BLUE_DARK = "#1D4ED8"   # AppColors.primaryDark  — gradient end
PRIMARY = "#2563EB"     # AppColors.primary      — flat/one-colour uses
INK = "#1F2937"         # AppColors.textPrimary  — wordmark on light ground

# ---------------------------------------------------------------------------
# Glyph
# ---------------------------------------------------------------------------
# Authoring box. Coordinates below are in this space; every consumer scales.
GLYPH_BOX = 120.0

# Stroke weight of the two arms. The stem is drawn as a filled outline instead
# of a stroke because its foot is torn rather than capped, so its width is
# spelled out separately and must match: 43 - 24 == 19.
ARM_WEIGHT = 19.0
_CAP = ARM_WEIGHT / 2  # round caps extend this far past a path endpoint

# The stem: rounded at the top like a stroke cap, torn across the bottom into
# two teeth. Drawn as one closed path so the tear is part of the silhouette and
# survives being filled, scaled, or knocked out of a mask.
STEM_PATH = (
    "M 33.5 27 A 9.5 9.5 0 0 1 43 36.5 V 93 "
    "L 38.25 102.5 L 33.5 93 L 28.75 102.5 L 24 93 "
    "V 36.5 A 9.5 9.5 0 0 1 33.5 27 Z"
)

# The arms, as round-capped strokes. The upper arm rises past the stem's
# shoulder; that overshoot is what keeps the mark from reading as a flat letter.
ARM_UPPER = ((49.0, 63.0), (87.0, 27.0))
ARM_LOWER = ((49.0, 67.0), (87.0, 95.0))

# Inked extent of the assembled glyph, in authoring units.
#
# A round-capped straight stroke's outline is the convex hull of the circles at
# its two endpoints, so the arms' bounds are exact rather than approximated.
# Placement scales and centres on this box, never on GLYPH_BOX — the glyph is
# not centred in its authoring square and never was.
def _glyph_bbox() -> tuple[float, float, float, float]:
    xs = [24.0, 43.0]          # stem
    ys = [27.0, 102.5]
    for (x0, y0), (x1, y1) in (ARM_UPPER, ARM_LOWER):
        xs += [x0 - _CAP, x0 + _CAP, x1 - _CAP, x1 + _CAP]
        ys += [y0 - _CAP, y0 + _CAP, y1 - _CAP, y1 + _CAP]
    return min(xs), min(ys), max(xs), max(ys)


GLYPH_BBOX = _glyph_bbox()          # (24.0, 17.5, 96.5, 104.5)
GLYPH_W = GLYPH_BBOX[2] - GLYPH_BBOX[0]
GLYPH_H = GLYPH_BBOX[3] - GLYPH_BBOX[1]


def glyph(colour: str = "#fff") -> str:
    """The glyph's SVG elements, in authoring coordinates."""
    (ux0, uy0), (ux1, uy1) = ARM_UPPER
    (lx0, ly0), (lx1, ly1) = ARM_LOWER
    return (
        f'<path fill="{colour}" d="{STEM_PATH}"/>'
        f'<g fill="none" stroke="{colour}" stroke-width="{ARM_WEIGHT:g}"'
        f' stroke-linecap="round">'
        f'<path d="M {ux0:g} {uy0:g} L {ux1:g} {uy1:g}"/>'
        f'<path d="M {lx0:g} {ly0:g} L {lx1:g} {ly1:g}"/>'
        f"</g>"
    )


def place(canvas: float, height_frac: float, colour: str = "#fff") -> str:
    """The glyph centred on a `canvas`-square, inked `height_frac` of it tall.

    Sizing is by height because the mark is taller than it is wide; driving it
    from width would make it tower out of the tile.
    """
    scale = (canvas * height_frac) / GLYPH_H
    cx = (GLYPH_BBOX[0] + GLYPH_BBOX[2]) / 2
    cy = (GLYPH_BBOX[1] + GLYPH_BBOX[3]) / 2
    tx = canvas / 2 - cx * scale
    ty = canvas / 2 - cy * scale
    return (
        f'<g transform="translate({tx:.4f},{ty:.4f}) scale({scale:.6f})">'
        f"{glyph(colour)}</g>"
    )


# ---------------------------------------------------------------------------
# Backgrounds
# ---------------------------------------------------------------------------
# The corner radius Apple's squircle approximates and Android's mask expects:
# a shade under a quarter of the side.
CORNER_FRAC = 112.0 / 512.0


def gradient_def(ident: str = "g") -> str:
    """The brand gradient, running top-left to bottom-right."""
    return (
        f'<linearGradient id="{ident}" x1="0" y1="0" x2="1" y2="1">'
        f'<stop offset="0" stop-color="{BLUE_LIGHT}"/>'
        f'<stop offset="1" stop-color="{BLUE_DARK}"/>'
        f"</linearGradient>"
    )


def svg(canvas: float, body: str, defs: str = "") -> str:
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {canvas:g} {canvas:g}"'
        f' width="{canvas:g}" height="{canvas:g}">'
        f"{f'<defs>{defs}</defs>' if defs else ''}{body}</svg>"
    )


def tile(canvas: float, height_frac: float, rounded: bool) -> str:
    """A gradient app tile carrying the glyph in white.

    `rounded` bakes the corner radius in. iOS and Android mask icons themselves
    and are handed the square; anything rendered as-is — PWA, Windows, the
    in-repo lockup — gets the corners baked, because nothing else will round
    them.
    """
    rx = f' rx="{canvas * CORNER_FRAC:g}"' if rounded else ""
    body = (
        f'<rect width="{canvas:g}" height="{canvas:g}"{rx} fill="url(#g)"/>'
        f"{place(canvas, height_frac)}"
    )
    return svg(canvas, body, gradient_def())
