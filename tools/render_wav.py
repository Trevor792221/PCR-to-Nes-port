#!/usr/bin/env python3
"""Render the game's (original) music to WAV files.

Emulates src/sound.s: the same sequencer (one tick per sixteenth =
8 frames), instrument envelopes, and the NES APU's pulse, triangle and
noise channels with the APU's non-linear mixer.

Usage: render_wav.py OUTDIR
Writes 01-midnight-garage.wav (two loops), 02-win.wav, 03-lose.wav,
04-showdown.wav (boss theme, two loops), 05-neon-boulevard.wav (second
garage theme), 06-after-hours.wav (the garage at night).
"""
import os
import struct
import sys
import wave

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mkmusic as mm

CPU = 1789773.0
FPS = 60.0988
RATE = 44100
MUS_TEMPO = 8
DUTY = [[0, 1, 0, 0, 0, 0, 0, 0], [0, 1, 1, 0, 0, 0, 0, 0],
        [0, 1, 1, 1, 1, 0, 0, 0], [1, 0, 0, 1, 1, 1, 1, 1]]
TRI = list(range(15, -1, -1)) + list(range(16))
NOISE_PERIOD = [4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068]


def note_period(i):
    midi = 36 + (i - 1)
    f = 440.0 * 2 ** ((midi - 69) / 12)
    return max(8, min(0x7FF, int(round(CPU / (16 * f) - 1))))


class Channel:
    def __init__(self, data):
        self.data, self.pos = data, 0
        self.timer, self.len, self.inst = 1, 1, 0
        self.vol, self.vcnt, self.note = 0, 0, 0
        self.active, self.trig = True, False
        self.loops = 0

    def events(self):
        while True:
            b = self.data[self.pos]
            self.pos += 1
            if b == 0xFF:
                self.pos = 0
                self.loops += 1
            elif b == 0xFE:
                self.active, self.note = False, 0
                return
            elif b >= 0xC0:
                self.inst = b & 0x3F
            elif b >= 0x80:
                self.len = b & 0x3F
            else:
                self.note, self.timer, self.trig = b, self.len, True
                _, v, r, _ = mm.INSTR[self.inst]
                self.vol, self.vcnt = v, r
                return

    def envelope(self):
        _, _, rate, floor = mm.INSTR[self.inst]
        if rate:
            self.vcnt -= 1
            if self.vcnt == 0:
                self.vcnt = rate
                if self.vol > floor:
                    self.vol -= 1


def render(chans, loops):
    chs = [Channel(c) for c in chans]
    tick = MUS_TEMPO - 1
    out = []
    ph = [0.0, 0.0, 0.0]          # pulse 1, pulse 2, triangle phase
    lfsr, nacc = 1, 0.0
    spf = RATE / FPS
    acc = 0.0
    tail = 0
    while True:
        tick += 1
        if tick >= MUS_TEMPO:
            tick = 0
            for c in chs:
                if c.active:
                    c.timer -= 1
                    if c.timer == 0:
                        c.events()
        for c in chs:
            c.envelope()
        if loops and min(c.loops for c in chs[:3]) >= loops:
            break
        if not any(c.active for c in chs):
            tail += 1
            if tail > 30:
                break
        # samples for this frame
        acc += spf
        n = int(acc)
        acc -= n
        p = [chs[0], chs[1]]
        fp = [CPU / (16 * (note_period(c.note) + 1)) if c.note else 0 for c in p]
        duty = [DUTY[mm.INSTR[c.inst][0]] for c in p]
        tri = chs[2]
        ft = CPU / (32 * (note_period(tri.note) + 1)) if tri.note else 0
        noi = chs[3]
        if noi.trig:
            noi.trig = False
        nper = NOISE_PERIOD[(noi.note - 1) & 15] if noi.note else 0
        nstep = CPU / RATE / nper if nper else 0
        for _ in range(n):
            pv = 0
            for k in range(2):
                if fp[k]:
                    ph[k] = (ph[k] + fp[k] * 8 / RATE) % 8
                    pv += p[k].vol * duty[k][int(ph[k])]
            tv = 0
            if ft:
                ph[2] = (ph[2] + ft * 32 / RATE) % 32
                tv = TRI[int(ph[2])]
            nv = 0
            if nper:
                nacc += nstep
                while nacc >= 1:
                    nacc -= 1
                    bit = (lfsr ^ (lfsr >> 1)) & 1
                    lfsr = (lfsr >> 1) | (bit << 14)
                nv = 0 if lfsr & 1 else noi.vol
            po = 95.88 / (8128.0 / pv + 100) if pv else 0.0
            d = tv / 8227.0 + nv / 12241.0
            to = 159.79 / (1.0 / d + 100) if d else 0.0
            out.append(po + to)
    # remove DC, normalise, fade the last 0.5 s of looped songs
    mean = sum(out) / len(out)
    out = [v - mean for v in out]
    peak = max(abs(v) for v in out) or 1
    out = [v / peak * 0.85 for v in out]
    if loops:
        fade = int(RATE * 0.5)
        for i in range(fade):
            out[-fade + i] *= 1 - i / fade
    return out


def write(path, samples):
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(v * 32767)) for v in samples))


def main():
    outdir = sys.argv[1]
    os.makedirs(outdir, exist_ok=True)
    names = {'song_garage': ('01-midnight-garage.wav', 2),
             'song_win': ('02-win.wav', 0), 'song_lose': ('03-lose.wav', 0),
             'song_boss': ('04-showdown.wav', 2),
             'song_neon': ('05-neon-boulevard.wav', 1),
             'song_night': ('06-after-hours.wav', 1)}
    for name, chans in mm.SONGS:
        data = [mm.compile_channel(t, loop, drums) for t, loop, drums in chans]
        fname, loops = names[name]
        samples = render(data, loops)
        write(os.path.join(outdir, fname), samples)
        print('%s: %.1f s' % (fname, len(samples) / RATE))


if __name__ == '__main__':
    main()
