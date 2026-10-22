"""Famicom Data Recorder: the save onto tape and back, on py65 with a tape
deck modelled on the Family BASIC keyboard's tape port ($4016 bit 0 out,
bit 1 in, bit 2 on)."""
import bisect
import os
import random
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from cpu import CPU, Memory     # noqa: E402

TP_OK, TP_CANCEL, TP_BAD = 0, 1, 2
SV_CASH, SV_LEVEL = 0x6004, 0x600B
BTN_B = 0x02                    # controller read order: A, B, Select, Start, ...


class Deck(Memory):
    """$4016: records what the game writes to the tape; plays a tape back."""

    def __getitem__(self, a):
        if a == 0x4016:
            v = 0
            if self.pad_bits:                    # controller 1, serially
                v |= self.pad_bits.pop(0)
            if self.on and self.tape is not None:
                v |= self.level(self.cpu.processorCycles - self.t0) << 1
            return v
        if a == 0x4017:
            return 0
        return bytearray.__getitem__(self, a)

    def __setitem__(self, a, v):
        if a == 0x4016:
            if self.recording and v & 4:
                self.writes.append((self.cpu.processorCycles, v & 1))
            if v & 1:                            # strobe: latch the pad
                self.pad_bits = [(self.pad >> i) & 1 for i in range(8)]
            self.on = bool(v & 4)
        Memory.__setitem__(self, a, v)

    def level(self, t):
        i = bisect.bisect_right(self.times, t) - 1
        return self.levels[i] if i >= 0 else 0

    def play(self, edges, pre_roll=30000):
        self.times = [pre_roll + t for t, _ in edges]
        self.levels = [v for _, v in edges]
        self.tape = True
        self.t0 = self.cpu.processorCycles


def machine():
    c = CPU(bank=6)
    deck = Deck(0x10000)
    deck[:] = c.mem
    deck.rom, deck.shift, deck.count = c.mem.rom, 0, 0
    deck.cpu, deck.recording, deck.writes = c.mpu, False, []
    deck.on, deck.tape, deck.pad, deck.pad_bits = False, None, 0, []
    c.mem = c.mpu.memory = deck
    return c


def record(c):
    c.mem.recording = True
    c.call('tape_write', limit=10 ** 8)
    c.mem.recording = False
    w = c.mem.writes
    t0 = w[0][0]
    return [(t - t0, v) for t, v in w]


def variant(edges, kind='direct', speed=1.0, jitter=0.0, seed=1):
    rnd = random.Random(seed)
    if kind == 'mesen':                          # each stretch gets the next write's level
        edges = [(t, edges[i + 1][1]) for i, (t, _) in enumerate(edges[:-1])]
    elif kind == 'inverted':
        edges = [(t, 1 - v) for t, v in edges]
    out, last = [], -1
    for t, v in edges:
        t = int(t * speed + rnd.uniform(-jitter, jitter))
        t = max(t, last + 1)
        out.append((t, v))
        last = t
    return out


class Tape(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        c = machine()
        c.call('new_game')
        c.mem[SV_CASH:SV_CASH + 3] = (123456).to_bytes(3, 'little')
        c.mem[SV_LEVEL] = 17
        c.call('save_write')
        cls.saved = bytes(c.mem[0x6000:0x6200])
        cls.tape = record(c)

    def load(self, edges, pad=0):
        c = machine()
        c.call('new_game')                       # another game in the console
        c.mem.pad = pad
        c.mem.play(edges)
        result = c.call('tape_read', limit=10 ** 8)
        return c, result

    def test_a_save_comes_back_off_the_tape(self):
        c, result = self.load(self.tape)
        self.assertEqual(result, TP_OK)
        c.call('tape_take')
        self.assertFalse(c.mpu.p & 1, 'taken')
        self.assertEqual(bytes(c.mem[0x6000:0x6200]), self.saved)
        self.assertEqual(int.from_bytes(c.mem[SV_CASH:SV_CASH + 3], 'little'), 123456)
        self.assertEqual(bytes(c.mem[0x7000:0x7200]), self.saved, 'and backed up')

    def test_any_deck_any_polarity_speed_and_wobble(self):
        # Mesen records each stretch with the level written at its end;
        # a real deck may flip the signal, run fast or slow, and wobble
        for kind, speed, jitter in (('mesen', 1, 0), ('inverted', 1, 0), ('direct', .9, 0),
                                    ('direct', 1.1, 0), ('mesen', 1.08, 60), ('inverted', .92, 60),
                                    ('direct', .85, 80), ('mesen', 1.15, 80)):
            c, result = self.load(variant(self.tape, kind, speed, jitter))
            self.assertEqual(result, TP_OK, (kind, speed, jitter))
            self.assertEqual(bytes(c.mem[0x6400:0x6600]), self.saved, (kind, speed, jitter))

    def test_a_bad_bit_is_caught_and_the_game_stays(self):
        t = self.tape
        k = len(t) - 2000                            # near the end, in the save:
        while not (t[k + 1][0] - t[k][0] < 600 and t[k + 2][0] - t[k + 1][0] < 600):
            k += 1                                   # two short halves (a 0 bit)
        # stretch both by 400 cycles: that 0 now reads as a 1
        bad = t[:k + 1] + [(u + 400, v) for u, v in t[k + 1:k + 2]] + \
            [(u + 800, v) for u, v in t[k + 2:]]
        c, result = self.load(bad)
        self.assertEqual(result, TP_BAD)
        self.assertNotEqual(int.from_bytes(c.mem[SV_CASH:SV_CASH + 3], 'little'), 123456)

    def test_b_gives_up_on_a_silent_tape(self):
        c, result = self.load([(0, 0)], pad=BTN_B)
        self.assertEqual(result, TP_CANCEL)
        self.assertLess(c.cycles, 1789773, 'within a second')

    def test_a_tape_from_another_version_is_refused(self):
        c = machine()
        c.call('new_game')
        c.mem[0x6003] ^= 1                           # another save layout ("PXR4" -> "PXR5")
        c.call('save_write')
        tape = record(c)
        c, result = self.load(tape)
        self.assertEqual(result, TP_OK, 'it reads fine')
        before = bytes(c.mem[0x6000:0x6200])
        c.call('tape_take')
        self.assertTrue(c.mpu.p & 1, 'but is not taken')
        self.assertEqual(bytes(c.mem[0x6000:0x6200]), before, 'the game stays')

    def test_tape_length(self):
        seconds = self.tape[-1][0] / 1789773
        self.assertLess(seconds, 6)


if __name__ == '__main__':
    unittest.main()
