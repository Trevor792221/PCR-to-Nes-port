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
SV_WINS, SV_LOSSES, SV_CRATES, SV_STREET = 0x600F, 0x6011, 0x6013, 0x6017
SV_RACES, SV_PBEST, SV_PBCAR, SV_TOPSPD = 0x6019, 0x601B, 0x601D, 0x601E


def game_state(s):
    cars, cur = [], 0
    for slot in range(8):
        b = SV_CARS + slot * 48
        if s.wram(b) == 0xFF:
            continue
        if slot == s.wram(SV_CURCAR):
            cur = len(cars)
        cars.append((s.wram(b), [s.wram(b + 1 + i) for i in range(14)], s.wram(b + 15)))
    player = dict(cash=s.wram(SV_CASH, 3), gems=s.wram(SV_GEMS, 2), level=s.wram(SV_LEVEL),
                  xp=s.wram(SV_XP, 2), ladder=s.wram(SV_LADDER), secret=s.wram(SV_SECRET),
                  options=s.wram(SV_OPTIONS))
    top = s.wram(SV_TOPSPD, 2)
    player['stats'] = dict(races=s.wram(SV_RACES, 2), wins=s.wram(SV_WINS, 2),
                           losses=s.wram(SV_LOSSES, 2), crates=s.wram(SV_CRATES, 2),
                           street=s.wram(SV_STREET), pbest=s.wram(SV_PBEST, 2),
                           pbcar=s.wram(SV_PBCAR), topmph=top & 0x3FF, topcar=top >> 12)
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
            st['stats'] = {k: rnd.randint(0, (1 << n) - 1) for k, n in pw.STATS}
            st['stats']['pbcar'], st['stats']['topcar'] = rnd.randint(0, 12), rnd.randint(0, 12)
            p = pw.encode_player(**st)
            self.assertEqual(len(p), 32)
            self.assertEqual(pw.decode_player(p), st)
            n = rnd.randint(1, 8)
            cars = [(rnd.randint(0, 12), [rnd.randint(0, 4) for _ in range(14)],
                     rnd.choice(pw.PAINT_LIST)) for _ in range(n)]
            cur = rnd.randrange(n)
            g = pw.encode_garage(cars, cur)
            self.assertEqual(len(g), pw.garage_len(n))
            self.assertEqual(pw.decode_garage(g), dict(cars=cars, cur=cur))
            # a single wrong letter is caught (checksum / range checks)
            i = rnd.randrange(len(p))
            bad = p[:i] + pw.ALPHABET[(pw.ALPHABET.index(p[i]) + rnd.randint(1, 31)) % 32] + p[i + 1:]
            self.assertIsNone(pw.decode_player(bad), 'typo %s -> %s' % (p, bad))
            i = rnd.randrange(len(g))
            bad = g[:i] + pw.ALPHABET[(pw.ALPHABET.index(g[i]) + rnd.randint(1, 31)) % 32] + g[i + 1:]
            self.assertIsNone(pw.decode_garage(bad), 'typo %s -> %s' % (g, bad))

    def test_restore_on_a_fresh_console(self):
        s = new_game()
        set_cash(s, 1234567)
        s.nes[SV_GEMS], s.nes[SV_GEMS + 1] = 300 & 0xFF, 300 >> 8
        s.nes[SV_LEVEL], s.nes[SV_XP], s.nes[SV_LADDER], s.nes[SV_SECRET] = 17, 50, 6, 1
        s.nes[SV_OPTIONS] = 5
        for addr, v in ((SV_RACES, 321), (SV_WINS, 200), (SV_LOSSES, 99), (SV_CRATES, 45),
                        (SV_PBEST, 10234), (SV_TOPSPD, 287 | 11 << 12)):
            s.nes[addr], s.nes[addr + 1] = v & 0xFF, v >> 8
        s.nes[SV_STREET], s.nes[SV_PBCAR] = 17, 11
        give_car(s, 1, 11, 3)
        give_car(s, 4, 12, 4)
        s.nes[SV_CARS + 4 * 48 + 2] = 2
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

    def test_v1_passwords_from_v3_0_still_work(self):
        p = pw.encode_player(250000, 40, 9, 10, 3, 0, 4)      # 15 letters (v3.0)
        g = pw.encode_garage([(5, [1] * 12, 0x16)], 0, version=1)
        t = to_password_screen()
        type_password(t, p)
        type_password(t, g)
        t.step(60)
        self.assertEqual(t.mem('game_mode'), 1)
        player, cars, cur = game_state(t)
        self.assertEqual(player['cash'], 250000)
        self.assertEqual(player['ladder'], 3)
        self.assertEqual(set(player['stats'].values()), {0}, 'fresh stats')

    def test_v2_garage_passwords_from_v4_1_still_work(self):
        p = pw.encode_player(250000, 40, 9, 10, 3, 0, 4, dict.fromkeys(dict(pw.STATS), 0))
        g = pw.encode_garage([(8, [2] * 12, 0x16), (2, [4] * 12, 0x27)], 1, version=2)
        self.assertEqual(len(g), 19)
        self.assertEqual(pw.decode_garage(g)['cars'][0][1], [2] * 12 + [0, 0])
        t = to_password_screen()
        type_password(t, p)
        type_password(t, g)
        t.step(60)
        self.assertEqual(t.mem('game_mode'), 1)
        player, cars, cur = game_state(t)
        self.assertEqual(cars, [(8, [2] * 12 + [0, 0], 0x16), (2, [4] * 12 + [0, 0], 0x27)])
        self.assertEqual(cur, 1)

    def test_new_game_passwords(self):
        p = pw.encode_player(3000, 5, 1, 0, 0, 0, 0, dict.fromkeys(dict(pw.STATS), 0))
        g = pw.encode_garage([(0, [0] * 14, 0x27)], 0)
        t = to_password_screen()
        type_password(t, p)
        type_password(t, g)
        t.step(60)
        self.assertEqual(t.mem('game_mode'), 1)
        self.assertEqual(t.wram(SV_CASH, 3), 3000)
        self.assertEqual(t.wram(SV_CARS), 0)
        self.assertEqual(t.wram(SV_CARS + 48), 0xFF)


if __name__ == '__main__':
    unittest.main()
