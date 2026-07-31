#!/usr/bin/env python3
"""Rasterize an SVG to PNG at an exact pixel size using headless Chrome.

Chrome is the only vector rasterizer on this machine, and it screenshots a
viewport rather than a drawing, so the SVG is wrapped in a page whose body IS
the target box. Rendering at 4x and downsampling with Lanczos gives edges that
Chrome's own antialiasing does not at small sizes.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
MASTER = 1024  # every size is a Lanczos reduction of one master render


def master(svg_path: Path, pad: float = 0.0, px: int = MASTER) -> Image.Image:
    """Rasterize `svg_path` once, large.

    A Chrome launch costs seconds, so callers render one master per artwork and
    downsample it for every delivered size rather than shelling out per size.

    `pad` insets the artwork by that fraction of the box on every side, which
    is how the Android adaptive foreground gets its 33% safe-area margin.
    """
    inner = 100 * (1 - 2 * pad)

    svg = svg_path.read_text()
    html = f"""<!doctype html><meta charset=utf-8>
<style>
  html,body {{ margin:0; padding:0; background:transparent; }}
  body {{ width:{px}px; height:{px}px; position:relative; overflow:hidden; }}
  #a {{ position:absolute; left:{pad * 100}%; top:{pad * 100}%;
        width:{inner}%; height:{inner}%; }}
  #a svg {{ width:100%; height:100%; display:block; }}
</style><div id=a>{svg}</div>"""

    with tempfile.TemporaryDirectory() as tmp:
        page = Path(tmp) / "page.html"
        page.write_text(html)
        shot = Path(tmp) / "shot.png"
        subprocess.run(
            [
                CHROME, "--headless", "--disable-gpu", "--no-sandbox",
                "--hide-scrollbars", "--default-background-color=00000000",
                "--force-device-scale-factor=1",
                f"--screenshot={shot}", f"--window-size={px},{px}",
                page.as_uri(),
            ],
            check=True, capture_output=True,
        )
        return Image.open(shot).convert("RGBA")


def emit(src: Image.Image, out_path: Path, size: int) -> None:
    """Write `src` reduced to `size`x`size`."""
    out_path.parent.mkdir(parents=True, exist_ok=True)
    im = src if src.size == (size, size) else src.resize((size, size), Image.LANCZOS)
    im.save(out_path)


if __name__ == "__main__":
    emit(master(Path(sys.argv[1]),
                float(sys.argv[4]) if len(sys.argv) > 4 else 0.0),
         Path(sys.argv[2]), int(sys.argv[3]))
