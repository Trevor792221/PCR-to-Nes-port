#!/usr/bin/env python3
"""Reference encoder/decoder for Pixel Racer's two passwords (mirrors
src/password.s bit for bit).

PLAYER password, 32 characters:
    version 2 | cash 24 | gems 12 | level 7 | xp 12 | ladder 4 | secret 1 |
    options 3 | races 12 | wins 12 | losses 12 | crates 10 | street wins 8 |
    best 1/4 ms 15 | its car 4 | top mph 10 | its car 4 | checksum 8
  (15-character version-1 passwords from v3.0, without the stats after
  options, are still accepted.)
GARAGE password, 12-74 characters (grows with the number of cars):
    version 3 | cars-1 3 | car in use 3 |
    per car: model 4, parts as 7 pairs (a*5+b) of 5 bits, body colour 5 |
    checksum 8
  Version 4 (written as 0 in the 2-bit field), 14-85 characters, only when
  a car has an engine or drivetrain swap: after each body colour, the
  record's swap bytes: engine 5 (id + 1, 0 = its own) | drivetrain 2.
  (versions 1-2, 11-66 characters, have 12 parts: still accepted, with no
  wheelie bars or injectors.)
TUNE password (optional, none when every car is stock), any length:
    version 2 | cars-1 3 |
    per car, in garage order: engine tuned 1 | gears tuned 1 |
      engine: fuel map 8 x 4 (cell+5) | timing 4 (+5) | tire psi 5 (+14) |
              boost 5 (+13) | 2-step 6 (rpm/200)
      gears:  final drive, then each gear: changed 1 | if so, 10 bits: the
              change from stock in 3/256 steps (two's complement)
    checksum 8 (CRC-8)

Bits are written MSB first.  Every 5 bits become one character, XORed with a
mask that changes per position (7, 20, 1, 14, ... : +13 mod 32).  The
checksum is a rotate-left-and-add over every field value, seeded differently
for the two passwords so they can't be swapped.

    python3 tools/password.py PLAYERPASSWORD GARAGEPASSWORD   # decode
"""
import sys

ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
SEED_PLAYER, SEED_GARAGE, SEED_TUNE = 0x5A, 0xC3, 0xA5
PLAYER_LEN = 15             # version 1 (v3.0): no stats
PLAYER_LEN2 = 32            # version 2: with stats
NPARTS = 14
NPARTS_OLD = 12             # garage versions 1-2
NCARS = 13
NENGINES = 17               # tools/gamedata.py ENGINES
CRATE_CAR = 12
CASH_MAX = 9999999
PAINT_LIST = [0x16, 0x06, 0x26, 0x27, 0x17, 0x28, 0x38, 0x2A, 0x1A, 0x0A, 0x2C, 0x1C,
              0x21, 0x11, 0x12, 0x02, 0x13, 0x14, 0x24, 0x07, 0x00, 0x10, 0x30, 0x2D]


def garage_len(ncars, version=3):
    per = {4: 51, 3: 44}.get(version, 39)
    return (16 + per * ncars + 4) // 5


class Bits:
    """crc=True: CRC-8 (poly $07) over every field bit -- catches any one
    wrong letter.  crc=False: the version-1 rotate-and-add field sum."""

    def __init__(self, seed, crc=True):
        self.bits = []
        self.pos = 0
        self.chk = seed
        self.crc = crc

    def _sum(self, v):
        self.chk = ((self.chk << 1) | (self.chk >> 7)) & 0xFF
        self.chk = (self.chk + v) & 0xFF

    def _crc_bit(self, bit):
        fb = (self.chk >> 7) ^ bit
        self.chk = (self.chk << 1) & 0xFF
        if fb:
            self.chk ^= 0x07

    def put(self, v, n, chk=True):
        assert 0 <= v < (1 << n), (v, n)
        bits = [(v >> (n - 1 - i)) & 1 for i in range(n)]
        if chk:
            if self.crc:
                for bit in bits:
                    self._crc_bit(bit)
            else:
                self._sum(v)
        self.bits += bits

    def get(self, n, chk=True):
        v = 0
        for _ in range(n):
            bit = self.bits[self.pos] if self.pos < len(self.bits) else 0
            v = v << 1 | bit
            self.pos += 1
            if chk and self.crc:
                self._crc_bit(bit)
        if chk and not self.crc:
            self._sum(v)
        return v

    def text(self, nchars):
        self.bits += [0] * (nchars * 5 - len(self.bits))
        self.pos = 0
        out, m = '', 7
        for _ in range(nchars):
            out += ALPHABET[self.get(5, chk=False) ^ m]
            m = (m + 13) & 31
        return out

    @classmethod
    def from_text(cls, s, seed, crc=True):
        b = cls(seed, crc)
        m = 7
        for c in s:
            b.put(ALPHABET.index(c) ^ m, 5, chk=False)
            m = (m + 13) & 31
        b.chk = seed
        return b


