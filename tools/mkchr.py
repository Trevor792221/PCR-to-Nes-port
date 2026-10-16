#!/usr/bin/env python3
"""Build all CHR (tile) data and background maps for Pixel Racer NES.

Usage: mkchr.py OUTDIR

Writes:
  common.chr   BG tiles $00-$7F (UI tiles + font)              2 KB
  race.chr     BG tiles $80-$FF for races (skyline, road)      2 KB
  menu.chr     BG tiles $80-$FF for menus (logo, garage)       2 KB
  sprites.chr  sprite tiles $00-$3F                            1 KB
  cars.chr     6 car bodies x 12 tiles (top 4, wheels A, wheels B)
  bigcars.chr  6 car bodies x 32 tiles (2x scale, for menus)
  race_map.bin nametable rows 6-29 for the race background (24x32)
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


def build_race():
    ts = TileSet(0x80)
    rnd = random.Random(1987)
    W = 256
    # --- skyline: rows 6..14 (72 px).  Palette: 0 black, 1 navy, 2 blue glow, 3 windows
    H = 72
    pix = [['1'] * W for _ in range(H)]
    # horizon glow on the lowest sky rows
    for y in range(40, H):
        for x in range(W):
            if y >= 52 or (y >= 44 and (x + y) % 2 == 0):
                pix[y][x] = '2'
    # stars
    for _ in range(10):
        x, y = rnd.randrange(W), rnd.randrange(30)
        pix[y][x] = '3'
    # moon
    for y in range(6, 15):
        for x in range(200, 210):
            if (x - 204.5) ** 2 + (y - 10.5) ** 2 < 20:
                pix[y][x] = '3'
    # buildings: widths multiples of 8, tops on 8-pixel boundaries
    x = 0
    while x < W:
        w = rnd.choice([16, 24, 32, 16, 40])
        w = min(w, W - x)
        top = rnd.choice([24, 32, 32, 40, 40, 48])
        style = rnd.randrange(3)
        for yy in range(top, H):
            for xx in range(x, x + w):
                px = '0'
                lx, ly = xx - x, yy - top
                if 1 <= lx < w - 1 and ly >= 3:
                    if style == 0 and lx % 4 in (1, 2) and ly % 6 in (1, 2, 3) and (lx // 4 + ly // 6) % 3 != 2:
                        px = '3'
                    if style == 1 and lx % 8 in (2, 3, 4, 5) and ly % 8 in (2, 3) and (lx // 8 + ly // 8) % 2 == 0:
                        px = '3'
                    if style == 2 and lx % 3 == 1 and ly % 4 == 1 :
                        px = '3'
                pix[yy][xx] = px
        # antenna on tall buildings
        if top <= 24 and w >= 16:
            for yy in range(top - 6, top):
                pix[yy][x + w // 2] = '0'
            pix[top - 7][x + w // 2] = '3'
        x += w
    pix = [''.join(r) for r in pix]
    sky_rows = []
    for ty in range(9):
        row = []
        for tx in range(32):
            row.append(ts.add(tile([pix[ty * 8 + y][tx * 8:tx * 8 + 8] for y in range(8)])))
        sky_rows.append(row)

    # --- road: palette 0 black, 1 asphalt, 2 light grey, 3 white
    asphalt = solid(1)
    A = ts.add(asphalt)
    # the rail row shares its attribute block with the sky: colours 0 and 3 only
    rail_top = ts.add(tile(['........', '33333333', '33333333', '0.0..0.0', '.0....0.', '33333333', '33333333', '00000000']))
    rail_post = ts.add(tile(['........', '33333333', '33333333', '0.0330.0', '.0.33.0.', '33333333', '33333333', '00033000']))
    walk = ts.add(tile(['22222222', '22222222', '22222220', '22222220', '22222220', '22222220', '22222220', '00000000']))
    walk2 = ts.add(tile(['22222222', '22222222', '22222222', '22222222', '22222222', '22222222', '22222222', '00000000']))
    curb_top = ts.add(tile(['00000000', '33333333', '11111111', '11111111', '11111111', '11111111', '11111111', '11111111']))
    curb_bot = ts.add(tile(['11111111', '11111111', '11111111', '11111111', '11111111', '11111111', '33333333', '00000000']))
    dash = ts.add(tile(['11111111', '11111111', '11111111', '33333333', '33333333', '11111111', '11111111', '11111111']))
    nodash = A
    gutter = ts.add(tile(['00000000', '22222222', '22202220', '22222222', '22222222', '22022202', '22222222', '22222222']))
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
                row.append(dash if (c // 2) % 2 == 0 else nodash)
            elif r == 28:
                row.append(curb_bot)
            elif r == 29:
                row.append(gutter)
            else:
                row.append(A)
        road_rows.append(row)
    # special tiles used by the code (column streaming)
    specials = {}
    specials['START'] = ts.add(tile(['33..33..', '33..33..', '33..33..', '33..33..', '33..33..', '33..33..', '33..33..', '33..33..']))
    specials['FINISH_A'] = ts.add(tile(['3333....', '3333....', '3333....', '3333....', '....3333', '....3333', '....3333', '....3333']))
    specials['FINISH_B'] = ts.add(tile(['....3333', '....3333', '....3333', '....3333', '3333....', '3333....', '3333....', '3333....']))
    specials['ASPHALT'] = A
    specials['CURB_TOP'] = curb_top
    specials['CURB_BOT'] = curb_bot
    specials['DASH'] = dash
    # HUD extras in the race set
    specials['HUD_EDGE'] = ts.add(tile(['........', '11111111', '........', '........', '........', '........', '........', '........']))
    rows = sky_rows + road_rows
    nt = bytes(sum(rows, []))
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
    race, race_nt, race_sp, nrace = build_race()
    w('race.chr', race)
    w('race_map.bin', race_nt)
    menu, logo_map, menu_sp, nmenu = build_menu()
    w('menu.chr', menu)
    w('logo_map.bin', logo_map)
    w('sprites.chr', build_sprites())
    w('cars.chr', b''.join(b''.join(car_tiles(n)) for n in art.SHAPE_ORDER))
    w('bigcars.chr', b''.join(b''.join(big_car_tiles(n)) for n in art.SHAPE_ORDER))
    # tile ids the code needs
    with open(os.path.join(out, 'tiles.inc'), 'w') as f:
        f.write('; generated by tools/mkchr.py\n')
        for k, v in race_sp.items():
            f.write('T_%s = $%02X\n' % (k, v))
        for k, v in menu_sp.items():
            if isinstance(v, list):
                f.write('.define T_%s_MAP %s\n' % (k, ', '.join('$%02X' % x for x in v)))
            else:
                f.write('T_%s = $%02X\n' % (k, v))
        f.write('LOGO_W = %d\n' % (len(logo_map) // 2))
    print('race tiles %d/128, menu tiles %d/128' % (nrace, nmenu), file=sys.stderr)


if __name__ == '__main__':
    main()
