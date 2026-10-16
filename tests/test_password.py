"""The two passwords that replace the battery save."""
import os
import random
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'tools'))
import password as pw          # noqa: E402
from harness import *          # noqa: E402,F401,F403
from test_game import new_game, SV_CASH, SV_CARS, G_OPTIONS   # noqa: E402
from test_features import give_car, set_cash                 # noqa: E402

SV_GEMS, SV_XP, SV_LEVEL, SV_LADDER, SV_CURCAR = 0x6007, 0x6009, 0x600B, 0x600C, 0x600D
SV_OPTIONS, SV_SECRET = 0x600E, 0x6018


def game_state(s):
    cars, cur = [], 0
    for slot in range(8):
        b = SV_CARS + slot * 32
        if s.wram(b) == 0xFF:
            continue
        if slot == s.wram(SV_CURCAR):
            cur = len(cars)
        cars.append((s.wram(b), [s.wram(b + 1 + i) for i in range(12)], s.wram(b + 13)))
    player = dict(cash=s.wram(SV_CASH, 3), gems=s.wram(SV_GEMS, 2), level=s.wram(SV_LEVEL),
                  xp=s.wram(SV_XP, 2), ladder=s.wram(SV_LADDER), secret=s.wram(SV_SECRET),
                  options=s.wram(SV_OPTIONS))
    return player, cars, cur


def type_password(s, text):
    sel = 0
    for ch in text:
        k = pw.ALPHABET.index(ch)
        while sel % 8 != k % 8:
            s.press(RIGHT)
            sel = sel // 8 * 8 + (sel + 1) % 8
        while sel // 8 != k // 8:
            s.press(DOWN)
            sel = (sel + 8) % 32
        s.press(A)
    s.press(START)
    s.step(40)


def to_password_screen():
    s = Sim(boot=120)
    s.list_goto('ui_sel', 2)
    s.press(A)
    s.step(40)
    return s


class Passwords(unittest.TestCase):
    def test_reference_round_trip(self):
        rnd = random.Random(7)
        for _ in range(300):
            st = dict(cash=rnd.randint(0, 9999999), gems=rnd.randint(0, 4095),
                      level=rnd.randint(1, 99), xp=rnd.randint(0, 4095),
                      ladder=rnd.randint(0, 11), secret=rnd.randint(0, 1),
                      options=rnd.randint(0, 7))
            p = pw.encode_player(**st)
            self.assertEqual(len(p), 15)
            self.assertEqual(pw.decode_player(p), st)
            n = rnd.randint(1, 8)
            cars = [(rnd.randint(0, 12), [rnd.randint(0, 4) for _ in range(12)],
                     rnd.choice(pw.PAINT_LIST)) for _ in range(n)]
            cur = rnd.randrange(n)
            g = pw.encode_garage(cars, cur)
            self.assertEqual(len(g), pw.garage_len(n))
            self.assertEqual(pw.decode_garage(g), dict(cars=cars, cur=cur))
            # a single wrong letter is caught (checksum / range checks)
            i = rnd.randrange(len(p))
            bad = p[:i] + pw.ALPHABET[(pw.ALPHABET.index(p[i]) + 1) % 32] + p[i + 1:]
            self.assertIsNone(pw.decode_player(bad))

    def test_restore_on_a_fresh_console(self):
        s = new_game()
        set_cash(s, 1234567)
        s.nes[SV_GEMS], s.nes[SV_GEMS + 1] = 300 & 0xFF, 300 >> 8
        s.nes[SV_LEVEL], s.nes[SV_XP], s.nes[SV_LADDER], s.nes[SV_SECRET] = 17, 50, 6, 1
        s.nes[SV_OPTIONS] = 5
        give_car(s, 1, 11, 3)
        give_car(s, 4, 12, 4)
        s.nes[SV_CARS + 4 * 32 + 2] = 2
        s.nes[SV_CURCAR] = 4
        player, cars, cur = game_state(s)
        # OPTIONS > PASSWORD shows the passwords; the garage one is the last
        # one built and must match the reference encoder
        s.garage_goto(G_OPTIONS)
        s.press(A)
        s.step(30)
        s.list_goto('ui_sel', 3)
        s.press(A)
        s.step(40)
        g = pw.encode_garage(cars, cur)
        rom = ''.join(pw.ALPHABET[s.nes[0x6840 + i]] for i in range(s.mem('pw_len')))
        self.assertEqual(rom, g)
        p = pw.encode_player(**player)
        # a new console (no battery: nothing kept) takes both passwords
        t = to_password_screen()
        type_password(t, p)
        type_password(t, g)
        t.step(60)
        self.assertEqual(t.mem('game_mode'), 1, 'in the garage')
        self.assertEqual(game_state(t), (player, cars, cur))

    def test_wrong_password_is_refused(self):
        t = to_password_screen()
        type_password(t, 'ABCDEFGHJKLMNPQ')
        self.assertEqual(t.mem('pw_kind'), 0, 'still on password 1')
        self.assertEqual(t.mem('game_mode'), 0)
        t.press(SELECT)
        t.step(40)
        self.assertEqual(t.mem('game_mode'), 0, 'back on the title')
        self.assertEqual(t.mem('ui_count'), 3)

    def test_new_game_passwords(self):
        p = pw.encode_player(3000, 5, 1, 0, 0, 0, 0)
        g = pw.encode_garage([(0, [0] * 12, 0x27)], 0)
        t = to_password_screen()
        type_password(t, p)
        type_password(t, g)
        t.step(60)
        self.assertEqual(t.mem('game_mode'), 1)
        self.assertEqual(t.wram(SV_CASH, 3), 3000)
        self.assertEqual(t.wram(SV_CARS), 0)
        self.assertEqual(t.wram(SV_CARS + 32), 0xFF)


if __name__ == '__main__':
    unittest.main()
