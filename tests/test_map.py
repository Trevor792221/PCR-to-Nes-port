"""The world map: regions open with the player's level, rivals and prizes
grow across Japan, and bosses wait for the level of their home region."""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'tools'))
import password as pw          # noqa: E402
from harness import *          # noqa: E402,F401,F403
from test_game import new_game, G_RACE                       # noqa: E402
from test_password import to_password_screen, type_password  # noqa: E402

SV_XP, SV_LEVEL, SV_LADDER = 0x6009, 0x600B, 0x600C
REGION_LV = [1, 7, 12, 17, 21, 23, 31]
FUKUOKA, HIROSHIMA, OSAKA, NAGOYA, GUNMA, SAPPORO, TOKYO = range(7)


def open_map(s, level):
    s.nes[SV_LEVEL] = level
    s.garage_goto(G_RACE)
    s.press(A)
    s.step(40)
    assert s.mem('ui_count') == 7, 'on the map'


def pick_region(s, region):
    s.list_goto('ui_sel', region)
    s.press(A)
    s.step(40)


class Map(unittest.TestCase):
    def test_regions_open_with_level(self):
        s = new_game()
        open_map(s, 1)
        self.assertEqual(s.mem('map_max'), FUKUOKA)
        pick_region(s, HIROSHIMA)                    # needs level 7
        self.assertEqual(s.mem('ui_count'), 7, 'still on the map')
        self.assertEqual(s.mem('map_region'), FUKUOKA)
        self.assertEqual(s.mem('lag'), 0)
        s.press(B)
        s.step(40)
        for lv in range(1, 35):
            open_map(s, lv)
            want = max(i for i, need in enumerate(REGION_LV) if lv >= need)
            self.assertEqual(s.mem('map_max'), want, 'level %d' % lv)
            s.press(B)
            s.step(40)
        open_map(s, 21)
        self.assertEqual(s.mem('mus_song'), 6, 'the map plays Road to Tokyo')
        self.assertTrue(any(s.mem('mus_act', i) for i in range(4)))
        pick_region(s, GUNMA)
        self.assertEqual(s.mem('map_region'), GUNMA)
        self.assertEqual(s.mem('ui_count'), 8, 'race select')
        self.assertIn(s.mem('mus_song'), (0, 4, 5), 'garage theme back in race select')
        s.press(B)                                   # back to the map
        s.step(40)
        self.assertEqual(s.mem('ui_count'), 7)
        self.assertEqual(s.mem('ui_sel'), GUNMA, 'cursor on the region in use')

    def street_rival(self, region, level):
        s = new_game()
        open_map(s, level)
        pick_region(s, region)
        s.list_goto('rs_sel', 3)
        s.press(A)
        s.step(5)
        self.assertEqual(s.mem('race_kind'), 2)
        return s.mem('opp_skill'), [s.mem('opp_rec', 1 + i) for i in range(14)]

    def test_rivals_get_tougher(self):
        skill0, parts0 = self.street_rival(FUKUOKA, 1)
        skill6, parts6 = self.street_rival(TOKYO, 31)
        self.assertEqual(skill0, 140)
        self.assertEqual(skill6, 140 + 6 * 8)
        self.assertEqual(set(parts0), {0}, 'stock car: stock rivals at home')
        self.assertEqual(set(parts6), {3}, 'tuned rivals in Tokyo')

    def test_bets_scale_with_the_region(self):
        for region, level, bet in ((FUKUOKA, 1, 300), (OSAKA, 12, 600), (TOKYO, 31, 1200)):
            s = new_game()
            open_map(s, level)
            pick_region(s, region)
            s.list_goto('rs_sel', 1)                 # quick race, easy
            s.press(A)
            s.step(5)
            self.assertEqual(s.mem('race_kind'), 1)
            self.assertEqual(s.mem('race_bet') | s.mem('race_bet', 1) << 8, bet)

    def test_bosses_need_their_home_region(self):
        s = new_game()
        s.nes[SV_LADDER] = 4                         # boss 5 lives in Osaka (level 12)
        open_map(s, 11)
        pick_region(s, FUKUOKA)
        s.list_goto('rs_sel', 0)
        s.nes[s.sym['bi_boss']] = 0xFF
        s.press(A)
        s.step(40)
        self.assertEqual(s.mem('ui_count'), 8, 'locked: still on race select')
        self.assertEqual(s.mem('game_mode'), 1)
        s.nes[SV_LEVEL] = 12
        s.press(A)
        s.step(45)
        self.assertNotEqual(s.mem('bi_boss'), 4, 'level 12, but in Fukuoka: still locked')
        s.press(B)                                   # to the map, then Osaka
        s.step(40)
        pick_region(s, OSAKA)
        s.list_goto('rs_sel', 0)
        s.press(A)
        s.step(45)
        self.assertEqual(s.mem('bi_boss'), 4, 'in Osaka: the intro opens')

    def test_every_boss_only_races_at_home(self):
        home = [FUKUOKA, FUKUOKA, HIROSHIMA, HIROSHIMA, OSAKA, OSAKA, NAGOYA, GUNMA,
                SAPPORO, TOKYO, TOKYO]
        for boss, region in enumerate(home):
            for here in (region, (region + 3) % 7):
                s = new_game()
                s.nes[SV_LADDER] = boss
                open_map(s, 40)                      # every region open
                pick_region(s, here)
                s.list_goto('rs_sel', 0)
                s.nes[s.sym['bi_boss']] = 0xFF
                s.press(A)
                s.step(45)
                opened = s.mem('bi_boss') == boss    # the boss intro opened
                self.assertEqual(opened, here == region,
                                 'boss %d in region %d' % (boss + 1, here))

    def test_new_region_on_level_up(self):
        s = new_game()
        s.nes[SV_XP], s.nes[SV_XP + 1] = 339 & 0xFF, 339 >> 8   # 1 short of level 7
        open_map(s, 6)
        pick_region(s, FUKUOKA)
        s.list_goto('rs_sel', 4)                     # test run: 5 XP
        s.press(A)
        s.step(40)
        drive_race(s)
        s.step(60)
        self.assertEqual(s.wram(SV_LEVEL), 7)
        self.assertEqual(s.mem('rw_newreg'), HIROSHIMA + 1)

    def test_password_puts_you_at_your_furthest_region(self):
        st = dict(cash=50000, gems=10, level=23, xp=0, ladder=8, secret=0, options=0,
                  stats=dict.fromkeys(dict(pw.STATS), 0))
        t = to_password_screen()
        type_password(t, pw.encode_player(**st))
        type_password(t, pw.encode_garage([(3, [2] * 14, 0x16)], 0))
        type_password(t, '')
        t.step(60)
        self.assertEqual(t.mem('game_mode'), 1)
        self.assertEqual(t.mem('map_region'), SAPPORO)


if __name__ == '__main__':
    unittest.main()
