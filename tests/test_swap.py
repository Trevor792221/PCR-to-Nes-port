"""Engine and drivetrain swaps (garage -> SWAP), paid in gems."""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'tools'))
import gamedata as gd          # noqa: E402
from mkdata import TIERS       # noqa: E402
from harness import *          # noqa: E402,F401,F403
from test_game import new_game, start_race, SV_CARS, SV_CASH   # noqa: E402
from test_features import give_car                             # noqa: E402

G_SWAP = 10
SV_GEMS, SV_LEVEL = 0x6007, 0x600B
CR_PARTS, CR_FUEL, CR_TIMING, CR_TIREP, CR_BOOST, CR_LAUNCH, CR_NOS, CR_SWAP = \
    1, 34, 42, 43, 44, 45, 46, 47
ROTOR = gd.NCARS + 1                         # engine ids after the cars' own
BIG_BLOCK = gd.NCARS + 3


def garage(model, gems=50, level=20, parts=None):
    s = new_game()
    give_car(s, 0, model, 0)
    for i, lv in enumerate(parts or []):
        s.nes[SV_CARS + CR_PARTS + i] = lv
    s.nes[SV_GEMS], s.nes[SV_GEMS + 1] = gems, 0
    s.nes[SV_LEVEL] = level
    return s


def open_swap(s):
    s.garage_goto(G_SWAP)
    s.press(A)
    s.step(60)
    assert s.mem('ui_count') == 3, 'on the SWAP screen'


def pick_engine(s, engine):
    s.list_goto('ui_sel', 0)
    for _ in range(20):
        if gd.SWAP_ENGINES[s.mem('sw_e')] == engine:
            return
        s.press(RIGHT)
        s.step(15)
    raise AssertionError('engine not in the list')


def pick_drive(s, drive):
    s.list_goto('ui_sel', 1)
    while s.mem('sw_d') != drive:
        s.press(RIGHT)
        s.step(15)


class Swap(unittest.TestCase):
    def rec(self, s, off):
        return s.wram(SV_CARS + off)

    def engine(self, s):                         # swap byte: engine + 1 in bits 0-4,
        return self.rec(s, CR_SWAP) & 0x1F       # drivetrain + 1 in bits 5-6

    def drive(self, s):
        return self.rec(s, CR_SWAP) >> 5

    def test_engine_swap(self):
        parts = [3, 2, 1, 2, 1, 1, 2, 3, 0, 0, 1, 0, 0, 2]   # engine and chassis parts
        s = garage(4, parts=parts)                            # Hollis SS: 5.7 V8
        for off, v in ((CR_FUEL, 2), (CR_TIMING, 1), (CR_TIREP, 0xFC), (CR_BOOST, 2), (CR_LAUNCH, 30)):
            s.nes[SV_CARS + off] = v
        cash = s.wram(SV_CASH, 3)
        open_swap(s)
        pick_engine(s, ROTOR)
        s.press(A)
        s.step(60)
        self.assertEqual(self.engine(s), ROTOR + 1)
        self.assertEqual(s.wram(SV_GEMS), 50 - gd.ENGINES[ROTOR][5])
        got = [self.rec(s, CR_PARTS + i) for i in range(14)]
        want = [0 if p in gd.ENGINE_PARTS else lv for p, lv in enumerate(parts)]
        self.assertEqual(got, want, 'engine parts back to stock, the rest kept')
        refund = 0
        for p in gd.ENGINE_PARTS:
            for lv in range(1, parts[p] + 1):
                price = gd.part_cost(p, TIERS[4], lv)
                refund += price - (price >> 2)
        self.assertEqual(s.wram(SV_CASH, 3) - cash, refund, '3/4 of what they cost')
        self.assertEqual([self.rec(s, CR_FUEL), self.rec(s, CR_TIMING), self.rec(s, CR_BOOST),
                          self.rec(s, CR_LAUNCH)], [0, 0, 0, 0], 'engine tune reset')
        self.assertEqual(self.rec(s, CR_TIREP), 0xFC, 'tire pressure kept')
        self.assertEqual(s.mem('lag'), 0)
        # back to its own engine: free
        pick_engine(s, 4)
        s.press(A)
        s.step(60)
        self.assertEqual(self.engine(s), 0)
        self.assertEqual(s.wram(SV_GEMS), 50 - gd.ENGINES[ROTOR][5])

    def test_level_and_gems(self):
        s = garage(0, gems=50, level=3)
        open_swap(s)
        pick_engine(s, BIG_BLOCK)                    # level 10
        s.press(A)
        s.step(30)
        self.assertEqual(self.engine(s), 0, 'too low a level')
        s = garage(0, gems=4, level=20)
        open_swap(s)
        pick_engine(s, 1)                            # 5 gems
        s.press(A)
        s.step(30)
        self.assertEqual(self.engine(s), 0, 'not enough gems')
        self.assertEqual(s.wram(SV_GEMS), 4)

    def test_drivetrain_swap(self):
        s = garage(1)                                # Komet: FWD
        open_swap(s)
        pick_drive(s, gd.AWD)
        s.press(A)
        s.step(60)
        self.assertEqual(self.drive(s), gd.AWD + 1)
        self.assertEqual(s.wram(SV_GEMS), 50 - gd.DRIVE_GEMS)
        pick_drive(s, gd.FWD)                        # back: free
        s.press(A)
        s.step(60)
        self.assertEqual(self.drive(s), 0)
        self.assertEqual(s.wram(SV_GEMS), 50 - gd.DRIVE_GEMS)

    def test_the_crate_car_cant_be_swapped(self):
        s = garage(gd.CRATE_CAR)
        open_swap(s)
        s.press(RIGHT)
        s.step(20)
        s.press(A)
        s.step(30)
        s.list_goto('ui_sel', 1)
        s.press(RIGHT)
        s.step(20)
        s.press(A)
        s.step(30)
        self.assertEqual(self.rec(s, CR_SWAP), 0)
        self.assertEqual(s.wram(SV_GEMS), 50)

    def test_swapped_car_races_with_its_new_engine(self):
        s = garage(0)
        s.nes[SV_CARS + CR_SWAP] = BIG_BLOCK + 1 | (gd.RWD + 1) << 5
        start_race(s, 4)                             # test run
        s.step(20)
        self.assertEqual((s.mem('ph_eng'), s.mem('ph_drv')), (BIG_BLOCK, gd.RWD))
        car = gd.Car(0, [0] * 14, engine=BIG_BLOCK + 1, drive=gd.RWD + 1)
        self.assertEqual(s.mem('ph_redl_l') | s.mem('ph_redl_h') << 8, car.redline)
        self.assertEqual(s.mem('ph_mass_l') | s.mem('ph_mass_h') << 8, car.mass)
        rival = s.mem('ph_model', 1)
        self.assertEqual((s.mem('ph_eng', 1), s.mem('ph_drv', 1)), (rival, gd.CARS[rival][8]),
                         'rivals drive stock')


if __name__ == '__main__':
    unittest.main()
