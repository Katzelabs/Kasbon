"""The KASBON wordmark, converted from Plus Jakarta Sans to outlines.

A logo that references a font by name is one missing font away from rendering as
Times New Roman, so the wordmark ships as paths. The source is the ExtraBold
weight already bundled with the app, which is why the lockup and the in-app
`KASBON` set in `AppTextStyles` are the same letterforms rather than two things
that merely look alike.
"""

from pathlib import Path

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.ttLib import TTFont

FONT = Path(__file__).resolve().parents[1] / (
    "app/assets/fonts/PlusJakartaSans-ExtraBold.ttf"
)
TEXT = "KASBON"

# Tracking, in ems. The wordmark is set all-caps at large sizes, where the
# default fit is too tight; this matches the `letterSpacing: 2` the auth header
# has always applied to the same word.
TRACKING = 0.09


def wordmark(cap_height: float, colour: str) -> tuple[str, float, float]:
    """Return (svg fragment, width, height) for the wordmark.

    The fragment sits on a box whose top-left is the origin and whose height is
    exactly the cap height — caps have no descenders and no overshoot here, so
    the drawn ink and the box agree, and callers can align to it directly.
    """
    font = TTFont(FONT)
    upem = font["head"].unitsPerEm
    caps = font["OS/2"].sCapHeight
    glyphs = font.getGlyphSet()
    cmap = font.getBestCmap()

    scale = cap_height / caps
    track = TRACKING * upem

    parts, pen_x = [], 0.0
    for ch in TEXT:
        name = cmap[ord(ch)]
        pen = SVGPathPen(glyphs)
        glyphs[name].draw(pen)
        d = pen.getCommands()
        if d:
            parts.append(f'<path transform="translate({pen_x:.2f},0)" d="{d}"/>')
        pen_x += glyphs[name].width + track
    pen_x -= track  # no tracking hangs off the final letter

    # Font space is Y-up with the baseline at 0; SVG is Y-down. Flipping and
    # dropping the origin by the cap height puts the caps' tops at y=0.
    body = (
        f'<g fill="{colour}" transform="translate(0,{cap_height:.4f}) '
        f'scale({scale:.6f},{-scale:.6f})">{"".join(parts)}</g>'
    )
    return body, pen_x * scale, cap_height