STATS = (('races', 12), ('wins', 12), ('losses', 12), ('crates', 10), ('street', 8),
         ('pbest', 15), ('pbcar', 4), ('topmph', 10), ('topcar', 4))


def put_w(b, v, n):
    """n-bit field (n >= 8): high n-8 bits, then the low byte.  Clamped."""
    v = min(v, (1 << n) - 1)
    if n > 8:
        b.put(v >> 8, n - 8)
    b.put(v & 0xFF, 8)


def get_w(b, n):
    v = b.get(n - 8) << 8 if n > 8 else 0
    return v | b.get(8)


def encode_player(cash, gems, level, xp, ladder, secret, options, stats=None):
    """With stats: version 2, 32 letters.  Without: version 1, 15 letters."""
    b = Bits(SEED_PLAYER, crc=bool(stats))
    b.put(2 if stats else 1, 2)
    for sh in (16, 8, 0):
        b.put(cash >> sh & 0xFF, 8)
    put_w(b, gems, 12)
    b.put(level, 7)
    put_w(b, xp, 12)
    b.put(ladder, 4)
    b.put(secret & 1, 1)
    b.put(options & 7, 3)
    if stats:
        for name, n in STATS:
            if n < 8:
                b.put(stats[name] & ((1 << n) - 1), n)
            else:
                put_w(b, stats[name], n)
    b.put(b.chk, 8, chk=False)
    return b.text(PLAYER_LEN2 if stats else PLAYER_LEN)


def decode_player(s):
    if len(s) not in (PLAYER_LEN, PLAYER_LEN2):
        return None
    b = Bits.from_text(s, SEED_PLAYER, crc=len(s) == PLAYER_LEN2)
    ver = b.get(2)
    if ver != (1 if len(s) == PLAYER_LEN else 2):
        return None
    cash = b.get(8) << 16
    cash |= b.get(8) << 8
    cash |= b.get(8)
    gems = get_w(b, 12)
    level = b.get(7)
    xp = get_w(b, 12)
    ladder, secret, options = b.get(4), b.get(1), b.get(3)
    stats = None
    if ver == 2:
        stats = {name: (b.get(n) if n < 8 else get_w(b, n)) for name, n in STATS}
    want = b.chk
    if b.get(8, chk=False) != want:
        return None
    pad = len(s) * 5 - b.pos
    if pad and b.get(pad, chk=False):                           # padding must be 0
        return None
    if cash > CASH_MAX or not 1 <= level <= 99 or ladder > 11:
        return None
    out = dict(cash=cash, gems=gems, level=level, xp=xp, ladder=ladder,
               secret=secret, options=options)
    if stats:
        if stats['pbcar'] >= NCARS or stats['topcar'] >= NCARS:
            return None
        out['stats'] = stats
    return out


def encode_garage(cars, cur, version=None):
    """cars: list of (model, parts[14], body colour byte[, engine, drive])
    with the record's swap bytes; cur: index.  Version 4 (the default when a
    car is swapped, else 3) adds the swaps; version 3 has 14 parts; versions
    1-2 (v3.0-v4.1) 12.  Versions 2-4 use the CRC; version 1 (v3.0) the
    field sum."""
    if version is None:
        version = 4 if any(any(c[3:]) for c in cars) else 3
    b = Bits(SEED_GARAGE, crc=version >= 2)
    b.put(version & 3, 2)
    b.put(len(cars) - 1, 3)
    b.put(cur, 3)
    n = NPARTS if version >= 3 else NPARTS_OLD
    for model, parts, paint, *swap in cars:
        b.put(model, 4)
        for k in range(0, n, 2):
            b.put(parts[k] * 5 + parts[k + 1], 5)
        b.put(PAINT_LIST.index(paint) if paint in PAINT_LIST else 0, 5)
        if version == 4:
            engine, drive = swap or (0, 0)
            b.put(engine, 5)
            b.put(drive, 2)
    b.put(b.chk, 8, chk=False)
    return b.text(garage_len(len(cars), version))


