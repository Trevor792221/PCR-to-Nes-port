#!/usr/bin/env python3
"""Compile the game's music (original compositions) to ca65 data.

Channel streams:
  $00          rest for the current length
  $01-$5F      note (index into note_lo/note_hi), or noise period+1
  $80+n        set length to n sixteenths (n < $40)
  $C0+n        set instrument n
  $FE          end (stop the channel)
  $FF lo hi    jump
"""
import sys

NOTE = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
# note index 1 = C2
def note_index(tok):
    name = tok[0]
    acc = 0
    rest = tok[1:]
    if rest.startswith('#'):
        acc, rest = 1, rest[1:]
    elif rest.startswith('b'):
        acc, rest = -1, rest[1:]
    octave = int(rest)
    return (octave - 2) * 12 + NOTE[name] + acc + 1

DRUMS = {  # token -> (instrument, noise period)
    'K': (5, 12),
    'S': (6, 6),
    'H': (7, 1),
    'O': (8, 2),
}

# Instruments: duty (0-3), start volume, frames per volume step, floor
INSTR = [
    (2, 10, 3, 4),    # 0 lead
    (1, 7, 2, 2),     # 1 stab
    (0, 15, 0, 15),   # 2 triangle (volume ignored)
    (2, 9, 6, 6),     # 3 soft lead (long notes)
    (1, 6, 4, 0),     # 4 echo
    (0, 13, 1, 0),    # 5 kick
    (0, 11, 1, 0),    # 6 snare
    (0, 6, 1, 0),     # 7 hat
    (0, 8, 2, 0),     # 8 open hat
    (2, 12, 4, 0),    # 9 jingle lead
]

BEAT = 8   # frames per 16th note (~112 bpm); lengths are stored in 16ths


def compile_channel(text, loop=True, drums=False):
    out = []
    length = None
    for tok in text.split():
        if tok == '|':
            continue
        if tok.startswith('I'):
            out.append(0xC0 + int(tok[1:]))
            continue
        # 'X:n' = note X lasting n sixteenths
        if ':' in tok:
            tok, d = tok.split(':')
            dur = int(d)
            assert dur < 64
            if dur != length:
                out.append(0x80 + dur)
                length = dur
        if tok == 'R':
            out.append(0)
        elif drums:
            inst, per = DRUMS[tok]
            out.append(0xC0 + inst)
            out.append(per + 1)
        else:
            out.append(note_index(tok))
    out.append(0xFF if loop else 0xFE)
    return out


