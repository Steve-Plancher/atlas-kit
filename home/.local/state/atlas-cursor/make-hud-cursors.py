#!/usr/bin/env python3
"""Build the animated A.T.L.A.S HUD cursors (Xcursor).

Shapes share one visual language: deep-blue outline, dim ring, a bright cyan
element that sweeps, and an ice-white core. All of them point from their
CENTRE, so the hotspot is always size/2.

  reticle  hexagon ring + sweeping arc + pulsing crosshair   -> default (pointer)
  link     hexagon ring + sweeping arc + expanding pulse     -> pointer (hand)
  text     I-beam with brackets + a tick sliding along it    -> text (xterm)

  ./make-hud-cursors.py OUTDIR [shape ...]     default: all three

Supersedes make-hex-pointer.py (same reticle output).
"""
import math
import os
import shutil
import subprocess
import sys
import tempfile

FRAMES = 24
DELAY_MS = 60
SIZES = [24, 32, 48, 64]

OUTLINE = "#04263d"
RING = "#1478e6"
SWEEP = "#35c4ff"
GLOW = "#a8ecff"

HEX = [(48, 8), (82, 28), (82, 68), (48, 88), (14, 68), (14, 28)]


def hex_path():
    return "M" + " L".join("%g,%g" % p for p in HEX) + " Z"


def hex_perimeter():
    return sum(math.hypot(HEX[(i + 1) % len(HEX)][0] - HEX[i][0],
                          HEX[(i + 1) % len(HEX)][1] - HEX[i][1])
               for i in range(len(HEX)))


def svg(body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" '
            'viewBox="0 0 96 96">%s</svg>' % body)


def hex_ring(i):
    """Dim hexagon with the bright arc swept by dash offset (not rotation)."""
    per = hex_perimeter()
    dash = per / 4.0
    offset = -per * (i / FRAMES)
    return f"""
  <path d="{hex_path()}" stroke="{OUTLINE}" stroke-width="13"/>
  <path d="{hex_path()}" stroke="{RING}" stroke-width="6" opacity="0.75"/>
  <path d="{hex_path()}" stroke="{SWEEP}" stroke-width="7"
        stroke-dasharray="{dash:.2f} {per - dash:.2f}" stroke-dashoffset="{offset:.2f}"/>"""


def frame_reticle(i):
    pulse = 0.55 + 0.45 * (0.5 + 0.5 * math.cos(2 * math.pi * i / FRAMES))
    arm = 8 + 3 * pulse
    return svg(f"""<g fill="none" stroke-linejoin="round" stroke-linecap="round">{hex_ring(i)}
  <path d="M{48 - arm},48 L{48 + arm},48 M48,{48 - arm} L48,{48 + arm}"
        stroke="{OUTLINE}" stroke-width="10"/>
  <path d="M{48 - arm},48 L{48 + arm},48 M48,{48 - arm} L48,{48 + arm}"
        stroke="{GLOW}" stroke-width="4" opacity="{0.5 + 0.5 * pulse:.2f}"/>
 </g>""")


def frame_link(i):
    # A ping expanding out of the centre: reads as "activate this".
    t = i / FRAMES
    r = 5 + 20 * t
    fade = max(0.0, 1.0 - t)
    return svg(f"""<g fill="none" stroke-linejoin="round" stroke-linecap="round">{hex_ring(i)}
  <circle cx="48" cy="48" r="{r:.1f}" stroke="{GLOW}" stroke-width="{2 + 3 * fade:.1f}"
          opacity="{0.85 * fade:.2f}"/>
 </g>
 <circle cx="48" cy="48" r="7" fill="{GLOW}" stroke="{OUTLINE}" stroke-width="4"/>""")


def frame_text(i):
    # I-beam: fixed brackets, a bright tick sliding down the stem, soft pulse.
    top, bottom = 16, 80
    t = i / FRAMES
    tick = top + (bottom - top) * t
    pulse = 0.6 + 0.4 * (0.5 + 0.5 * math.cos(2 * math.pi * i / FRAMES))
    return svg(f"""<g fill="none" stroke-linecap="round">
  <path d="M48,{top} L48,{bottom} M34,{top} L62,{top} M34,{bottom} L62,{bottom}"
        stroke="{OUTLINE}" stroke-width="14"/>
  <path d="M34,{top} L62,{top} M34,{bottom} L62,{bottom}" stroke="{SWEEP}" stroke-width="7"/>
  <path d="M48,{top} L48,{bottom}" stroke="{RING}" stroke-width="6" opacity="0.8"/>
  <path d="M48,{max(top, tick - 9):.1f} L48,{min(bottom, tick + 9):.1f}"
        stroke="{GLOW}" stroke-width="6" opacity="{pulse:.2f}"/>
 </g>""")


SHAPES = {"reticle": frame_reticle, "link": frame_link, "text": frame_text}


def build(shape, out):
    maker = SHAPES[shape]
    work = tempfile.mkdtemp(prefix="atlas-cur-")
    try:
        conf = []
        for size in SIZES:
            hot = size // 2
            for i in range(FRAMES):
                svg_path = os.path.join(work, "%s%d_%02d.svg" % (shape, size, i))
                png_path = svg_path[:-4] + ".png"
                with open(svg_path, "w") as f:
                    f.write(maker(i))
                subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size),
                                svg_path, "-o", png_path], check=True)
                conf.append("%d %d %d %s %d" % (size, hot, hot, png_path, DELAY_MS))
        conf_path = os.path.join(work, "cursor.conf")
        with open(conf_path, "w") as f:
            f.write("\n".join(conf) + "\n")
        subprocess.run(["xcursorgen", conf_path, out], check=True)
        print("wrote %s (%s, %d frames x %d sizes)" % (out, shape, FRAMES, len(SIZES)))
    finally:
        shutil.rmtree(work, ignore_errors=True)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    outdir = os.path.abspath(sys.argv[1])
    shapes = sys.argv[2:] or list(SHAPES)
    for tool in ("rsvg-convert", "xcursorgen"):
        if not shutil.which(tool):
            sys.exit("missing %s" % tool)
    os.makedirs(outdir, exist_ok=True)
    # File names match the Xcursor names the theme's symlinks already point at.
    targets = {"reticle": "default", "link": "pointer", "text": "text"}
    for shape in shapes:
        build(shape, os.path.join(outdir, targets[shape]))


if __name__ == "__main__":
    main()
