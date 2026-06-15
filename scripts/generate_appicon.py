#!/usr/bin/env python3
"""
Generates the iOS app icon (1024x1024 PNG) for Musicarr with no third-party
image libraries — just the standard library. Renders the Musicarr brand mark
(an acid-lime rounded square with a dark inset slot) on the app's dark
background, with analytic anti-aliasing via a rounded-rectangle signed-distance
field.

    python3 scripts/generate_appicon.py
"""

import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Musicarr/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
SIZE = 1024

# Palette (matches Theme / web CSS variables)
BG       = (0x0B, 0x0C, 0x10)
LIME     = (0xC9, 0xF2, 0x4D)
INK      = (0x11, 0x14, 0x0A)

def clamp(x, lo, hi): return lo if x < lo else hi if x > hi else x

def rounded_rect_sdf(px, py, cx, cy, hx, hy, r):
    """Signed distance from point to a rounded rectangle (negative = inside)."""
    dx = abs(px - cx) - (hx - r)
    dy = abs(py - cy) - (hy - r)
    ax, ay = max(dx, 0.0), max(dy, 0.0)
    outside = (ax * ax + ay * ay) ** 0.5
    inside = min(max(dx, dy), 0.0)
    return outside + inside - r

def blend(dst, src, a):
    return tuple(int(round(dst[i] * (1 - a) + src[i] * a)) for i in range(3))

def render():
    s = SIZE
    # Brand mark geometry (centered). The lime square spans ~62% of the icon.
    cx = cy = s / 2.0
    sq_half = s * 0.31           # half-side of the lime square
    sq_r = sq_half * 0.42        # corner radius
    # Inset dark slot, proportioned like the web brand-mark ::after
    # (inset 6px/8px within a 20px square -> 0.3 / 0.4 of the side).
    bar_hx = sq_half * (1 - 2 * 0.40)   # half width
    bar_hy = sq_half * (1 - 2 * 0.30)   # half height
    bar_r = bar_hx * 0.5

    rows = []
    for y in range(s):
        row = bytearray()
        py = y + 0.5
        for x in range(s):
            px = x + 0.5
            color = BG
            # Lime square
            d = rounded_rect_sdf(px, py, cx, cy, sq_half, sq_half, sq_r)
            cov = clamp(0.5 - d, 0.0, 1.0)
            if cov > 0:
                color = blend(color, LIME, cov)
            # Dark inset slot
            d2 = rounded_rect_sdf(px, py, cx, cy, bar_hx, bar_hy, bar_r)
            cov2 = clamp(0.5 - d2, 0.0, 1.0)
            if cov2 > 0:
                color = blend(color, INK, cov2)
            row += bytes(color)
        rows.append(bytes(row))
    return rows

def write_png(path, rows):
    s = SIZE
    raw = bytearray()
    for r in rows:
        raw.append(0)         # filter type 0 (None)
        raw += r
    comp = zlib.compress(bytes(raw), 9)

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data +
                struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff))

    ihdr = struct.pack(">IIBBBBB", s, s, 8, 2, 0, 0, 0)  # 8-bit, color type 2 (RGB)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", comp) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)

if __name__ == "__main__":
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    write_png(OUT, render())
    print(f"Wrote {OUT} ({SIZE}x{SIZE})")
