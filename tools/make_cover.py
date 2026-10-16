#!/usr/bin/env python3
"""Draws the 630 by 500 itch.io cover from the game's own tile sheet and font.

Run from the repo root:  python3 tools/make_cover.py
Writes assets/cover.png. Needs Pillow.
"""
import random
from PIL import Image

TILES = Image.open("assets/urizen.png").convert("RGBA")
FONT = Image.open("assets/font.png").convert("RGBA")

PAPER = (0x10, 0x14, 0x18, 255)
INK = (0xE8, 0xDC, 0xB0, 255)
ACCENT = (0xD0, 0x80, 0x40, 255)

W, H = 630, 500
S = 3  # tile scale: 12 px tiles become 36 px
img = Image.new("RGBA", (W, H), PAPER)


def tile(col, row, x, y, scale=S):
    """Draws a Urizen tile (12 px, 1 px gap) with black knocked out."""
    sx, sy = 13 * col + 1, 13 * row + 1
    crop = TILES.crop((sx, sy, sx + 12, sy + 12))
    px = crop.load()
    for yy in range(12):
        for xx in range(12):
            r, g, b, _ = px[xx, yy]
            if r == 0 and g == 0 and b == 0:
                px[xx, yy] = (0, 0, 0, 0)
    crop = crop.resize((12 * scale, 12 * scale), Image.NEAREST)
    img.alpha_composite(crop, (x, y))


def text(s, x, y, color, scale):
    """DINOBYTE: 16 by 16 sheet of 6 by 8 cells, tinted."""
    cx = x
    for ch in s:
        c = ord(ch)
        sx, sy = (c % 16) * 6, (c // 16) * 8
        glyph = FONT.crop((sx, sy, sx + 6, sy + 8))
        tinted = Image.new("RGBA", glyph.size, (0, 0, 0, 0))
        gp, tp = glyph.load(), tinted.load()
        for yy in range(8):
            for xx in range(6):
                if gp[xx, yy][3] > 0:
                    tp[xx, yy] = color
        img.alpha_composite(tinted.resize((6 * scale, 8 * scale), Image.NEAREST), (cx, y))
        cx += 6 * scale


def centered(s, y, color, scale):
    text(s, (W - len(s) * 6 * scale) // 2, y, color, scale)


rng = random.Random(5)
trees = [(0, 8), (1, 8), (2, 8), (3, 8), (4, 8)]
tufts = [(3, 9), (4, 9), (6, 9), (10, 9)]
cols, rows = W // 36 + 1, H // 36 + 1
for r in range(rows):
    for c in range(cols):
        x, y = c * 36, r * 36
        if 3 <= r <= 10:
            continue  # the band for the title and the characters
        roll = rng.randrange(20)
        if roll < 4:
            tile(*rng.choice(trees), x, y)
        elif roll < 9:
            tile(*rng.choice(tufts), x, y)
        elif roll == 9:
            tile(15, 6, x, y)

# Title.
centered("BEAVER HUNTERS", 120, INK, 7)
centered("OF SPLORR!!", 188, ACCENT, 7)

# The hunter and the beavers, big.
big = 6
tile(104, 0, 70, 290, big)
for i in range(4):
    tile(4, 14, 190 + i * 100, 320, big)

img.convert("RGB").save("assets/cover.png")
print("wrote assets/cover.png", img.size)
