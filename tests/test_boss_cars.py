"""Boss cars: beating a boss for the first time wins their car, as raced
(model, parts, paint), locked: no tuning, parts or swaps.  It sells for half
the car's price (its parts came free); with a full garage it's sold at once."""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'tools'))
import gamedata as gd           # noqa: E402
import password as pw          # noqa: E402
from cpu import CPU             # noqa: E402
from harness import *           # noqa: E402,F401,F403
from test_game import new_game, start_race, SV_CASH, SV_CARS, G_PARTS, G_TUNE, G_PAINT, \
    G_MYCARS   # noqa: E402
from test_features import give_car                                  # noqa: E402
from test_password import game_state, show_passwords, to_password_screen, type_password, \
    PW_TEXT   # noqa: E402

G_SWAP = 10
G_N = 11                        # garage menu items
SV_CURCAR = 0x600D
CR_PAINT, CR_SWAP = 15, 47
BOSS_MODEL = [0, 1, 2, 4, 3, 5, 6, 7, 11, 9, 11, gd.CRATE_CAR]     # src/menus.s
BOSS_LEVEL = [0, 1, 1, 1, 2, 2, 3, 3, 3, 4, 4, 4]
BOSS_PAINT = [0x2A, 0x11, 0x30, 0x14, 0x12, 0x28, 0x07, 0x3C, 0x0F, 0x00, 0x25, 0x13]


def rec(s, slot, off=0, n=1):
    return s.wram(SV_CARS + slot * 48 + off, n)


def beat_first_boss(s):
    start_race(s, 0)
    drive_race(s, launch=6600, shift_margin=200)
    s.step(60)
    assert s.mem('res_flags') & 1, 'beat the boss'


class BossCars(unittest.TestCase):
    def test_beating_a_boss_wins_their_car(self):
        s = new_game()
        beat_first_boss(s)
        self.assertEqual(rec(s, 1), BOSS_MODEL[0])
        self.assertEqual([rec(s, 1, 1 + p) for p in range(14)], [BOSS_LEVEL[0]] * 14)
        self.assertEqual(rec(s, 1, CR_PAINT), BOSS_PAINT[0])
        self.assertEqual(rec(s, 1, CR_SWAP), 0x80, 'a boss car')
        self.assertEqual(s.mem('rw_bcar'), 1)
        self.assertEqual(rec(s, 2), 0xFF, 'just the one')
        self.assertEqual(rec(s, 0, CR_SWAP), 0, 'the starter car is yours to tune')

    def test_a_full_garage_sells_it_at_once(self):
        s = new_game()
        for slot in range(1, 8):
            give_car(s, slot, 1, 0)
        cash = s.wram(SV_CASH, 3)
        beat_first_boss(s)
        self.assertEqual(s.mem('rw_bfull'), 1)
        self.assertEqual(s.wram(SV_CASH, 3), cash + 800 + gd.CARS[BOSS_MODEL[0]][10] // 2,
                         'the prize and half the car')

    def test_no_parts_tune_or_swaps_on_a_boss_car(self):
        s = new_game()
        give_car(s, 1, 11, 4)
        s.nes[SV_CARS + 48 + CR_SWAP] = 0x80
        s.nes[SV_CURCAR] = 1
        s.garage_goto(G_PAINT)                       # (redraws the garage for car 1)
        s.press(A)
        s.step(40)
        self.assertNotEqual(s.mem('ui_count'), G_N, 'paint is fine')
        s.press(B)
        s.step(40)
        for item in (G_PARTS, G_TUNE, G_SWAP):
            s.garage_goto(item)
            s.press(A)
            s.step(40)
            self.assertEqual((s.mem('game_mode'), s.mem('ui_count')), (1, G_N), 'still in the garage')
        self.assertEqual([rec(s, 1, 1 + p) for p in range(14)], [4] * 14)

    def test_a_boss_car_sells_for_half_its_price(self):
        s = new_game()
        give_car(s, 1, 11, 4)                        # fully upgraded, but won
        s.nes[SV_CARS + 48 + CR_SWAP] = 0x80
        cash = s.wram(SV_CASH, 3)
        s.garage_goto(G_MYCARS)
        s.press(A)
        s.step(30)
        s.list_goto('mc_sel', 1)
        s.press(SELECT)                              # sell
        s.step(30)
        s.press(A)
        s.step(30)
        self.assertEqual(rec(s, 1), 0xFF, 'sold')
        self.assertEqual(s.wram(SV_CASH, 3) - cash, gd.CARS[11][10] // 2, 'no money for its parts')

    def test_crate_part_prizes_pass_a_boss_car_by(self):
        c = CPU(bank=3)
        c.mem[SV_CURCAR] = 0
        c.mem[SV_CARS:SV_CARS + 48] = bytes(48)
        c.mem[SV_CARS + CR_SWAP] = 0x80
        c.call('give_part_silent')
        self.assertTrue(c.mpu.p & 1, 'no part: the crate pays cash instead')
        self.assertEqual(bytes(c.mem[SV_CARS + 1:SV_CARS + 15]), bytes(14))

    def test_boss_cars_in_the_garage_password(self):
        s = new_game()
        give_car(s, 1, 11, 4)
        s.nes[SV_CARS + 48 + CR_SWAP] = 0x80
        give_car(s, 2, gd.CRATE_CAR, 4)              # Eclipse's Zenith
        s.nes[SV_CARS + 96 + CR_SWAP] = 0x80
        player, cars, cur = game_state(s)
        self.assertEqual(cars[1][3:], (pw.BOSS_CAR, 0))
        show_passwords(s)
        g = ''.join(pw.ALPHABET[s.nes[PW_TEXT + i]] for i in range(s.mem('pw_len')))
        self.assertEqual(g, pw.encode_garage(cars, cur))
        self.assertEqual(len(g), pw.garage_len(3, 4), 'version 4: no new format')
        t = to_password_screen()
        type_password(t, pw.encode_player(**player))
        type_password(t, g)
        type_password(t, '')
        t.step(60)
        self.assertEqual(t.mem('game_mode'), 1)
        self.assertEqual(game_state(t), (player, cars, cur))
        self.assertEqual(rec(t, 2, CR_SWAP), 0x80)
        # a "boss car" with a drivetrain swap is a typo
        bad = pw.encode_garage([(4, [0] * 14, 0x16, pw.BOSS_CAR, 1)], 0)
        self.assertIsNone(pw.decode_garage(bad))
        t = to_password_screen()
        type_password(t, pw.encode_player(**player))
        type_password(t, bad)
        self.assertEqual(t.mem('pw_kind'), 1, 'refused')


if __name__ == '__main__':
    unittest.main()
