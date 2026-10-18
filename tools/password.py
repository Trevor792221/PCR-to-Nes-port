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
  (versions 1-2, 11-66 characters, have 12 parts: still accepted, with no
  wheelie bars or injectors.)

Bits are written MSB first.  Every 5 bits become one character, XORed with a
mask that changes per position (7, 20, 1, 14, ... : +13 mod 32).  The
checksum is a rotate-left-and-add over every field value, seeded differently
for the two passwords so they can't be swapped.

    python3 tools/password.py PLAYERPASSWORD GARAGEPASSWORD   # decode
"""
import sys

ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
SEED_PLAYER, SEED_GARAGE = 0x5A, 0xC3
PLAYER_LEN = 15             # version 1 (v3.0): no stats
PLAYER_LEN2 = 32            # version 2: with stats
NPARTS = 14
NPARTS_OLD = 12             # garage versions 1-2
NCARS = 13
CASH_MAX = 9999999
PAINT_LIST = [0x16, 0x06, 0x26, 0x27, 0x17, 0x28, 0x38, 0x2A, 0x1A, 0x0A, 0x2C, 0x1C,
              0x21, 0x11, 0x12, 0x02, 0x13, 0x14, 0x24, 0x07, 0x00, 0x10, 0x30, 0x2D]


def garage_len(ncars, version=3):
    per = 44 if version == 3 else 39
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


def encode_garage(cars, cur, version=3):
    """cars: list of (model, parts[14], body colour byte); cur: index.
    Version 3 has 14 parts; versions 1-2 (v3.0-v4.1) 12.  Versions 2-3 use
    the CRC; version 1 (v3.0) the field sum."""
    b = Bits(SEED_GARAGE, crc=version >= 2)
    b.put(version, 2)
    b.put(len(cars) - 1, 3)
    b.put(cur, 3)
    n = NPARTS if version == 3 else NPARTS_OLD
    for model, parts, paint in cars:
        b.put(model, 4)
        for k in range(0, n, 2):
            b.put(parts[k] * 5 + parts[k + 1], 5)
        b.put(PAINT_LIST.index(paint) if paint in PAINT_LIST else 0, 5)
    b.put(b.chk, 8, chk=False)
    return b.text(garage_len(len(cars), version))


def decode_garage(s):
    ver = Bits.from_text(s, SEED_GARAGE).get(2, chk=False)
    if ver not in (1, 2, 3):
        return None
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
        for _ in range((NPARTS if ver == 3 else NPARTS_OLD) // 2):
            v = b.get(5)
            if v > 24:
                return None
            parts += [v // 5, v % 5]
        parts += [0] * (NPARTS - len(parts))
        col = b.get(5)
        if model >= NCARS or col > 23:
            return None
        cars.append((model, parts, PAINT_LIST[col]))
    want = b.chk
    if b.get(8, chk=False) != want:
        return None
    pad = len(s) * 5 - b.pos
    if pad and b.get(pad, chk=False):                           # padding must be 0
        return None
    return dict(cars=cars, cur=cur)


if __name__ == '__main__':
    if len(sys.argv) == 3:
        print(decode_player(sys.argv[1].upper()))
        print(decode_garage(sys.argv[2].upper()))
    else:
        p = encode_player(3000, 5, 1, 0, 0, 0, 0, dict.fromkeys(dict(STATS), 0))
        g = encode_garage([(0, [0] * 12, 0x27)], 0)
        print('new game:', p, g)
