#!/usr/bin/env python3
"""Boot splash screen for Pixel Racer NES (original art).

A 90s-style Japanese sports coupe (long nose, rounded cabin, tall hoop
wing; no badges or brand marks) parked in front of a striped neon sunset,
with the game's logo.  The whole screen is generated here and written as

  splash.chr   256 BG tiles (the splash replaces the whole BG table while
               it is up; the title screen reloads the normal tiles)
  splash.nam   960-byte nametable + 64-byte attribute table

Palettes (src/splash.s):
  0 scenery/logo  black, red, orange, yellow
  1 text          black, white (PRESS START blinks it), grey, yellow
The version number (bottom right, grey) is the newest one in CHANGELOG.md.
  3 car           black, red, white, dark grey
Usage: mksplash.py OUTDIR
"""
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import font
from mkchr import TileSet, tile, big_letter, LOGO

W, H = 256, 240
HORIZON = 112               # first ground line
CAR_X, CAR_Y = 64, 112      # car box: 128 x 48 (tile rows 14-19)


def blank():
    return [['0'] * W for _ in range(H)]


def scenery(pix):
    # stars (yellow)
    for x, y in ((14, 44), (37, 70), (61, 52), (90, 40), (170, 46), (198, 66),
                 (221, 41), (243, 75), (8, 92), (247, 98), (120, 34), (150, 30)):
        pix[y][x] = '3'
    # striped sun: yellow top, orange bottom, gaps widen toward the horizon
    cx, cy, r = 128, 104, 44
    for y in range(cy - r, HORIZON):
        for x in range(cx - r, cx + r + 1):
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 >= r * r:
                continue
            band = None
            for gy, gh in ((80, 1), (88, 2), (96, 3), (104, 4)):
                if gy <= y < gy + gh:
                    band = True
            if band:
                continue
            pix[y][x] = '3' if y < 84 else '2'
    # horizon line and neon floor lines, closer together toward the horizon
    for x in range(W):
        pix[HORIZON][x] = '1'
    y, gap = HORIZON + 2, 2
    while y < 200:
        for x in range(W):
            pix[y][x] = '1'
        y += gap
        gap += 2


def poly_fill(pix, pts, c, ox, oy):
    """Fill polygon (car-local coords) into pix at offset."""
    ys = [p[1] for p in pts]
    for y in range(int(min(ys)), int(max(ys)) + 1):
        yc = y + 0.5
        xs = []
        for (x1, y1), (x2, y2) in zip(pts, pts[1:] + pts[:1]):
            if (y1 <= yc < y2) or (y2 <= yc < y1):
                xs.append(x1 + (yc - y1) * (x2 - x1) / (y2 - y1))
        xs.sort()
        for a, b in zip(xs[0::2], xs[1::2]):
            for x in range(int(math.ceil(a - 0.5)), int(math.floor(b - 0.5)) + 1):
                if 0 <= y < 48 and 0 <= x < 128:
                    pix[oy + y][ox + x] = c