def decode_garage(s):
    ver = Bits.from_text(s, SEED_GARAGE).get(2, chk=False) or 4
    b = Bits.from_text(s, SEED_GARAGE, crc=ver >= 2)
    b.get(2)
    n = b.get(3) + 1
    cur = b.get(3)
    if len(s) != garage_len(n, ver) or cur >= n:
        return None
    cars = []
    for _ in range(n):
        model = b.get(4)
        parts = []
        for _ in range((NPARTS if ver >= 3 else NPARTS_OLD) // 2):
            v = b.get(5)
            if v > 24:
                return None
            parts += [v // 5, v % 5]
        parts += [0] * (NPARTS - len(parts))
        col = b.get(5)
        if model >= NCARS or col > 23:
            return None
        if ver == 4:
            engine, drive = b.get(5), b.get(2)
            if engine > NENGINES or engine == CRATE_CAR + 1 or \
                    (model == CRATE_CAR and (engine or drive)):
                return None
            cars.append((model, parts, PAINT_LIST[col], engine, drive))
        else:
            cars.append((model, parts, PAINT_LIST[col]))
    want = b.chk
    if b.get(8, chk=False) != want:
        return None
    pad = len(s) * 5 - b.pos
    if pad and b.get(pad, chk=False):                           # padding must be 0
        return None
    return dict(cars=cars, cur=cur)


def _stock_ratios(model):
    import gamedata as gd
    return [gd.gear_raw(gd.CARS[model][7])] + [gd.gear_raw(g) for g in gd.car_gears(model)]


def encode_tune(cars):
    """cars: list of (model, tune, final, gears) in garage order, where tune is
    the 12 signed tune bytes of the record (fuel x8, timing, tire psi, boost,
    2-step rpm/100) and final/gears the 8.8 ratios.  '' if nothing is tuned."""
    b = Bits(SEED_TUNE)
    b.put(1, 2)
    b.put(len(cars) - 1, 3)
    any_tune = False
    for model, tune, final, gears in cars:
        stock = _stock_ratios(model)
        ratios = [final] + list(gears[:len(stock) - 1])
        eng = any(tune)
        gtuned = ratios != stock
        any_tune |= eng or gtuned
        b.put(int(eng), 1)
        b.put(int(gtuned), 1)
        if eng:
            for f in tune[:8]:
                b.put(f + 5, 4)
            b.put(tune[8] + 5, 4)
            b.put(tune[9] + 14, 5)
            b.put(tune[10] + 13, 5)
            b.put(tune[11] // 2, 6)
        if gtuned:
            for r, s in zip(ratios, stock):
                if r == s:
                    b.put(0, 1)
                else:
                    assert (r - s) % 3 == 0
                    b.put(1, 1)
                    b.put((r - s) // 3 & 0x3FF, 10)
    if not any_tune:
        return ''
    b.put(b.chk, 8, chk=False)
    return b.text((len(b.bits) + 4) // 5)


def decode_tune(s, models):
    """-> list of (tune or None, ratios or None) per car, or None if wrong.
    '' (nothing typed) means every car is stock."""
    if not s:
        return [(None, None)] * len(models)
    b = Bits.from_text(s, SEED_TUNE)
    if b.get(2) != 1 or b.get(3) != len(models) - 1:
        return None
    out = []
    for model in models:
        stock = _stock_ratios(model)
        eng, gt = b.get(1), b.get(1)
        tune = ratios = None
        if eng:
            fuel = [b.get(4) - 5 for _ in range(8)]
            tim, tp, bo, la = b.get(4) - 5, b.get(5) - 14, b.get(5) - 13, b.get(6) * 2
            if max(fuel) > 5 or tim > 5 or tp > 8 or bo > 9 or (la and la < 20):
                return None
            tune = fuel + [tim, tp, bo, la]
        if gt:
            ratios = []
            for i, st in enumerate(stock):
                r = st
                if b.get(1):
                    k = b.get(10)
                    r = st + 3 * (k - 1024 if k >= 512 else k)
                lo, hi = (0x200, 0x5FF) if i == 0 else (0x80, 0x4FF)
                if not lo <= r <= hi:
                    return None
                ratios.append(r)
        out.append((tune, ratios))
    want = b.chk
    if b.get(8, chk=False) != want:
        return None
    if len(s) != (b.pos + 4) // 5:
        return None
    if b.pos < len(s) * 5 and b.get(len(s) * 5 - b.pos, chk=False):
        return None
    return out


if __name__ == '__main__':
    if len(sys.argv) == 3:
        print(decode_player(sys.argv[1].upper()))
        print(decode_garage(sys.argv[2].upper()))
    else:
        p = encode_player(3000, 5, 1, 0, 0, 0, 0, dict.fromkeys(dict(STATS), 0))
        g = encode_garage([(0, [0] * 12, 0x27)], 0)
        print('new game:', p, g)
