"""Game Genie codes: run the ROM with each code applied, as the Game Genie
would present it to the console."""
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(os.path.dirname(HERE), 'tools'))
import gamegenie as gg
from harness import *          # noqa: F401,F403
from test_game import SV_CASH, SV_GEMS, SV_LADDER, SV_CARS
SV_XP, SV_LEVEL = 0x6009, 0x600B

CODES = dict((d, c) for d, c in gg.all_codes())
MONEY = gg.encode(gg.CHEAT_MONEY, 1, 0)
DEBUG = gg.encode(gg.CHEAT_DEBUG, 1, 0)


def sim_with(*codes):
    with open(ROM, 'rb') as f:
        data = gg.apply(f.read(), codes)
    fd, path = tempfile.mkstemp(suffix='.nes')
    with os.fdopen(fd, 'wb') as f:
        f.write(data)
    s = Sim(rom=path, boot=120)
    os.unlink(path)
    return s


def new_game(s):
    s.press(DOWN)
    s.press(A)
    s.step(10)
    s.press(A)
    s.step(40)


class Cheats(unittest.TestCase):
    def test_encoder(self):
        self.assertEqual(gg.decode('SXIOPO'), (0x91D9, 0xAD, None))   # well-known code
        for code in CODES.values():
            a, v, c = gg.decode(code)
            self.assertEqual(gg.encode(a, v, c), code)
            self.assertEqual(c, 0)
            self.assertIn(a, (gg.CHEAT_START_CAR, gg.CHEAT_MONEY, gg.CHEAT_DEBUG))

    def test_cheat_table_in_rom(self):
        with open(ROM, 'rb') as f:
            rom = f.read()
        for addr in (gg.CHEAT_START_CAR, gg.CHEAT_MONEY, gg.CHEAT_DEBUG):
            self.assertEqual(rom[16 + 7 * 0x4000 + addr - 0xC000], 0, hex(addr))

    def test_money(self):
        s = sim_with(MONEY)
        new_game(s)
        self.assertEqual(s.wram(SV_CASH, 3), 9999999)

    def test_start_car(self):
        for model in (5, 12):
            s = sim_with(gg.encode(gg.CHEAT_START_CAR, model, 0))
            new_game(s)
            self.assertEqual(s.wram(SV_CARS), model)

    def test_no_codes_no_debug_menu(self):
        s = Sim(boot=120)
        new_game(s)
        s.press(SELECT)
        s.step(30)
        self.assertEqual(s.wram(SV_CASH, 3), 3000)
        self.assertEqual(s.mem('ui_count'), 11, 'still the garage menu')

    def test_sound_test(self):
        s = sim_with(DEBUG)
        new_game(s)
        s.press(SELECT)
        s.step(40)
        s.list_goto('ui_sel', 5)                     # SOUND TEST
        s.press(A)
        s.step(40)
        self.assertEqual(s.mem('ui_count'), 4)
        s.press(LEFT)                                # songs wrap: 0 -> 6
        s.step(5)
        self.assertEqual(s.mem('st_song'), 6)
        s.press(A)
        s.step(10)
        self.assertEqual(s.mem('mus_song'), 6, 'ROAD TO TOKYO playing')
        self.assertTrue(any(s.mem('mus_act', i) for i in range(4)))
        s.list_goto('ui_sel', 1)                     # effects: 1 -> 17 -> 16
        s.press(LEFT)
        s.step(5)
        s.press(LEFT)
        s.step(5)
        self.assertEqual(s.mem('st_sfx'), 16)
        s.press(A, hold=2, release=1)
        rev = s.sym['sfxd_rev']
        self.assertTrue(rev <= s.mem16('sfx2_ptr') < rev + 80, 'engine rev playing')
        s.list_goto('ui_sel', 2)                     # STOP
        s.press(A)
        s.step(5)
        self.assertFalse(s.mem('mus_on'))
        s.press(B)
        s.step(40)
        self.assertEqual(s.mem('ui_count'), 7, 'back in the debug menu')
        self.assertTrue(s.mem('mus_on'), 'garage theme again')

    def test_debug_menu(self):
        s = sim_with(DEBUG)
        new_game(s)
        s.press(SELECT)
        s.step(40)
        self.assertEqual(s.mem('ui_count'), 7, 'debug menu open')
        # add car: pick model 12 (left from 0 wraps to the last car)
        s.press(LEFT)
        s.step(5)
        s.press(A)
        s.step(10)
        self.assertEqual(s.wram(SV_CARS + 48), 12)
        # add $100,000 and 100 gems
        s.list_goto('ui_sel', 2)
        s.press(A)
        s.step(10)
        self.assertEqual(s.wram(SV_CASH, 3), 103000)
        s.list_goto('ui_sel', 3)
        s.press(A)
        s.step(10)
        self.assertEqual(s.wram(SV_GEMS, 2), 105)
        # 1000 XP: level 1 -> 5 (140 + 180 + 220 + 260 used), with the gems
        s.list_goto('ui_sel', 4)
        s.press(A)
        s.step(10)
        self.assertEqual((s.wram(SV_LEVEL), s.wram(SV_XP, 2)), (5, 200))
        self.assertEqual(s.wram(SV_GEMS, 2), 105 + 2 + 2 + 3 + 3)
        # boss race: boss 10 ("PHANTOM" is index 9)
        s.list_goto('ui_sel', 1)
        for _ in range(9):
            s.press(RIGHT)
        s.step(5)
        self.assertEqual(s.mem('dbg_boss'), 9)
        s.press(A)
        s.step(30)
        self.assertEqual(s.mem('game_mode'), 2, 'race started')
        self.assertEqual(s.wram(SV_LADDER), 9)
        self.assertEqual(s.mem('opp_rec'), 9)          # RAIJIN R


if __name__ == '__main__':
    unittest.main()