# ---------------------------------------------------------------------------
# "Midnight Garage" -- title / garage theme.  A minor, 112 bpm.
# Token 'X:n' = note X lasting n sixteenths.
# ---------------------------------------------------------------------------
GARAGE_LEAD = '''
I0 A4:2 C5:2 E5:2 A5:2 G5:4 E5:2 D5:2 | C5:2 D5:2 E5:4 D5:2 C5:2 B4:4
   F4:2 A4:2 C5:2 F5:2 E5:4 C5:2 A4:2 | G4:2 B4:2 D5:2 G5:2 E5:8
   A4:2 C5:2 E5:2 A5:2 B5:4 A5:2 G5:2 | E5:2 G5:2 A5:4 G5:2 E5:2 D5:4
   F5:2 E5:2 D5:2 C5:2 D5:4 E5:2 F5:2 | E5:4 D5:2 B4:2 A4:8
I3 C5:4 B4:4 A4:4 G4:4 | A4:8 E4:8 | F4:4 G4:4 A4:4 C5:4 | B4:12 R:4
   C5:4 D5:4 E5:4 G5:4 | A5:8 G5:4 E5:4 | F5:4 E5:4 D5:4 B4:4 | A4:12 R:4
'''
GARAGE_HARM = '''
I1 R:2 E4:2 R:2 E4:2 R:2 E4:2 R:2 E4:2 | R:2 E4:2 R:2 E4:2 R:2 D4:2 R:2 D4:2
   R:2 C4:2 R:2 C4:2 R:2 C4:2 R:2 C4:2 | R:2 D4:2 R:2 D4:2 R:2 B3:2 R:2 B3:2
   R:2 E4:2 R:2 E4:2 R:2 E4:2 R:2 E4:2 | R:2 E4:2 R:2 E4:2 R:2 D4:2 R:2 D4:2
   R:2 A4:2 R:2 A4:2 R:2 G4:2 R:2 G4:2 | R:2 E4:2 R:2 E4:2 R:2 C4:2 R:2 C4:2
I4 E4:4 D4:4 C4:4 B3:4 | C4:8 B3:8 | A3:4 B3:4 C4:4 E4:4 | D4:12 R:4
   E4:4 F4:4 G4:4 B4:4 | C5:8 B4:4 G4:4 | A4:4 G4:4 F4:4 D4:4 | C4:12 R:4
'''
GARAGE_BASS = '''
I2 A2:2 A2:2 A3:2 A2:2 A2:2 A2:2 A3:2 G2:2 | A2:2 A2:2 A3:2 A2:2 G2:2 G2:2 G3:2 G2:2
   F2:2 F2:2 F3:2 F2:2 F2:2 F2:2 F3:2 F2:2 | G2:2 G2:2 G3:2 G2:2 E2:2 E2:2 E3:2 E2:2
   A2:2 A2:2 A3:2 A2:2 A2:2 A2:2 A3:2 G2:2 | A2:2 A2:2 A3:2 A2:2 G2:2 G2:2 G3:2 G2:2
   F2:2 F2:2 F3:2 F2:2 G2:2 G2:2 G3:2 G2:2 | A2:2 A2:2 E3:2 E2:2 A2:2 A2:2 A3:2 A2:2
   F2:4 F3:4 F2:4 F3:4 | A2:4 A3:4 E2:4 E3:4 | D2:4 D3:4 F2:4 F3:4 | G2:4 G3:4 G2:4 G3:4
   C3:4 C3:4 E2:4 E2:4 | F2:4 F3:4 G2:4 G3:4 | D2:4 D3:4 E2:4 E3:4 | A2:4 A3:4 A2:8
'''
GARAGE_DRUM = '''
K:2 H:2 S:2 H:2 K:2 K:2 S:2 H:2 | K:2 H:2 S:2 H:2 K:2 K:2 S:2 O:2
K:2 H:2 S:2 H:2 K:2 K:2 S:2 H:2 | K:2 H:2 S:2 H:2 K:2 S:2 S:2 S:2
K:2 H:2 S:2 H:2 K:2 K:2 S:2 H:2 | K:2 H:2 S:2 H:2 K:2 K:2 S:2 O:2
K:2 H:2 S:2 H:2 K:2 K:2 S:2 H:2 | K:2 H:2 S:2 H:2 K:2 S:2 S:2 S:2
K:4 H:4 S:4 H:4 | K:4 H:4 S:4 O:4 | K:4 H:4 S:4 H:4 | K:4 S:4 S:2 S:2 S:4
K:4 H:4 S:4 H:4 | K:4 H:4 S:4 O:4 | K:4 H:4 S:4 H:4 | K:4 S:4 S:2 S:2 S:4
'''

