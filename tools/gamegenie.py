#!/usr/bin/env python3
"""Game Genie codes for Pixel Racer NES.

The Game Genie sits between the cartridge and the console and changes the
byte the CPU reads at one address ($8000-$FFFF).  A 6-letter code always
replaces the byte; an 8-letter code only does so when the original byte
equals a compare value, which keeps it from hitting other banks of a
bank-switched cartridge.  This game keeps its cheat switches in the fixed
bank at $FFC0-$FFC2 (see src/main.s), so the codes keep working across
builds.

Usage:
  gamegenie.py                 print every code (markdown table rows)
  gamegenie.py decode CODE     show address / value / compare
  gamegenie.py apply IN OUT CODE...   write a patched ROM (for testing)
"""
import sys

LETTERS = 'APZLGITYEOXUKSVN'

CHEAT_START_CAR = 0xFFC0
CHEAT_MONEY = 0xFFC1
CHEAT_DEBUG = 0xFFC2


def encode(addr, value, compare=None):
    """Encode a code.  With compare -> 8 letters, else 6."""
    assert 0x8000 <= addr <= 0xFFFF and 0 <= value <= 255
    a = addr - 0x8000
    n = [0] * (8 if compare is not None else 6)
    n[0] = (value & 7) | ((value >> 4) & 8)
    n[1] = ((value >> 4) & 7) | ((a >> 4) & 8)
    n[2] = ((a >> 4) & 7) | (8 if compare is not None else 0)
    n[3] = ((a >> 12) & 7) | (a & 8)
    n[4] = (a & 7) | ((a >> 8) & 8)
    if compare is None:
        n[5] = ((a >> 8) & 7) | (value & 8)
    else:
        n[5] = ((a >> 8) & 7) | (compare & 8)
        n[6] = (compare & 7) | ((compare >> 4) & 8)
        n[7] = ((compare >> 4) & 7) | (value & 8)
    return ''.join(LETTERS[x] for x in n)


def decode(code):
    n = [LETTERS.index(c) for c in code.upper()]
    assert len(n) in (6, 8), code
    addr = 0x8000 + (((n[3] & 7) << 12) | ((n[5] & 7) << 8) | ((n[4] & 8) << 8) |
                     ((n[2] & 7) << 4) | ((n[1] & 8) << 4) | (n[4] & 7) | (n[3] & 8))
    if len(n) == 6:
        value = ((n[1] & 7) << 4) | ((n[0] & 8) << 4) | (n[0] & 7) | (n[5] & 8)
        return addr, value, None
    value = ((n[1] & 7) << 4) | ((n[0] & 8) << 4) | (n[0] & 7) | (n[7] & 8)
    compare = ((n[7] & 7) << 4) | ((n[6] & 8) << 4) | (n[6] & 7) | (n[5] & 8)
    return addr, value, compare


def apply(rom, codes):
    """Return a copy of an iNES image as the CPU would see it with the codes
    in.  Only addresses in the fixed bank ($C000-$FFFF, last 16 KB) are
    supported, which is where all of this game's codes point."""
    rom = bytearray(rom)
    nbanks = rom[4]
    for code in codes:
        addr, value, compare = decode(code)
        assert addr >= 0xC000, 'only fixed-bank codes are supported'
        off = 16 + (nbanks - 1) * 0x4000 + (addr - 0xC000)
        if compare is None or rom[off] == compare:
            rom[off] = value
    return bytes(rom)


def car_names():
    import os
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import gamedata
    return [c[0] for c in gamedata.CARS]


def all_codes():
    """(description, code) for every documented cheat."""
    out = [('Cash is always $9,999,999 (refilled whenever you enter the garage)',
            encode(CHEAT_MONEY, 0x01, 0x00)),
           ('Debug menu: press SELECT in the garage', encode(CHEAT_DEBUG, 0x01, 0x00))]
    for i, name in enumerate(car_names()):
        if i == 0:
            continue                       # the normal starter
        out.append(('New game starts with the %s' % name.strip(), encode(CHEAT_START_CAR, i, 0x00)))
    return out


if __name__ == '__main__':
    if len(sys.argv) >= 3 and sys.argv[1] == 'decode':
        a, v, c = decode(sys.argv[2])
        print('address $%04X value $%02X' % (a, v) + ('' if c is None else ' compare $%02X' % c))
    elif len(sys.argv) >= 5 and sys.argv[1] == 'apply':
        with open(sys.argv[2], 'rb') as f:
            data = apply(f.read(), sys.argv[4:])
        with open(sys.argv[3], 'wb') as f:
            f.write(data)
    else:
        for desc, code in all_codes():
            print('| `%s` | %s |' % (code, desc))
