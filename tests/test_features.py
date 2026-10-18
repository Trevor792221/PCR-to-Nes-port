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
    rec = record(model, [level] * 14)
    rec[15:18] = [0x28, 0x10, 0x21]
    for i, b in enumerate(rec):
        s.nes[SV_CARS + slot * 48 + i] = b


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

    # --- secret boss ----------------------------------------------------------
    def race_select_count(self, s, region=None):
        s.garage_goto(G_RACE)
        s.press(A)
        s.step(30)
        if region is not None:
            s.list_goto('ui_sel', region)
        s.press(A)                  # the map: race in the region shown
        s.step(30)
        return s.mem('ui_count')

    def test_secret_boss_hidden_without_zenith(self):
        s = new_game()
        self.assertEqual(self.race_select_count(s), 8)

    def test_secret_boss_only_in_tokyo(self):
        s = new_game()
        give_car(s, 0, 12, 4)
        s.nes[0x600B] = 14
        for region, rows in ((2, 8), (5, 8), (6, 9)):
            self.assertEqual(self.race_select_count(s, region), rows, 'region %d' % region)
            s.press(B)                               # race select -> map
            s.step(40)
            s.press(B)                               # map -> garage
            s.step(60)

    def test_secret_boss_race_and_reward(self):
        s = new_game()
        give_car(s, 0, 12, 4)
        s.nes[0x600B] = 14                           # level for Tokyo, the boss's home
        self.assertEqual(self.race_select_count(s, 6), 9)
        s.list_goto('rs_sel', 8)
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
        self.assertEqual(s.mem('ui_count'), 11, 'back in the garage')

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
        self.assertEqual(s.wram(SV_CARS + 48), 12, 'bought the Zenith')
        self.assertEqual(s.wram(SV_CASH, 3), 100000)

    def test_cruise_mode(self):
        s = new_game()
        s.garage_goto(G_RACE)
        s.press(A)
        s.step(30)
        s.press(A)                  # the map: race in the region shown
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
        s.press(A)                  # the map: race in the region shown
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

    def test_taxis_only_cruise_and_always_yellow(self):
        for kind, want_taxi in ((3, False), (5, True)):           # street race, cruise
            s = new_game()
            s.garage_goto(G_RACE)
            s.press(A)
            s.step(30)
            s.press(A)
            s.step(30)
            s.list_goto('rs_sel', kind)
            s.press(A)
            s.step(40)
            taxis = pals = 0
            for f in range(6000 if want_taxi else 2500):     # 1 in 5 vehicles is a taxi
                b = A
                if s.mem('ph_gear') == 0:
                    b |= RIGHT if f % 4 < 2 else 0
                elif rpm(s) >= redline(s) - 300 and s.mem('ph_shift_t') == 0 and f % 4 < 2:
                    b |= RIGHT
                s.step(1, b)
                for i in range(6):
                    if s.mem('tr_on', i) and s.mem('tr_type', i) == 0:
                        taxis += 1
                        pals |= 1 << s.mem('tr_pal', i)
                if s.mem('game_mode') != 2:
                    break
            if want_taxi:
                self.assertGreater(taxis, 0, 'taxis when cruising')
                self.assertEqual(pals, 1 << 2, 'taxis use the yellow palette')
            else:
                self.assertEqual(taxis, 0, 'no taxis in street races')

    def test_cruise_without_traffic(self):
        s = new_game()
        s.garage_goto(G_RACE)
        s.press(A)
        s.step(30)
        s.press(A)                  # the map: race in the region shown
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
        s.press(A)                  # the map: race in the region shown
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
        s.press(A)                  # the map: race in the region shown
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
        s.step(80)
        self.assertEqual(s.mem('ui_count'), 8, 'the engine tune hub')
        s.press(A)                                   # GEAR RATIOS
        s.step(60)
        self.assertEqual(s.mem('ui_count'), 10, 'final, 7 gears, reset, back')
        rec = SV_CARS
        g1 = s.wram(rec + 20, 2)
        s.list_goto('ui_sel', 1)
        s.press(RIGHT)
        s.step(5)
        self.assertNotEqual(s.wram(rec + 20, 2), g1)
        s.list_goto('ui_sel', 8)                     # RESET TO STOCK
        s.press(A)
        s.step(10)
        self.assertEqual(s.wram(rec + 20, 2), g1)

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
        s.press(A)                  # the map: race in the region shown
        s.step(30)
        s.press(A)                                   # LADDER BOSS
        s.step(45)
        self.assertEqual(s.mem('bi_boss'), 0)
        self.assertEqual(s.mem('game_mode'), 1, 'intro, not racing yet')
        s.press(B)                                   # back to race select
        s.step(40)
        self.assertEqual(s.mem('ui_count'), 8)
        self.assertEqual(s.mem('game_mode'), 1)
        s.press(A)
        s.step(45)
        s.press(A)                                   # race
        s.step(60)
        self.assertEqual(s.mem('game_mode'), 2)
        self.assertEqual(s.mem('race_kind'), 0)

    # --- two players ------------------------------------------------------------
    def drive_two(self, s, frames=3000):
        def rpm_c(c):
            return s.mem('ph_rpm_l', c) | s.mem('ph_rpm_h', c) << 8

        def red_c(c):
            return s.mem('ph_redl_l', c) | s.mem('ph_redl_h', c) << 8
        for f in range(frames):
            bs = []
            for c in (0, 1):
                b = A
                if s.mem('ph_gear', c) == 0:
                    if s.mem('rc_green') and f % 4 < 2:
                        b |= RIGHT
                elif (rpm_c(c) >= red_c(c) - 300 and s.mem('ph_shift_t', c) == 0
                      and f % 4 < 2):
                    b |= RIGHT
                bs.append(b)
            s.step(1, bs[0] | bs[1] << 8)
            if s.mem('game_mode') == 3:
                break

    def start_two(self, s, p2_next=0):
        s.garage_goto(G_RACE)
        s.press(A)
        s.step(30)
        s.press(A)                  # the map: race in the region shown
        s.step(30)
        s.list_goto('rs_sel', 6)
        for _ in range(p2_next):
            s.press(RIGHT)
            s.step(10)
        s.press(A)
        s.step(60)

    def test_two_player_race(self):
        s = new_game()
        give_car(s, 1, 11, 4)                        # player 2 takes the Nova Hyper
        self.start_two(s, p2_next=1)
        self.assertEqual(s.mem('race_kind'), 6)
        self.assertEqual(s.mem('opp_rec'), 11)
        self.drive_two(s)
        s.step(30)
        self.assertEqual(s.mem('game_mode'), 3)
        self.assertEqual(s.mem('lag'), 0)
        flags = s.mem('res_flags')
        self.assertFalse(flags & 1, 'player 2 (hypercar) wins')
        self.assertTrue(flags & 4, 'player 2 has a time')
        self.assertLess(s.mem16('res_opp_et'), s.mem16('res_et'))
        self.assertEqual(s.wram(SV_CASH, 3), 3000, 'no money in 2-player races')
        self.assertEqual(s.wram(SV_RACES, 2), 0, 'not counted in the stats')

    def test_perfect_shift_mark(self):
        from test_game import start_race
        s = new_game()
        start_race(s, 4)
        s.step(10)
        # the mark sits where the tach shows redline - 450 rpm (bar at x 32)
        red = redline(s)
        k = s.mem16('tach_k')
        self.assertEqual(s.mem('shift_x'), 32 + ((red - 450) * k >> 16))
        tiles = [s.nes[0x200 + i * 4 + 1] for i in range(64)]
        self.assertIn(0x0D, tiles, 'mark sprite on screen')

    def test_two_player_foul_start(self):
        s = new_game()
        self.start_two(s)
        s.step(20)
        s.step(2, RIGHT << 8)                        # player 2 launches on amber
        s.step(200)
        self.assertEqual(s.mem('game_mode'), 3)
        self.assertEqual(s.mem('res_flags') & 0x09, 0x09, 'P2 foul: player 1 wins')

    def test_music_after_boss_intro_and_race(self):
        def playing(s):
            return any(s.mem('mus_act', i) for i in range(4))
        s = new_game()
        s.garage_goto(G_RACE)
        s.press(A)
        s.step(30)
        s.press(A)                  # the map: race in the region shown
        s.step(30)
        s.press(A)                                   # boss intro: boss theme
        s.step(60)
        self.assertEqual(s.mem('mus_song'), 3)
        s.press(B)                                   # back: garage theme
        s.step(60)
        self.assertEqual(s.mem('mus_song'), 0)
        self.assertTrue(playing(s))
        s.press(A)
        s.step(60)
        s.press(A)                                   # race the boss
        s.step(5)
        drive_race(s, launch=6600, shift_margin=200)
        s.step(60)
        s.press(A)                                   # results -> garage
        s.step(120)
        self.assertEqual(s.mem('game_mode'), 1)
        self.assertIn(s.mem('mus_song'), (0, 4, 5), 'a garage theme again')
        self.assertTrue(playing(s), 'not silent after the jingle')

    def test_garage_day_and_night_after_races(self):
        from test_game import start_race
        s = new_game()
        seen = set()
        for _ in range(8):
            start_race(s, 4)
            drive_race(s, launch=4500, shift_margin=300)
            s.step(60)
            s.press(A)
            s.step(100)
            night, song = s.mem('garage_night'), s.mem('mus_song')
            if night:
                self.assertEqual(song, 5, 'night garage plays After Hours')
            else:
                self.assertIn(song, (0, 4), 'day garage plays a day theme')
            seen.add(night)
        self.assertEqual(seen, {0, 1}, 'both day and night came up')

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