# ---------------------------------------------------------------------------
# "Showdown" -- boss intro theme.  E minor, same tempo, driving 16th bass.
# Em | Em | C | B | Em | Em | C B7 | Em
# ---------------------------------------------------------------------------
BOSS_LEAD = '''
I0 E5:2 R:1 E5:1 G5:2 B5:2 A5:4 G5:2 F#5:2 | E5:6 D5:2 B4:8
   C5:2 R:1 C5:1 E5:2 G5:2 F#5:4 E5:2 D5:2 | B4:12 R:4
   E5:2 R:1 E5:1 G5:2 B5:2 C6:4 B5:2 A5:2 | G5:4 A5:2 B5:2 E6:8
   D6:2 C6:2 B5:2 A5:2 G5:2 F#5:2 E5:2 D#5:2 | E5:12 R:4
'''
BOSS_HARM = '''
I1 R:2 B4:2 R:2 G4:2 R:2 B4:2 R:2 G4:2 | R:2 B4:2 R:2 G4:2 R:2 F#4:2 R:2 F#4:2
   R:2 G4:2 R:2 E4:2 R:2 G4:2 R:2 E4:2 | R:2 F#4:2 R:2 D#4:2 R:2 F#4:2 R:2 D#4:2
   R:2 B4:2 R:2 G4:2 R:2 B4:2 R:2 G4:2 | R:2 B4:2 R:2 G4:2 R:2 B4:2 R:2 G4:2
   R:2 G4:2 R:2 E4:2 R:2 F#4:2 R:2 D#4:2 | R:2 B4:2 R:2 G4:2 G4:4 R:4
'''
_E = 'E2:1 E2:1 E3:1 E2:1 ' * 4
_C = 'C3:1 C3:1 C4:1 C3:1 ' * 4
_B = 'B2:1 B2:1 B3:1 B2:1 ' * 4
BOSS_BASS = 'I2 ' + _E + _E + _C + _B + _E + _E + _C[:len(_C) // 2] + _B[:len(_B) // 2] + _E
_BEAT = 'K:2 H:1 H:1 S:2 H:2 K:2 K:2 S:2 H:2 '
_FILL = 'K:2 H:2 S:2 H:2 S:1 S:1 S:2 S:2 S:2 '
BOSS_DRUM = (_BEAT * 3 + _FILL) * 2

# ---------------------------------------------------------------------------
# "Neon Boulevard" -- second garage theme (picked at random after races).
# G major, 16 bars:  G Em C D G Em C-D G | Am D G Em C D Bm-Em Am-D
# ---------------------------------------------------------------------------
NEON_LEAD = '''
I0 D5:2 G5:2 B5:2 D6:2 B5:4 A5:2 G5:2 | E5:2 G5:2 B5:4 A5:2 G5:2 E5:4
   C5:2 E5:2 G5:2 C6:2 B5:4 G5:2 E5:2 | F#5:4 A5:4 D6:4 C6:2 A5:2
   B5:2 D6:2 B5:2 G5:2 A5:4 B5:4 | G5:2 E5:2 G5:2 B5:2 E6:8
   C6:4 B5:2 A5:2 B5:4 A5:2 F#5:2 | G5:12 R:4
I3 A5:3 G5:1 E5:4 C5:4 E5:4 | F#5:3 E5:1 D5:4 A4:4 D5:4
   G5:3 F#5:1 D5:4 B4:4 D5:4 | E5:3 D5:1 B4:4 G4:4 B4:4
   C5:4 E5:4 G5:4 C6:4 | D6:4 C6:4 A5:4 F#5:4
   B5:4 A5:4 G5:4 E5:4 | A5:4 B5:2 C6:2 D6:8
'''
def _stab(a, b, c=None, d=None):
    c, d = c or a, d or b
    return 'R:2 %s:2 R:2 %s:2 R:2 %s:2 R:2 %s:2 ' % (a, b, c, d)
NEON_HARM = 'I1 ' + ''.join([
    _stab('B4', 'D5'), _stab('G4', 'B4'), _stab('E4', 'G4'), _stab('F#4', 'A4'),
    _stab('B4', 'D5'), _stab('G4', 'B4'), _stab('E4', 'G4', 'F#4', 'A4'), _stab('B4', 'D5'),
    _stab('C5', 'E5'), _stab('F#4', 'A4'), _stab('B4', 'D5'), _stab('G4', 'B4'),
    _stab('E4', 'G4'), _stab('F#4', 'A4'), _stab('D4', 'F#4', 'E4', 'G4'), _stab('A4', 'C5', 'F#4', 'A4')])
def _oct(r1, r2=None):
    r2 = r2 or r1
    lo1, hi1 = r1 + '2', r1 + '3'
    lo2, hi2 = r2 + '2', r2 + '3'
    return '%s:2 %s:2 %s:2 %s:2 %s:2 %s:2 %s:2 %s:2 ' % (lo1, hi1, lo1, hi1, lo2, hi2, lo2, hi2)
NEON_BASS = 'I2 ' + ''.join([
    _oct('G'), _oct('E'), _oct('C'), _oct('D'), _oct('G'), _oct('E'), _oct('C', 'D'), _oct('G'),
    _oct('A'), _oct('D'), _oct('G'), _oct('E'), _oct('C'), _oct('D'), _oct('B', 'E'), _oct('A', 'D')])
_NB = 'K:2 H:2 S:2 H:2 K:2 H:2 S:2 H:2 '
_NF = 'K:2 H:2 S:2 H:2 S:1 S:1 S:2 K:2 S:2 '
NEON_DRUM = (_NB * 7 + _NF) * 2

# short jingles (do not loop)
WIN_LEAD = 'I9 C5:1 E5:1 G5:1 C6:3 R:1 A5:1 C6:6'
WIN_HARM = 'I1 E4:1 G4:1 C5:1 E5:3 R:1 F5:1 E5:6'
WIN_BASS = 'I2 C3:2 G2:2 C3:2 F2:2 C3:6'
LOSE_LEAD = 'I9 E5:2 D#5:2 D5:2 C#5:8'
LOSE_HARM = 'I1 C5:2 B4:2 A#4:2 A4:8'
LOSE_BASS = 'I2 A2:2 G#2:2 G2:2 F#2:8'
SILENT = 'R:1'

SONGS = [
    ('song_garage', [(GARAGE_LEAD, True, False), (GARAGE_HARM, True, False),
                     (GARAGE_BASS, True, False), (GARAGE_DRUM, True, True)]),
    ('song_win', [(WIN_LEAD, False, False), (WIN_HARM, False, False),
                  (WIN_BASS, False, False), (SILENT, False, True)]),
    ('song_lose', [(LOSE_LEAD, False, False), (LOSE_HARM, False, False),
                   (LOSE_BASS, False, False), (SILENT, False, True)]),
    ('song_boss', [(BOSS_LEAD, True, False), (BOSS_HARM, True, False),
                   (BOSS_BASS, True, False), (BOSS_DRUM, True, True)]),
    ('song_neon', [(NEON_LEAD, True, False), (NEON_HARM, True, False),
                   (NEON_BASS, True, False), (NEON_DRUM, True, True)]),
]


def main():
    lines = ['; generated by tools/mkmusic.py -- original music']
    # note period table, index 1 = C2 ... 72 notes
    lo, hi = [0], [0]
    for i in range(1, 80):
        midi = 36 + (i - 1)            # C2 = midi 36
        f = 440.0 * 2 ** ((midi - 69) / 12)
        p = int(round(1789773 / (16 * f) - 1))
        p = max(8, min(0x7FF, p))
        lo.append(p & 0xFF)
        hi.append(p >> 8)
    lines.append('note_lo: .byte ' + ', '.join('$%02X' % x for x in lo))
    lines.append('note_hi: .byte ' + ', '.join('$%02X' % x for x in hi))
    lines.append('instr_duty: .byte ' + ', '.join('$%02X' % (d << 6) for d, v, r, f in INSTR))
    lines.append('instr_vol:  .byte ' + ', '.join('%d' % v for d, v, r, f in INSTR))
    lines.append('instr_rate: .byte ' + ', '.join('%d' % r for d, v, r, f in INSTR))
    lines.append('instr_floor: .byte ' + ', '.join('%d' % f for d, v, r, f in INSTR))
    lines.append('song_table:')
    for name, _ in SONGS:
        lines.append('        .word %s_0, %s_1, %s_2, %s_3' % ((name,) * 4))
    for name, chans in SONGS:
        for ci, (text, loop, drums) in enumerate(chans):
            data = compile_channel(text, loop, drums)
            label = '%s_%d' % (name, ci)
            lines.append(label + ':')
            if loop:
                data = data[:-1]
                for k in range(0, len(data), 16):
                    lines.append('        .byte ' + ', '.join('$%02X' % b for b in data[k:k + 16]))
                lines.append('        .byte $FF')
                lines.append('        .word ' + label)
            else:
                for k in range(0, len(data), 16):
                    lines.append('        .byte ' + ', '.join('$%02X' % b for b in data[k:k + 16]))
    lines.append('SONG_GARAGE = 0')
    lines.append('SONG_WIN = 1')
    lines.append('SONG_LOSE = 2')
    lines.append('SONG_BOSS = 3')
    lines.append('SONG_NEON = 4')
    open(sys.argv[1], 'w').write('\n'.join(lines) + '\n')


if __name__ == '__main__':
    main()
