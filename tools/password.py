#!/usr/bin/env python3
"""Reference encoder/decoder for Pixel Racer's two passwords (mirrors
src/password.s bit for bit).

PLAYER password, 15 characters:
    version 2 | cash 24 | gems 12 | level 7 | xp 12 | ladder 4 | secret 1 |
    options 3 | checksum 8
GARAGE password, 11-66 characters (grows with the number of cars):
    version 2 | cars-1 3 | car in use 3 |
    per car: model 4, parts as 6 pairs (a*5+b) of 5 bits, body colour 5 |
    checksum 8

Bits are written MSB first.  Every 5 bits become one character, XORed with a
mask that changes per position (7, 20, 1, 14, ... : +13 mod 32).  The
checksum is a rotate-left-and-add over every field value, seeded differently
for the two passwords so they can't be swapped.

    python3 tools/password.py PLAYERPASSWORD GARAGEPASSWORD   # decode
"""
import sys

ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
VERSION = 1
SEED_PLAYER, SEED_GARAGE = 0x5A, 0xC3
PLAYER_LEN = 15
NPARTS = 12
NCARS = 13
CASH_MAX = 9999999
PAINT_LIST = [0x16, 0x06, 0x26, 0x27, 0x17, 0x28, 0x38, 0x2A, 0x1A, 0x0A, 0x2C, 0x1C,
              0x21, 0x11, 0x12, 0x02, 0x13, 0x14, 0x24, 0x07, 0x00, 0x10, 0x30, 0x2D]


def garage_len(ncars):
    return (16 + 39 * ncars + 4) // 5


class Bits:
    def __init__(self, seed):
        self.bits = []
        self.pos = 0
        self.chk = seed

    def _sum(self, v):
        self.chk = ((self.chk << 1) | (self.chk >> 7)) & 0xFF
        self.chk = (self.chk + v) & 0xFF

    def put(self, v, n, chk=True):
        assert 0 <= v < (1 << n), (v, n)
        if chk:
            self._sum(v)
        self.bits += [(v >> (n - 1 - i)) & 1 for i in range(n)]

    def get(self, n, chk=True):
        v = 0
        for _ in range(n):
            v = v << 1 | (self.bits[self.pos] if self.pos < len(self.bits) else 0)
            self.pos += 1
        if chk:
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
    def from_text(cls, s, seed):
        b = cls(seed)
        m = 7
        for c in s:
            b.put(ALPHABET.index(c) ^ m, 5, chk=False)
            m = (m + 13) & 31
        b.chk = seed
        return b


def encode_player(cash, gems, level, xp, ladder, secret, options):
    b = Bits(SEED_PLAYER)
    gems, xp = min(gems, 4095), min(xp, 4095)
    b.put(VERSION, 2)
    for sh in (16, 8, 0):
        b.put(cash >> sh & 0xFF, 8)
    b.put(gems >> 8, 4)
    b.put(gems & 0xFF, 8)
    b.put(level, 7)
    b.put(xp >> 8, 4)
    b.put(xp & 0xFF, 8)
    b.put(ladder, 4)
    b.put(secret & 1, 1)
    b.put(options & 7, 3)
    b.put(b.chk, 8, chk=False)
    return b.text(PLAYER_LEN)


def decode_player(s):
    if len(s) != PLAYER_LEN:
        return None
    b = Bits.from_text(s, SEED_PLAYER)
    if b.get(2) != VERSION:
        return None
    cash = b.get(8) << 16
    cash |= b.get(8) << 8
    cash |= b.get(8)
    gems = b.get(4) << 8
    gems |= b.get(8)
    level = b.get(7)
    xp = b.get(4) << 8
    xp |= b.get(8)
    ladder, secret, options = b.get(4), b.get(1), b.get(3)
    want = b.chk
    if b.get(8, chk=False) != want or b.get(2, chk=False):    # padding must be 0
        return None
    if cash > CASH_MAX or not 1 <= level <= 99 or ladder > 11:
        return None
    return dict(cash=cash, gems=gems, level=level, xp=xp, ladder=ladder,
                secret=secret, options=options)


def encode_garage(cars, cur):
    """cars: list of (model, parts[12], body colour byte); cur: index."""
    b = Bits(SEED_GARAGE)
    b.put(VERSION, 2)
    b.put(len(cars) - 1, 3)
    b.put(cur, 3)
    for model, parts, paint in cars:
        b.put(model, 4)
        for k in range(0, NPARTS, 2):
            b.put(parts[k] * 5 + parts[k + 1], 5)
        b.put(PAINT_LIST.index(paint) if paint in PAINT_LIST else 0, 5)
    b.put(b.chk, 8, chk=False)
    return b.text(garage_len(len(cars)))


def decode_garage(s):
    b = Bits.from_text(s, SEED_GARAGE)
    if b.get(2) != VERSION:
        return None
    n = b.get(3) + 1
    cur = b.get(3)
    if len(s) != garage_len(n) or cur >= n:
        return None
    cars = []
    for _ in range(n):
        model = b.get(4)
        parts = []
        for _ in range(NPARTS // 2):
            v = b.get(5)
            if v > 24:
                return None
            parts += [v // 5, v % 5]
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
        p = encode_player(3000, 5, 1, 0, 0, 0, 0)
        g = encode_garage([(0, [0] * 12, 0x27)], 0)
        print('new game:', p, g)
