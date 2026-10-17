"""Cash cap, the secret 12th boss, the stats page, quit-to-title."""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from harness import *          # noqa: F401,F403
from test_game import new_game, start_race, SV_CASH, SV_GEMS, SV_CARS, G_RACE, G_TUNE, G_DYNO
from test_physics import record

SV_SECRET, SV_RACES, SV_PBEST, SV_PBCAR, SV_TOPSPD = 0x6018, 0x6019, 0x601B, 0x601D, 0x601E
G_STATS, G_OPTIONS = 9, 8
CASH_MAX = 9999999


def give_car(s, slot, model, level):
    rec = record(model, [level] * 12)
    rec[13:16] = [0x28, 0x10, 0x21]
    for i, b in enumerate(rec):
        s.nes[SV_CARS + slot * 32 + i] = b


def save_sum(s, end):
    """The game's rotating checksum of $6004..end-1."""
    t0 = t1 = 0
    for addr in range(0x6004, end):
        v = s.wram(addr) + t0
        t0, a = v & 0xFF, t1 + (v >> 8)
        c = t0 >> 7
        t0 = (t0 << 1) & 0xFF
        c2 = (a >> 7) & 1
        t1 = ((a << 1) | c) & 0xFF
        if c2:
            t0 = (t0 + 1) & 0xFF
    return t0, t1


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

    def test_old_save_is_converted(self):
        """A v1 save (10 parts, best time in the record) loads with its cars,
        paint, gearing and best times intact."""
        s = new_game()
        old = [3, 1, 2, 3, 4, 0, 1, 2, 3, 4, 0,      # model + 10 parts
               0x16, 0x10, 0x21, 0x20, 0x03] + list(range(100, 114)) + [0x34, 0x12]
        for i, b in enumerate(old):
            s.nes[SV_CARS + i] = b
        s.nes[SV_CARS + 32] = 0xFF                   # slot 1 empty but has junk
        s.nes[SV_CARS + 32 + 30] = 0x99
        for i, c in enumerate(b'PXR1'):
            s.nes[0x6000 + i] = c
        t0, t1 = save_sum(s, 0x6120)
        s.nes[0x6120], s.nes[0x6121] = t0, t1
        s.nes.reset()
        s.step(120)
        self.assertEqual(bytes(s.wram(0x6000 + i) for i in range(4)), b'PXR2')
        rec = [s.wram(SV_CARS + i) for i in range(32)]
        self.assertEqual(rec[:11], old[:11])
        self.assertEqual(rec[11:13], [0, 0], 'new parts start stock')
        self.assertEqual(rec[13:16], [0x16, 0x10, 0x21])
        self.assertEqual(rec[16:18], [0x20, 0x03])
        self.assertEqual(rec[18:32], list(range(100, 114)))
        self.assertEqual(s.wram(0x6120, 2), 0x1234)
        self.assertEqual(s.wram(0x6122, 2), 0, 'empty slot: no best')
        self.assertEqual(s.wram(SV_CASH, 3), 3000, 'kept, not a new game')
        self.assertEqual(save_sum(s, 0x6130), (s.wram(0x6130), s.wram(0x6131)))

    # --- secret boss ----------------------------------------------------------
    def race_select_count(self, s):
        s.garage_goto(G_RACE)
        s.press(A)
        s.step(30)
        return s.mem('ui_count')

    def test_secret_boss_hidden_without_zenith(self):
        s = new_game()
        self.assertEqual(self.race_select_count(s), 7)

    def test_secret_boss_race_and_reward(self):
        s = new_game()
        give_car(s, 0, 12, 4)
        self.assertEqual(self.race_select_count(s), 8)
        s.list_goto('rs_sel', 7)
        s.press(A)
        s.step(45)
        self.assertEqual(s.mem('bi_boss'), 11, 'intro: ECLIPSE')
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

    def test_cruise_mode(self):
        s = new_game()
        s.garage_goto(G_RACE)
        s.press(A)
        s.step(30)
        s.list_goto('rs_sel', 5)
        s.press(A)
        s.step(40)
        self.assertEqual(s.mem('race_kind'), 5)
        self.assertEqual(s.mem('rc_opp'), 0, 'no rival')
        self.assertEqual(s.mem('rc_state'), 1, 'no start lights')
        traffic = 0
        for f in range(4000):                        # past the 60 s race limit
            b = A
            if s.mem('ph_gear') == 0:
                b |= RIGHT if f % 4 < 2 else 0
            elif (rpm(s) >= redline(s) - 300 and s.mem('ph_shift_t') == 0
                  and s.mem('ph_slip') == 0 and f % 4 < 2):
                b |= RIGHT
            s.step(1, b)
            traffic = max(traffic, sum(s.mem('tr_on', i) for i in range(3)))
        self.assertEqual(s.mem('game_mode'), 2, 'still cruising')
        self.assertEqual(s.mem('lag'), 0)
        self.assertGreater(traffic, 0)
        self.assertEqual(s.wram(SV_RACES, 2), 0, 'cruising is not a race')
        s.press(START)
        s.step(10)
        s.press(SELECT)
        s.step(2)
        self.assertEqual(s.mem('game_mode'), 1, 'quit straight to the garage')

    def test_cruise_nitrous_is_unlimited(self):
        s = new_game()
        give_car(s, 0, 2, 2)                         # sport nitrous
        s.garage_goto(G_RACE)
        s.press(A)
        s.step(30)
        s.list_goto('rs_sel', 5)
        s.press(A)
        s.step(40)
        shots = 0
        for f in range(3000):
            b = A
            if s.mem('ph_gear') == 0:
                b |= RIGHT if f % 4 < 2 else 0
            elif (rpm(s) >= redline(s) - 300 and s.mem('ph_shift_t') == 0
                  and s.mem('ph_slip') == 0 and f % 4 < 2):
                b |= RIGHT
            if s.mem('ph_gear') >= 2 and f % 8 < 2:
                b |= B
            was = s.mem('ph_nos_on')
            s.step(1, b)
            shots += not was and s.mem('ph_nos_on')
        self.assertGreaterEqual(shots, 3, 'bottle refills while cruising')

    def test_cruise_without_traffic(self):
        s = new_game()
        s.garage_goto(G_RACE)
        s.press(A)
        s.step(30)
        s.list_goto('rs_sel', 5)
        s.press(RIGHT)                               # traffic off
        s.step(5)
        self.assertEqual(s.mem('cruise_empty'), 1)
        s.press(A)
        s.step(40)
        self.assertEqual(s.mem('race_kind'), 5)
        for f in range(1500):
            b = A
            if s.mem('ph_gear') == 0:
                b |= RIGHT if f % 4 < 2 else 0
            elif (rpm(s) >= redline(s) - 300 and s.mem('ph_shift_t') == 0
                  and f % 4 < 2):
                b |= RIGHT
            s.step(1, b)
            self.assertEqual(sum(s.mem('tr_on', i) for i in range(3)), 0)

    def test_traffic_variety(self):
        s = new_game()
        s.garage_goto(G_RACE)
        s.press(A)
        s.step(30)
        s.list_goto('rs_sel', 5)
        s.press(A)
        s.step(40)
        types, pals = set(), set()
        for f in range(6000):                        # about 25 vehicles
            b = A
            if s.mem('ph_gear') == 0:
                b |= RIGHT if f % 4 < 2 else 0
            elif (rpm(s) >= redline(s) - 300 and s.mem('ph_shift_t') == 0
                  and f % 4 < 2):
                b |= RIGHT
            s.step(1, b)
            for i in range(3):
                if s.mem('tr_on', i):
                    types.add(s.mem('tr_type', i))
                    pals.add(s.mem('tr_pal', i))
        self.assertEqual(types, {0, 1, 2, 3, 4}, 'sedan, hatch, pickup, van, box truck')
        self.assertEqual(pals, {2, 3}, 'two traffic colours when cruising')
        self.assertEqual(s.mem('lag'), 0)

    def test_one_mile_race(self):
        s = new_game()
        s.garage_goto(G_RACE)
        s.press(A)
        s.step(30)
        s.list_goto('rs_sel', 2)
        s.press(LEFT)                                # 1/4 -> 1 mile
        s.step(5)
        self.assertEqual(s.mem('race_half'), 2)
        s.list_goto('rs_sel', 4)                     # test run
        s.press(A)
        s.step(40)
        self.assertEqual(s.mem16('race_dist'), 6436)
        drive_race(s, launch=4500, shift_margin=300, max_frames=4500)
        s.step(60)
        self.assertEqual(s.mem('game_mode'), 3)
        et = s.mem16('res_et')
        self.assertTrue(40000 < et < 55000, et)      # model: 46.9 s
        self.assertEqual(s.wram(SV_PBEST, 2), 0, 'not a 1/4 mile time')

    def test_seven_gear_tune_menu(self):
        s = new_game()
        give_car(s, 0, 11, 4)                        # Nova Hyper, race gearbox
        s.garage_goto(G_TUNE)
        s.press(A)
        s.step(40)
        self.assertEqual(s.mem('ui_count'), 10, 'final, 7 gears, reset, back')
        rec = SV_CARS
        g1 = s.wram(rec + 18, 2)
        s.list_goto('ui_sel', 1)
        s.press(RIGHT)
        s.step(5)
        self.assertNotEqual(s.wram(rec + 18, 2), g1)
        s.list_goto('ui_sel', 8)                     # RESET TO STOCK
        s.press(A)
        s.step(10)
        self.assertEqual(s.wram(rec + 18, 2), g1)

    def test_dyno_hp_matches_the_garage(self):
        for model, lvl in ((0, 0), (5, 2), (11, 4)):
            s = new_game()
            give_car(s, 0, model, lvl)
            s.garage_goto(G_OPTIONS)                 # back out: the garage redraws
            s.press(A)
            s.step(30)
            s.press(B, hold=12)
            s.step(60)
            self.assertEqual(s.mem('cur_bank'), 1)
            garage = s.mem16('ep_hp')
            s.garage_goto(G_DYNO)
            s.press(A)
            s.step(30)
            s.press(A)
            s.step(400)
            self.assertEqual(s.mem16('ep_hp'), garage)

    def test_boss_intro_back_and_race(self):
        s = new_game()
        s.garage_goto(G_RACE)
        s.press(A)
        s.step(30)
        s.press(A)                                   # LADDER BOSS
        s.step(45)
        self.assertEqual(s.mem('bi_boss'), 0)
        self.assertEqual(s.mem('game_mode'), 1, 'intro, not racing yet')
        s.press(B)                                   # back to race select
        s.step(40)
        self.assertEqual(s.mem('ui_count'), 7)
        self.assertEqual(s.mem('game_mode'), 1)
        s.press(A)
        s.step(45)
        s.press(A)                                   # race
        s.step(60)
        self.assertEqual(s.mem('game_mode'), 2)
        self.assertEqual(s.mem('race_kind'), 0)

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
