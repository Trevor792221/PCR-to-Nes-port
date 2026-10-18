#!/usr/bin/env python3
"""Build all CHR (tile) data and background maps for Pixel Racer NES.

Usage: mkchr.py OUTDIR

Writes:
  common.chr   BG tiles $00-$7F (UI tiles + font)              2 KB
  raceN.chr    BG tiles $80-$FF for race theme N (road, skyline) 2 KB each
               themes: 0 day, 1 sunset, 2 night
  menu.chr     BG tiles $80-$FF for menus (logo, garage)       2 KB
  sprites.chr  sprite tiles $00-$3F                            1 KB
  cars.chr     7 car bodies + 2 traffic vehicles x 12 tiles (top 4, wheels A, wheels B)
  bigcars.chr  6 car bodies x 32 tiles (2x scale, for menus)
  race_mapN.bin nametable rows 6-29 for race theme N (24x32)
  logo_map.bin title logo (2 rows x 22 tiles)
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art
import font


def tile(rows):
    """8 strings of 8 chars ('.'/0-3, or 'k','p','w' = 1,2,3) -> 16 bytes."""
    m = {'.': 0, ' ': 0, '0': 0, '1': 1, '2': 2, '3': 3, 'k': 1, 'p': 2, 'w': 3, '#': 1}
    p0, p1 = [], []
    assert len(rows) == 8, rows
    for r in rows:
        r = r.ljust(8, '.')
        b0 = b1 = 0
        for i, c in enumerate(r[:8]):
            v = m[c]
            if v & 1:
                b0 |= 0x80 >> i
            if v & 2:
                b1 |= 0x80 >> i
        p0.append(b0)
        p1.append(b1)
    return bytes(p0 + p1)


def grid_tiles(pix, tw, th):
    """Cut a pixel grid (list of strings) into tw x th tiles, row-major."""
    out = []
    for ty in range(th):
        for tx in range(tw):
            out.append(tile([pix[ty * 8 + y][tx * 8:tx * 8 + 8] for y in range(8)]))
    return out


def solid(c):
    return tile([str(c) * 8] * 8)


# ---------------------------------------------------------------------------
# Common BG tiles $00-$7F
# ---------------------------------------------------------------------------
def build_common():
    t = [solid(0)] * 128
    t[0x01] = solid(1)
    t[0x02] = solid(2)
    t[0x03] = solid(3)
    # box frame (colour 3)
    t[0x04] = tile(['........', '........', '........', '...33333', '...3....', '...3....', '...3....', '...3....'])
    t[0x05] = tile(['........', '........', '........', '33333333', '........', '........', '........', '........'])
    t[0x06] = tile(['........', '........', '........', '33333...', '....3...', '....3...', '....3...', '....3...'])
    t[0x07] = tile(['...3....'] * 8)
    t[0x08] = tile(['....3...'] * 8)
    t[0x09] = tile(['...3....', '...3....', '...3....', '...33333', '........', '........', '........', '........'])
    t[0x0A] = tile(['........', '........', '........', '........', '33333333', '........', '........', '........'])
    t[0x0B] = tile(['....3...', '....3...', '....3...', '33333...', '........', '........', '........', '........'])
    # horizontal bar, k = 0..8 pixels filled (colour 2), rest colour 3
    for k in range(9):
        mid = '2' * k + '3' * (8 - k)
        t[0x0C + k] = tile(['........', mid, mid, mid, mid, mid, mid, '........'])
    # tree lights: off ring, on colour 2, on colour 3
    t[0x15] = tile(['..1111..', '.1....1.', '1......1', '1......1', '1......1', '1......1', '.1....1.', '..1111..'])
    t[0x16] = tile(['..1111..', '.122221.', '12222221', '12222221', '12222221', '12222221', '.122221.', '..1111..'])
    t[0x17] = tile(['..1111..', '.133331.', '13333331', '13333331', '13333331', '13333331', '.133331.', '..1111..'])
    # progress track
    t[0x18] = tile(['........', '........', '........', '33333333', '33333333', '........', '........', '........'])
    t[0x19] = tile(['1.......', '1.......', '1.......', '13333333', '13333333', '1.......', '1.......', '1.......'])
    t[0x1A] = tile(['1212....', '2121....', '1212....', '2121....', '1212....', '2121....', '1.......', '1.......'])
    t[0x1C] = tile(['........', '.1......', '.11.....', '.111....', '.1111...', '.111....', '.11.....', '.1......'])  # >
    t[0x1D] = tile(['........', '....1...', '...11...', '..111...', '.1111...', '..111...', '...11...', '....1...'])  # <
    t[0x1E] = tile(['33333333'] * 2 + ['........'] * 6)                                                         # thin rule top
    t[0x1F] = tile(['........'] * 6 + ['33333333'] * 2)                                                         # thin rule bottom
    for c in range(32, 96):
        rows = list(font.G[chr(c)]) + ['.....']
        t[c] = tile([r.replace('#', '1') for r in rows])
    # $60-$7F: the same font in colour 3 (for highlighted text) -- letters only
    for c in range(64, 96):
        rows = list(font.G[chr(c)]) + ['.....']
        t[c + 0x20] = tile([r.replace('#', '3') for r in rows])
    # digits in colour 3 at $60.. are covered above for '@'..'_'; put digits at $7B-..? no.
    return b''.join(t)


# ---------------------------------------------------------------------------
# Race tiles $80-$FF + background map
# ---------------------------------------------------------------------------
class TileSet:
    def __init__(self, base, limit=128):
        self.base, self.tiles, self.limit = base, [], limit

    def add(self, data):
        if data in self.tiles:
            return self.base + self.tiles.index(data)
        assert len(self.tiles) < self.limit, 'tile set full'
        self.tiles.append(data)
        return self.base + len(self.tiles) - 1

    def blob(self):
        return b''.join(self.tiles + [solid(0)] * (self.limit - len(self.tiles)))


RACE_THEMES = ['DAY', 'SUNSET', 'NIGHT']
SKY_W, SKY_H = 256, 72          # skyline: nametable rows 6-14


def _buildings(pix, rnd, body, window, lit, tops=(24, 32, 32, 40, 40, 48)):
    """City block along the bottom of the sky.  body/window are colour
    chars; lit(lx, ly) decides which window cells get the window colour.
    Widths are multiples of 8 and tops sit on 8-pixel boundaries so the
    tiles repeat."""
    x = 0
    while x < SKY_W:
        w = min(rnd.choice([16, 24, 32, 16, 40]), SKY_W - x)
        top = rnd.choice(tops)
        style = rnd.randrange(3)
        for yy in range(top, SKY_H):
            for xx in range(x, x + w):
                px = body
                lx, ly = xx - x, yy - top
                if 1 <= lx < w - 1 and ly >= 3:
                    on = False
                    if style == 0:
                        on = lx % 4 in (1, 2) and ly % 6 in (1, 2, 3)
                    elif style == 1:
                        on = lx % 8 in (2, 3, 4, 5) and ly % 8 in (2, 3)
                    else:
                        on = lx % 3 == 1 and ly % 4 == 1
                    if on and lit(style, lx, ly):
                        px = window
                pix[yy][xx] = px
        if top <= 24 and w >= 16:                  # antenna
            for yy in range(top - 6, top):
                pix[yy][x + w // 2] = body
            pix[top - 7][x + w // 2] = window if window != body else '3'
        x += w


def _disc(pix, cx, cy, r, c):
    for y in range(max(0, int(cy - r - 1)), min(SKY_H, int(cy + r + 2))):
        for x in range(max(0, int(cx - r - 1)), min(SKY_W, int(cx + r + 2))):
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 < r * r:
                pix[y][x] = c


def sky_night(rnd):
    """Palette: 0 black buildings, 1 navy sky, 2 blue glow, 3 lit windows."""
    pix = [['1'] * SKY_W for _ in range(SKY_H)]
    for y in range(40, SKY_H):
        for x in range(SKY_W):
            if y >= 52 or (y >= 44 and (x + y) % 2 == 0):
                pix[y][x] = '2'
    for _ in range(10):
        pix[rnd.randrange(30)][rnd.randrange(SKY_W)] = '3'
    _disc(pix, 205, 11, 4.5, '3')                 # moon
    _buildings(pix, rnd, '0', '3',
               lambda st, lx, ly: st == 2 or (st == 0 and (lx // 4 + ly // 6) % 3 != 2)
               or (st == 1 and (lx // 8 + ly // 8) % 2 == 0))
    return pix


def sky_day(rnd):
    """Palette: 0 black windows, 1 pale sky, 2 grey buildings, 3 white
    clouds and sun."""
    pix = [['1'] * SKY_W for _ in range(SKY_H)]
    _disc(pix, 44, 13, 7, '3')                    # sun
    # clouds: overlapping discs, flat bottoms on 8-pixel rows
    for cx, cy, n in ((112, 16, 4), (190, 10, 3), (240, 24, 3), (12, 30, 3)):
        for i in range(n):
            _disc(pix, cx + i * 7 - n * 3, cy - (2 if i % 2 else 0), 5 if i % 2 else 4, '3')
        for x in range(cx - n * 3 - 3, cx + n * 4 + 1):
            for y in range(cy + 2, cy + 5):
                if 0 <= x < SKY_W:
                    pix[y][x] = '1'
    _buildings(pix, rnd, '2', '0',
               lambda st, lx, ly: st != 0 or (lx // 4 + ly // 6) % 3 != 2)
    # roof lines
    for y in range(1, SKY_H):
        for x in range(SKY_W):
            if pix[y][x] == '2' and pix[y - 1][x] in '13':
                pix[y][x] = '0'
    return pix


def sky_sunset(rnd):
    """Palette: 0 black silhouettes, 1 purple sky, 2 orange glow, 3 sun and
    a few lit windows."""
    pix = [['1'] * SKY_W for _ in range(SKY_H)]
    # purple overhead fading to orange at the horizon (dithered bands)
    for y in range(SKY_H):
        for x in range(SKY_W):
            if (y >= 40 or (y >= 32 and (x + y) % 2 == 0)
                    or (y >= 24 and x % 2 == 0 and y % 2 == 0)
                    or (y >= 16 and x % 4 == 0 and y % 4 == 0)):
                pix[y][x] = '2'
    _disc(pix, 168, 40, 17, '3')                  # big low sun
    for y in (36, 42, 47, 51):                    # haze bands across it
        for x in range(150, 187):
            if pix[y][x] == '3':
                pix[y][x] = '2'
    _buildings(pix, rnd, '0', '3',
               lambda st, lx, ly: st == 1 and (lx // 8 + ly // 8) % 3 == 0,
               tops=(40, 48, 48, 56, 56, 40))
    return pix


SKY_PAINTERS = {'DAY': sky_day, 'SUNSET': sky_sunset, 'NIGHT': sky_night}


def build_race(theme):
    """Tiles $80-$FF and the rows 6-29 map for one race theme.  Road and
    special tiles come first so their numbers are the same in every theme."""
    ts = TileSet(0x80)
    # --- road: palette 0 black, 1 asphalt, 2 light grey, 3 white
    A = ts.add(solid(1))
    # the rail row shares its attribute block with the sky: colours 0 and 3 only
    rail_top = ts.add(tile(['........', '33333333', '33333333', '0.0..0.0', '.0....0.', '33333333', '33333333', '00000000']))
    rail_post = ts.add(tile(['........', '33333333', '33333333', '0.0330.0', '.0.33.0.', '33333333', '33333333', '00033000']))
    walk = ts.add(tile(['22222222', '22222222', '22222220', '22222220', '22222220', '22222220', '22222220', '00000000']))
    walk2 = ts.add(tile(['22222222', '22222222', '22222222', '22222222', '22222222', '22222222', '22222222', '00000000']))
    curb_top = ts.add(tile(['00000000', '33333333', '11111111', '11111111', '11111111', '11111111', '11111111', '11111111']))
    curb_bot = ts.add(tile(['11111111', '11111111', '11111111', '11111111', '11111111', '11111111', '33333333', '00000000']))
    dash = ts.add(tile(['11111111', '11111111', '11111111', '33333333', '33333333', '11111111', '11111111', '11111111']))
    gutter = ts.add(tile(['00000000', '22222222', '22202220', '22222222', '22222222', '22022202', '22222222', '22222222']))
    specials = {}
    specials['START'] = ts.add(tile(['33..33..'] * 8))
    specials['FINISH_A'] = ts.add(tile(['3333....'] * 4 + ['....3333'] * 4))
    specials['FINISH_B'] = ts.add(tile(['....3333'] * 4 + ['3333....'] * 4))
    specials['ASPHALT'] = A
    specials['CURB_TOP'] = curb_top
    specials['CURB_BOT'] = curb_bot
    specials['DASH'] = dash
    specials['HUD_EDGE'] = ts.add(tile(['........', '11111111'] + ['........'] * 6))
    road_rows = []
    for r in range(15, 30):
        row = []
        for c in range(32):
            if r == 15:
                row.append(rail_post if c % 4 == 0 else rail_top)
            elif r == 16:
                row.append(walk if c % 2 else walk2)
            elif r == 17:
                row.append(curb_top)
            elif r in (21, 25):
                row.append(dash if (c // 2) % 2 == 0 else A)
            elif r == 28:
                row.append(curb_bot)
            elif r == 29:
                row.append(gutter)
            else:
                row.append(A)
        road_rows.append(row)
    # --- skyline
    pix = [''.join(r) for r in SKY_PAINTERS[theme](random.Random(1987))]
    sky_rows = []
    for ty in range(9):
        sky_rows.append([ts.add(tile([pix[ty * 8 + y][tx * 8:tx * 8 + 8] for y in range(8)]))
                         for tx in range(32)])
    nt = bytes(sum(sky_rows + road_rows, []))
    return ts.blob(), nt, specials, len(ts.tiles)


# ---------------------------------------------------------------------------
# Menu tiles $80-$FF: big logo letters, garage floor, crate
# ---------------------------------------------------------------------------
LOGO = 'PIXEL RACER'


def big_letter(ch):
    """16x16 letter from the 5x7 font: 2x scale, colour 2 face, colour 3 highlight,
    colour 1 drop shadow."""
    g = list(font.G[ch])
    pix = [['0'] * 16 for _ in range(16)]
    on = lambda x, y: 0 <= y < 7 and 0 <= x < 5 and g[y][x] == '#'
    for y in range(16):
        for x in range(16):
            sx, sy = (x - 2) // 2, (y - 1) // 2
            if x >= 2 and y >= 1 and on(sx, sy):
                pix[y][x] = '3' if y < 6 else '2'
            elif x >= 3 and y >= 2 and on((x - 3) // 2, (y - 2) // 2):
                pix[y][x] = '1'
    return [''.join(r) for r in pix]


WBAR = ['........', '........', '........', '.1111111', '.1......', '111.....', '131.....', '111.....']
FLOOR_A_ROWS = ['33333333', '22222222', '22222222', '22222222', '11111111', '11111111', '11111111', '11111111']
WB_COL, WB_ROW = 10, 9           # garage: 3x3 tiles behind the showroom car's rear


def garage_wheelie(pix, ts):
    """The garage tiles under the 2x wheelie bars (16x16 at x 84, screen y
    76, 12 pixels behind the showroom car) with the bars drawn in black.
    The showroom car is 8 sprites wide, so the bars can't be sprites there."""
    big = [''.join(c * 2 for c in r) for r in WBAR for _ in (0, 1)]
    out = []
    for ty in range(3):
        for tx in range(3):
            rows = []
            for y in range(8):
                py = (WB_ROW - 4 + ty) * 8 + y               # garage rows start at 4
                row = list(pix[py][(WB_COL + tx) * 8:(WB_COL + tx) * 8 + 8])
                for x in range(8):
                    bx, by = (WB_COL + tx) * 8 + x - 84, py + 32 - 76
                    if 0 <= bx < 16 and 0 <= by < 16 and big[by][bx] == '1':
                        row[x] = '0'
                rows.append(''.join(row))
            out.append(ts.add(tile(rows)))
    return out


