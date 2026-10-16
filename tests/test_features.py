"""Cash cap, the secret 12th boss, the stats page, quit-to-title."""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from harness import *          # noqa: F401,F403
from test_game import new_game, start_race, SV_CASH, SV_GEMS, SV_CARS, G_RACE
from test_physics import record

SV_SECRET, SV_RACES, SV_PBEST, SV_PBCAR, SV_TOPSPD = 0x6018, 0x6019, 0x601B, 0x601D, 0x601E
G_STATS, G_OPTIONS = 9, 8
CASH_MAX = 9999999


def give_car(s, slot, model, level):
    rec = record(model, [level] * 10)
    rec[11:14] = [0x28, 0x10, 0x21]
    for i, b in enumerate(rec[:30]):
        s.nes[SV_CARS + slot * 32 + i] = b


def set_cash(s, value):
    for i in range(3):
        s.nes[SV_CASH + i] = (value >> (8 * i)) & 0xFF


class Features(unittest.TestCase):
    # --- cash ---------------------------------------------------------------
    def test_cash_is_capped(self):
        s = new_game()
        set_cash(s, CASH_MAX - 500)
        start_race(s, 0)                             # first boss pays $800
        drive_race(s, launch=6600, shift_margin=200)
        s.step(30)
        self.assertTrue(s.mem('res_flags') & 1)
        self.assertEqual(s.wram(SV_CASH, 3), CASH_MAX)

    def test_old_save_over_the_cap_is_clamped(self):
        s = new_game()
        set_cash(s, 16000000)
        s.garage_goto(G_OPTIONS)                     # any save_write fixes the checksum
        s.press(A)
        s.step(30)
        s.press(RIGHT)                               # toggle units -> saves
        s.step(10)
        s.nes.reset()
        s.step(120)
        self.assertEqual(s.wram(SV_CASH, 3), CASH_MAX)

    # --- secret boss ----------------------------------------------------------
    def race_select_count(self, s):
        s.garage_goto(G_RACE)
        s.press(A)
        s.step(30)
        return s.mem('ui_count')

    def test_secret_boss_hidden_without_zenith(self):
        s = new_game()
        self.assertEqual(self.race_select_count(s), 6)

    def test_secret_boss_race_and_reward(self):
        s = new_game()
        give_car(s, 0, 12, 4)
        self.assertEqual(self.race_select_count(s), 7)
        s.list_goto('rs_sel', 6)
        s.press(A)
        s.step(5)
        self.assertEqual(s.mem('race_kind'), 4)
        self.assertEqual(s.mem('opp_rec'), 12)       # rival drives a Zenith too
        drive_race(s, launch=9300, shift_margin=150, nitrous_gear=1)
        self.assertTrue(s.mem('res_flags') & 1, 'beat the secret boss')
        s.step(30)
        self.assertEqual(s.wram(SV_SECRET), 1)
        self.assertEqual(s.wram(SV_CASH, 3), 3000 + 500000)
        self.assertGreaterEqual(s.wram(SV_GEMS, 2), 5 + 25)

    # --- stats ----------------------------------------------------------------
    def test_stats_are_tracked(self):
        s = new_game()
        start_race(s, 4)                             # test run, 1/4 mile
        drive_race(s, launch=6600, shift_margin=200)
        s.step(30)
        et = s.mem16('res_et')
        mph = s.mem16('res_mph')
        self.assertEqual(s.wram(SV_RACES, 2), 1)
        self.assertEqual(s.wram(SV_PBEST, 2), et)
        self.assertEqual(s.wram(SV_PBCAR), 0)
        self.assertEqual(s.wram(SV_TOPSPD, 2), mph | 0 << 12)
        self.assertTrue(70 < mph < 90, mph)
        s.press(A)
        s.step(40)
        s.garage_goto(G_STATS)
        s.press(A)
        s.step(40)
        self.assertEqual(s.mem('game_mode'), 1)
        self.assertEqual(s.mem('cur_bank'), 1)       # stats page is up, no crash
        s.press(B)
        s.step(40)
        self.assertEqual(s.mem('ui_count'), 10, 'back in the garage')

    def test_race_backgrounds_vary(self):
        s = new_game()
        seen = set()
        for _ in range(12):
            start_race(s, 4)
            s.step(40)
            seen.add(s.mem('race_theme'))
            self.assertLess(s.mem('race_theme'), 3)
            f = 0
            while s.mem('rc_state') == 0 and f < 400:
                s.step(1, A if rpm(s) < 6600 else 0)
                f += 1
            for f in range(120):
                s.step(1, A | (RIGHT if s.mem('ph_gear') == 0 and f % 4 < 2 else 0))
            self.assertEqual(s.mem('lag'), 0)
            s.step(4, START)
            s.step(4)
            s.step(4, SELECT)
            s.step(60)
        self.assertEqual(seen, {0, 1, 2}, 'day, sunset and night all come up')

    def test_zenith_in_dealer_after_the_legend(self):
        s = new_game()
        s.garage_goto(4)                             # dealer
        s.press(A)
        s.step(40)
        s.press(LEFT)
        s.step(30)
        self.assertEqual(s.mem('dl_model'), 11, 'no Zenith before The Legend')
        s.press(B, hold=12)
        s.step(40)
        s.nes[0x600C] = 11                           # ladder complete
        set_cash(s, 700000)
        s.garage_goto(4)
        s.press(A)
        s.step(40)
        self.assertEqual(s.mem('dl_count'), 13)
        while s.mem('dl_model') != 12:
            s.press(LEFT)
            s.step(30)
        s.press(A)
        s.step(5)
        s.press(A)                                   # confirm
        s.step(10)
        self.assertEqual(s.wram(SV_CARS + 32), 12, 'bought the Zenith')
        self.assertEqual(s.wram(SV_CASH, 3), 100000)

    def test_quit_to_title_from_options(self):
        s = new_game()
        s.garage_goto(G_OPTIONS)
        s.press(A)
        s.step(30)
        s.list_goto('ui_sel', 4)
        s.press(A)
        s.step(40)
        self.assertEqual(s.mem('game_mode'), 0)


if __name__ == '__main__':
    unittest.main()
