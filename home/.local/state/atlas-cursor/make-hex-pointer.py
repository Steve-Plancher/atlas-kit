#!/usr/bin/env python3
"""Build the animated A.T.L.A.S hex-scanner pointer (Xcursor).

A dim hexagon ring stays put; a bright cyan arc sweeps around it and the centre
crosshair pulses. Frames are SVG -> PNG (rsvg-convert) -> one Xcursor file
(xcursorgen). The hotspot is the CENTRE of the reticle, not a tip.

  ./make-hex-pointer.py [out_file]        default: ./left_ptr
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
VIEW = 96.0

OUTLINE = "#04263d"
RING = "#1478e6"
SWEEP = "#35c4ff"
GLOW = "#a8ecff"

# Hexagon (flat-ish, pointy top/bottom) inside the 96px box.
HEX = [(48, 8), (82, 28), (82, 68), (48, 88), (14, 68), (14, 28)]


def hex_path():
    return "M" + " L".join("%g,%g" % p for p in HEX) + " Z"


def perimeter():
    total = 0.0
    for i in range(len(HEX)):
        x1, y1 = HEX[i]
        x2, y2 = HEX[(i + 1) % len(HEX)]
        total += math.hypot(x2 - x1, y2 - y1)
    return total


def frame_svg(i):
    per = perimeter()
    # Bright arc is ~1.5 hex edges long, sweeping once per loop.
    dash = per / 4.0
    offset = -per * (i / FRAMES)
    # Centre crosshair breathes with the sweep.
    pulse = 0.55 + 0.45 * (0.5 + 0.5 * math.cos(2 * math.pi * i / FRAMES))
    cross = 8 + 3 * pulse
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96">
 <g fill="none" stroke-linejoin="round" stroke-linecap="round">
  <path d="{hex_path()}" stroke="{OUTLINE}" stroke-width="13"/>
  <path d="{hex_path()}" stroke="{RING}" stroke-width="6" opacity="0.75"/>
  <path d="{hex_path()}" stroke="{SWEEP}" stroke-width="7"
        stroke-dasharray="{dash:.2f} {per - dash:.2f}" stroke-dashoffset="{offset:.2f}"/>
  <path d="M{48 - cross},48 L{48 + cross},48 M48,{48 - cross} L48,{48 + cross}"
        stroke="{OUTLINE}" stroke-width="10"/>
  <path d="M{48 - cross},48 L{48 + cross},48 M48,{48 - cross} L48,{48 + cross}"
        stroke="{GLOW}" stroke-width="4" opacity="{0.5 + 0.5 * pulse:.2f}"/>
 </g>
</svg>"""


def main():
    out = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else "left_ptr")
    for tool in ("rsvg-convert", "xcursorgen"):
        if not shutil.which(tool):
            sys.exit("missing %s" % tool)

    work = tempfile.mkdtemp(prefix="atlas-hex-")
    try:
        conf = []
        for size in SIZES:
            hot = size // 2
            for i in range(FRAMES):
                svg = os.path.join(work, "f%d_%02d.svg" % (size, i))
                png = os.path.join(work, "f%d_%02d.png" % (size, i))
                with open(svg, "w") as f:
                    f.write(frame_svg(i))
                subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size),
                                svg, "-o", png], check=True)
                conf.append("%d %d %d %s %d" % (size, hot, hot, png, DELAY_MS))
        conf_path = os.path.join(work, "cursor.conf")
        with open(conf_path, "w") as f:
            f.write("\n".join(conf) + "\n")
        subprocess.run(["xcursorgen", conf_path, out], check=True)
        print("wrote %s (%d frames x %d sizes)" % (out, FRAMES, len(SIZES)))
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main()