def build_garage(ts, night=False):  # noqa: C901
    """Garage backdrop behind the showroom car: nametable rows 4-12.
    night=True: the roll-up door is open on a night sky (moon, stars, a lit
    skyline) drawn in palette 1; the night colours are set in code.
    Palettes (menu): 0 = black/white/grey/yellow (ceiling and lamps),
    2 = reds (tool chest), 3 = greys (walls, door, floor).
    Returns (map bytes 9x32, palette per 16x16 block, 5 block rows x 16)."""
    W, H = 256, 72
    pix = [['0'] * W for _ in range(H)]
    # --- ceiling (rows 4-5, palette 0): steel beam, two hanging lamps
    for x in range(W):
        for y in (1, 2, 3, 4, 5):
            pix[y][x] = '2'
        if x % 16 == 4:
            pix[3][x] = '1'                       # rivets
    for lx in (48, 208):
        for y in range(6, 9):
            pix[y][lx] = '2'                      # cord
        for y, half in ((9, 3), (10, 5), (11, 6), (12, 7)):
            for x in range(lx - half, lx + half + 1):
                pix[y][x] = '2'                   # shade
        for y in (13, 14):
            for x in range(lx - 3, lx + 4):
                pix[y][x] = '3'                   # bulb glow
        pix[15][lx - 1] = pix[15][lx] = pix[15][lx + 1] = '3'
    # --- walls (rows 6-10, palette 3): bricks
    for y in range(16, 56):
        for x in range(W):
            ly = (y - 16) % 8
            off = 0 if ((y - 16) // 8) % 2 == 0 else 4
            if ly == 3 or ly == 7:
                pix[y][x] = '0'
            elif ly < 3 and (x + off) % 8 == 4 and ((y - 16) // 8) % 2:
                pix[y][x] = '0'
            elif ly > 3 and (x + off) % 8 == 2 and ((y - 16) // 8) % 2:
                pix[y][x] = '0'
            else:
                pix[y][x] = '1'
    # roll-up door behind the car (cols 10-21)
    for y in range(16, 56):
        for x in range(80, 176):
            if x < 84 or x >= 172 or y < 20:
                pix[y][x] = '3'                   # frame and header
            else:
                pix[y][x] = '2' if (y - 20) % 4 < 2 else ('1' if (y - 20) % 4 == 2 else '3')
    for x in range(120, 136):
        pix[52][x] = pix[53][x] = '3'             # handle
    if night:
        _night_door(pix)
    # pegboard with tools (cols 1-6, rows 6-7)
    for y in range(17, 31):
        for x in range(9, 55):
            pix[y][x] = '0' if (x % 4 == 1 and y % 4 == 1) else '3'
    for y in range(19, 29):                       # wrench
        pix[y][16] = pix[y][17] = '2'
    for x in range(14, 20):
        pix[19][x] = '2'
    pix[20][14] = pix[20][19] = '2'
    for y in range(20, 29):                       # hammer
        pix[y][29] = pix[y][30] = '1'
    for x in range(25, 35):
        pix[20][x] = pix[21][x] = '2'
    for y in range(21, 29):                       # screwdriver
        pix[y][42] = '2'
    for y in range(19, 23):
        pix[y][41] = pix[y][42] = pix[y][43] = '1'
    for y in range(19, 28):                       # saw
        for x in range(48, 53):
            if x - 48 <= (y - 19) // 2:
                pix[y][x] = '2'
    # tyre stack (cols 2-5, rows 8-10)
    for t in range(3):                            # three tyres seen side-on
        y0 = 32 + t * 8
        for y in range(y0, y0 + 8):
            for x in range(17, 47):
                ly, corner = y - y0, x in (17, 46)
                if ly in (0, 7) or (corner and ly in (1, 6)):
                    pix[y][x] = '0'               # rounded black edge
                elif ly in (1, 6):
                    pix[y][x] = '2' if x % 3 else '0'   # tread blocks
                elif ly in (3, 4):
                    pix[y][x] = '1'               # sidewall stripe
                else:
                    pix[y][x] = '3'               # sidewall
    # tool chest (cols 24-27, rows 6-9, palette 2) with casters on row 10
    for y in range(16, 48):
        for x in range(192, 224):
            if x in (192, 223) or y in (16, 47):
                pix[y][x] = '0'
            elif (y - 16) % 8 == 0 and y > 22:
                pix[y][x] = '1'                   # drawer seams
            elif (y - 16) % 8 == 4 and 202 <= x < 214:
                pix[y][x] = '3'                   # handles
            else:
                pix[y][x] = '2'
    for cx in (196, 219):
        for y in range(48, 54):
            for x in range(cx - 2, cx + 3):
                pix[y][x] = '0'
    # --- floor (rows 11-12): same tiles as before
    floor_a = tile(['33333333', '22222222', '22222222', '22222222', '11111111', '11111111', '11111111', '11111111'])
    under = [list(r) for r in pix[:56]] + [list(r * 32) for r in FLOOR_A_ROWS]  # row 11 is floor
    wheelie = garage_wheelie(under, ts)
    rows = [''.join(r) for r in pix]
    gmap = []
    for ty in range(7):
        for tx in range(32):
            gmap.append(ts.add(tile([rows[ty * 8 + y][tx * 8:tx * 8 + 8] for y in range(8)])))
    floor_b = tile(['11111111', '11111111', '11111111', '11111111', '22222222', '22222222', '22222222', '22222222'])
    gmap += [ts.add(floor_a)] * 32 + [ts.add(floor_b)] * 32
    build_garage.wheelie[night] = wheelie
    # palettes per 16x16 block: block rows 2..6 (nametable rows 4-13)
    attr = []
    for by in range(5):
        for bx in range(16):
            if by == 0:
                attr.append(0)                    # ceiling
            elif by in (1, 2) and bx in (12, 13):
                attr.append(2)                    # tool chest
            elif night and by in (1, 2) and 5 <= bx <= 10:
                attr.append(1)                    # open door: night sky
            else:
                attr.append(3)
    return bytes(gmap), bytes(attr)


build_garage.wheelie = {}


def _night_door(pix):
    """Open door on a night sky, laid out on the 8x8 tile grid so it costs
    only ~10 tiles.  Tile columns 10-21, rows 6-9 use palette 1 (0 sky,
    1 skyline and door header, 2 lit windows, 3 moon and stars); row 10 is
    the driveway (palette 3)."""
    for y in range(16, 48):
        for x in range(80, 176):
            pix[y][x] = '1' if y < 20 else '0'                # header, sky
    for tx, y in ((11, 21), (14, 21), (18, 21), (12, 27), (16, 27), (21, 27)):
        pix[y][tx * 8 + 4] = '3'                              # stars
    moon = ['..33....', '.33.....', '33......', '33......', '33......', '.33.....', '..33....', '........']
    for dy, row in enumerate(moon):                           # crescent, tile (19, 7)
        for dx, ch in enumerate(row):
            if ch == '3':
                pix[24 + dy][152 + dx + 2] = '3'
    lit_a = ['11111111', '12112111', '11111111', '12112111', '11111111', '12112111', '11111111', '11111111']
    lit_b = ['11111111', '11112111', '11111111', '12111111', '11111111', '11112111', '11111111', '11111111']
    # building height per tile column 10..21: 2 = rows 8-9, 1 = row 9 only
    heights = [1, 2, 2, 1, 2, 1, 1, 2, 2, 2, 1, 2]
    for i, h in enumerate(heights):
        for row in range(2 - h, 2):
            pat = lit_a if (i + row) % 2 else lit_b
            for dy in range(8):
                for dx in range(8):
                    pix[32 + row * 8 + dy][80 + i * 8 + dx] = pat[dy][dx]
    for y in range(48, 56):                                   # driveway
        for x in range(80, 176):
            pix[y][x] = '2' if y == 48 else '1'

def build_menu():
    ts = TileSet(0x80)
    ts.add(solid(0))
    letters = {}
    for ch in sorted(set(LOGO.replace(' ', ''))):
        pix = big_letter(ch)
        letters[ch] = [ts.add(tile([pix[ty * 8 + y][tx * 8:tx * 8 + 8] for y in range(8)]))
                       for ty in range(2) for tx in range(2)]
    top, bot = [], []
    for ch in LOGO:
        if ch == ' ':
            top += [0, 0]
            bot += [0, 0]
        else:
            a, b, c, d = letters[ch]
            top += [a, b]
            bot += [c, d]
    specials = {}
    # garage floor (palette 3: 0 bg, 1 dark, 2 mid, 3 light)
    specials['FLOOR_A'] = ts.add(tile(['33333333', '22222222', '22222222', '22222222', '11111111', '11111111', '11111111', '11111111']))
    specials['FLOOR_B'] = ts.add(tile(['11111111', '11111111', '11111111', '11111111', '22222222', '22222222', '22222222', '22222222']))
    specials['WALL'] = ts.add(tile(['11111111', '11111111', '11111111', '00000000', '11111111', '11111111', '11111111', '00000000']))
    specials['WALL2'] = ts.add(tile(['1111.111', '1111.111', '1111.111', '00000000', '11.11111', '11.11111', '11.11111', '00000000']))
    specials['STRIPE'] = ts.add(tile(['22....22', '2....222', '....2222', '...2222.', '..2222..', '.2222...', '2222....', '222....2']))
    # garage backdrop, rows 4-12 (see build_garage)
    gmap, gattr = build_garage(ts)
    specials['GARAGE'] = (gmap, gattr)
    specials['GARAGE_NIGHT'] = build_garage(ts, night=True)
    specials['WBAR_DAY'] = build_garage.wheelie[False]
    specials['WBAR_NIGHT'] = build_garage.wheelie[True]
    # crate 4x4 (32x32)
    crate = [
        '11111111111111111111111111111111',
        '13333333333333333333333333333331',
        '13222222222222222222222222222231',
        '13212222222222222222222222221231',
        '13221222222222222222222222212231',
        '13222122222222222222222222122231',
        '13222212222222222222222221222231',
        '13222221222222222222222212222231',
        '13222222122222222222222122222231',
        '13222222212222222222221222222231',
        '13222222221222222222212222222231',
        '13222222222122222222122222222231',
        '13222222222212222221222222222231',
        '13222222222221222212222222222231',
        '13222222222222122122222222222231',
        '13333333333333311333333333333331',
        '13333333333333311333333333333331',
        '13222222222222122122222222222231',
        '13222222222221222212222222222231',
        '13222222222212222221222222222231',
        '13222222222122222222122222222231',
        '13222222221222222222212222222231',
        '13222222212222222222221222222231',
        '13222222122222222222222122222231',
        '13222221222222222222222212222231',
        '13222212222222222222222221222231',
        '13222122222222222222222222122231',
        '13221222222222222222222222212231',
        '13212222222222222222222222221231',
        '13222222222222222222222222222231',
        '13333333333333333333333333333331',
        '11111111111111111111111111111111',
    ]
    specials['CRATE'] = [ts.add(t) for t in grid_tiles(crate, 4, 4)]
    return ts.blob(), bytes(top + bot), specials, len(ts.tiles)


# ---------------------------------------------------------------------------
# Sprites
# ---------------------------------------------------------------------------
def build_sprites():
    t = [solid(0)] * 64
    t[0x00] = tile(['33333333'] + ['........'] * 7)                        # sprite 0
    t[0x01] = tile(['........', '.33.....', '.333....', '.3333...', '.33333..', '.3333...', '.333....', '.33.....'])
    t[0x02] = tile(['........', '........', '...22...', '..2222..', '..2222..', '...22...', '........', '........'])
    t[0x03] = tile(['........', '..222...', '.222222.', '22222222', '22222222', '.222222.', '..2222..', '........'])
    t[0x04] = tile(['..2..2..', '.222222.', '2222222.', '22222222', '22222222', '.2222222', '.222222.', '...2.2..'])
    t[0x05] = tile(['........', '........', '..2.....', '22332...', '2333333.', '22332...', '..2.....', '........'])
    t[0x06] = tile(['........', '........', '.2......', '223322..', '23333332', '223322..', '.2......', '........'])
    t[0x07] = tile(['........', '..1111..', '.122221.', '12222221', '12222221', '1.1111.1', '.1.11.1.', '........'])  # map marker
    t[0x08] = tile(['...33...', '...33...', '...33...', '33333333', '.333333.', '..3333..', '...33...', '........'])  # down arrow
    t[0x09] = tile(['...3....', '...3....', '..333...', '3333333.', '..333...', '...3....', '...3....', '........'])  # sparkle
    t[0x0A] = tile(['33333333'] * 8)
    t[0x0B] = tile(['........', '..3.....', '.33.....', '3333333.', '.33.....', '..3.....', '........', '........'])  # left arrow
    t[0x0C] = tile(['........', '.....3..', '.....33.', '.3333333', '.....33.', '.....3..', '........', '........'])  # right arrow
    t[0x0D] = tile(['33......'] * 8)                                        # perfect-shift mark on the tach
    t[0x0E] = tile(['........', '..1111..', '.122221.', '.122221.', '.122221.', '.122221.', '..1111..', '........'])  # map: open city
    t[0x0F] = tile(['........', '..1111..', '.133331.', '.131131.', '.131131.', '.133331.', '..1111..', '........'])  # map: locked city
    # wheelie bars: a strut from the rear bumper to a small wheel, next to
    # the car's lower half (colours 1 outline, 3 rims)
    t[0x28] = tile(WBAR)
    return b''.join(t)


def car_tiles(name):
    a = art.car_pixels(name, 0)
    b = art.car_pixels(name, 1)
    tiles = grid_tiles(a, 4, 2)                         # 0-3 top, 4-7 bottom (wheels A)
    tiles += grid_tiles(b[8:], 4, 1)                    # 8-11 bottom (wheels B)
    return tiles


def big_car_tiles(name):
    a = art.car_pixels(name, 0)
    big = []
    for r in a:
        rr = ''.join(c * 2 for c in r)
        big += [rr, rr]
    return grid_tiles(big, 8, 4)


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    w = lambda n, d: open(os.path.join(out, n), 'wb').write(d)
    w('common.chr', build_common())
    counts = []
    for i, theme in enumerate(RACE_THEMES):
        race, race_nt, sp, n = build_race(theme)
        if i == 0:
            race_sp = sp
        assert sp == race_sp, 'road tiles must match across themes'
        w('race%d.chr' % i, race)
        w('race_map%d.bin' % i, race_nt)
        counts.append('%s %d' % (theme.lower(), n))
    nrace = ', '.join(counts)
    menu, logo_map, menu_sp, nmenu = build_menu()
    w('menu.chr', menu)
    w('garage_map.bin', menu_sp['GARAGE'][0])
    w('garage_attr.bin', menu_sp['GARAGE'][1])
    w('garage_night_map.bin', menu_sp['GARAGE_NIGHT'][0])
    w('garage_night_attr.bin', menu_sp['GARAGE_NIGHT'][1])
    w('logo_map.bin', logo_map)
    w('sprites.chr', build_sprites())
    w('cars.chr', b''.join(b''.join(car_tiles(n)) for n in art.SHAPE_ORDER + art.TRAFFIC_ORDER))
    w('bigcars.chr', b''.join(b''.join(big_car_tiles(n)) for n in art.SHAPE_ORDER))
    # tile ids the code needs
    with open(os.path.join(out, 'tiles.inc'), 'w') as f:
        f.write('; generated by tools/mkchr.py\n')
        for k, v in race_sp.items():
            f.write('T_%s = $%02X\n' % (k, v))
        for k, v in menu_sp.items():
            if k in ('GARAGE', 'GARAGE_NIGHT'):
                continue
            if isinstance(v, list):
                f.write('.define T_%s_MAP %s\n' % (k, ', '.join('$%02X' % x for x in v)))
            else:
                f.write('T_%s = $%02X\n' % (k, v))
        f.write('LOGO_W = %d\n' % (len(logo_map) // 2))
        f.write('NTHEMES = %d\n' % len(RACE_THEMES))
    print('race tiles (of 128): %s; menu tiles %d/128' % (nrace, nmenu), file=sys.stderr)


if __name__ == '__main__':
    main()