def car(pix):
    """Draw the coupe into pix.  Car-local box 128 x 48, ground at y 47.
    Fill chars: 'r' red body, 'w' white glass/highlights/rims, 'g' dark grey
    tyres, 'k' black lines; outlined afterwards."""
    box = [['.'] * 128 for _ in range(48)]
    body = [(3, 38), (2, 30), (5, 25), (24, 22), (32, 21), (44, 11), (56, 8),
            (68, 9), (86, 20), (94, 21), (110, 24), (121, 27), (126, 31),
            (125, 37), (119, 40), (8, 40)]
    poly_fill(box, body, 'r', 0, 0)
    # wing: two uprights and the plane
    poly_fill(box, [(10, 23), (11, 16), (13, 16), (13, 23)], 'r', 0, 0)
    poly_fill(box, [(21, 22), (22, 16), (24, 16), (24, 22)], 'r', 0, 0)
    poly_fill(box, [(1, 17), (2, 13), (31, 14), (32, 17)], 'r', 0, 0)
    # glasshouse with a B-pillar
    poly_fill(box, [(35, 21), (46, 12), (57, 10.5), (66, 11.5), (82, 21)], 'w', 0, 0)
    for y in range(11, 22):
        box[y][61] = box[y][62] = 'k'
    # door line, side intake, sill, headlight, mirror, highlights
    for y in range(22, 37):
        box[y][64] = 'k'
    for x in range(30, 42):
        box[27][x] = box[28][x] = 'k'
    for x in range(14, 116):
        box[37][x] = 'k'
    poly_fill(box, [(112, 27), (122, 29), (124, 32), (114, 31)], 'w', 0, 0)
    poly_fill(box, [(84, 18), (88, 17), (88, 20), (85, 20)], 'k', 0, 0)
    for x in range(90, 118):
        box[23 + (x - 90) // 10][x] = 'w'        # hood shine
    for x in range(8, 30):
        box[24][x] = 'w'                          # deck shine
    for y in range(28, 33):
        box[y][3] = box[y][4] = 'k'               # tail lamp housing
    # wheel arches, outline, wheels
    wheels = [(26, 38), (101, 38)]
    for cx, cy in wheels:
        for y in range(48):
            for x in range(128):
                if math.hypot(x + 0.5 - cx, y + 0.5 - cy) < 11.5 and y >= cy - 12:
                    box[y][x] = '.'
    out = [row[:] for row in box]
    for y in range(48):
        for x in range(128):
            if box[y][x] != '.':
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < 128 and 0 <= ny < 48 and box[ny][nx] in 'rwg':
                    out[y][x] = 'k'
                    break
    box = out
    for cx, cy in wheels:
        for y in range(48):
            for x in range(128):
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                d = math.hypot(dx, dy)
                if d > 9.6:
                    continue
                if d > 9.0 or d < 1.6:
                    box[y][x] = 'k'
                elif d > 6.6:
                    box[y][x] = 'g'               # tyre
                else:
                    a = math.atan2(dy, dx) % (2 * math.pi / 5)
                    box[y][x] = 'w' if abs(a - math.pi / 5) < 0.35 else 'k'
    # shadow on the ground, then paste the car
    for y in range(44, 48):
        for x in range(6, 122):
            if box[y][x] == '.':
                box[y][x] = 'k'
    code = {'k': '0', 'r': '1', 'w': '2', 'g': '3'}
    for y in range(48):
        for x in range(128):
            if box[y][x] != '.':
                pix[CAR_Y + y][CAR_X + x] = code[box[y][x]]


def text(pix, s, col, row, c='1'):
    for i, ch in enumerate(s):
        g = list(font.G[ch]) + ['.....']
        for y in range(8):
            for x in range(5):
                if g[y][x] == '#':
                    pix[row * 8 + y][(col + i) * 8 + x] = c


def version():
    """The newest version in CHANGELOG.md, e.g. 'V5.0'."""
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'CHANGELOG.md')
    with open(path) as f:
        return 'V' + re.search(r'^## v([\d.]+)', f.read(), re.M).group(1)


def logo(pix, col, row):
    for i, ch in enumerate(LOGO):
        if ch == ' ':
            continue
        g = big_letter(ch)
        for y in range(16):
            for x in range(16):
                if g[y][x] != '0':
                    pix[row * 8 + y][(col + i * 2) * 8 + x] = g[y][x]


def build():
    pix = blank()
    scenery(pix)
    logo(pix, 5, 3)
    car(pix)
    text(pix, 'PRESS START', 10, 24)
    text(pix, 'UNOFFICIAL FAN GAME', 6, 27)
    ver = version()
    text(pix, ver, 31 - len(ver), 28, '2')          # bottom right, grey
    rows = [''.join(r) for r in pix]
    ts = TileSet(0x00, limit=256)
    nt = []
    for ty in range(30):
        for tx in range(32):
            nt.append(ts.add(tile([rows[ty * 8 + y][tx * 8:tx * 8 + 8] for y in range(8)])))
    # attributes: scenery palette 0, text rows palette 1, car box palette 3
    attr = bytearray(64)
    for by in range(15):
        for bx in range(16):
            pal = 0
            if by in (12, 13):                    # rows 24-27: text
                pal = 1
            if by == 14 and bx >= 12:             # rows 28-29, cols 24-31: version
                pal = 1
            if 7 <= by <= 9 and 4 <= bx <= 11:    # rows 14-19, cols 8-23: car
                pal = 3
            i = (by // 2) * 8 + bx // 2
            shift = ((by & 1) * 2 + (bx & 1)) * 2
            attr[i] |= pal << shift
    return ts.blob(), bytes(nt) + bytes(attr), len(ts.tiles), rows


def main():
    out = sys.argv[1]
    chr_, nam, n, rows = build()
    with open(os.path.join(out, 'splash.chr'), 'wb') as f:
        f.write(chr_)
    with open(os.path.join(out, 'splash.nam'), 'wb') as f:
        f.write(nam)
    print('splash tiles %d/256' % n, file=sys.stderr)


if __name__ == '__main__':
    main()
