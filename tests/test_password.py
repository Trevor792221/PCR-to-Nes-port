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
SV_CARS_ = SV_CARS

SV_GEMS, SV_XP, SV_LEVEL, SV_LADDER, SV_CURCAR = 0x6007, 0x6009, 0x600B, 0x600C, 0x600D
SV_OPTIONS, SV_SECRET = 0x600E, 0x6018
PW_TEXT = 0x6900
SV_OWNED = 0x61B0               # 3 bytes a slot: swaps paid for, not fitted
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
    swap = lambda slot: s.wram(SV_CARS + slot * 48 + 47)   # engine | drive << 5
    slots = [k for k in range(8) if s.wram(SV_CARS + k * 48) != 0xFF]
    owned = lambda slot: s.wram(SV_OWNED + 3 * slot, 3)
    fields = lambda v: (pw.BOSS_CAR, 0) if v & 0x80 else (v & 0x1F, v >> 5)   # boss car: 31
    if any(swap(slot) or owned(slot) for slot in slots):     # swapped: version 4
        cars = [c + fields(swap(slot)) for c, slot in zip(cars, slots)]
    if any(owned(slot) for slot in slots):                  # paid-for swaps: version 5
        cars = [c + (owned(slot),) for c, slot in zip(cars, slots)]
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


def signed(v):
    return v - 256 if v >= 128 else v


def garage_tunes(s):
    """(model, 13 tune bytes, final, gears) per car, in garage order"""
    import gamedata as gd
    out = []
    for slot in range(8):
        b = SV_CARS + slot * 48
        m = s.wram(b)
        if m == 0xFF:
            continue
        out.append((m, [signed(s.wram(b + 34 + i)) for i in range(13)], s.wram(b + 18, 2),
                    [s.wram(b + 20 + 2 * i, 2) for i in range(gd.CARS[m][6])]))
    return out


def random_tune(rnd, model):
    import gamedata as gd
    tune = ([rnd.randint(-5, 5) for _ in range(8)] + [rnd.randint(-5, 5), rnd.randint(-14, 8),
            rnd.randint(-13, 9), rnd.choice([0, 2 * rnd.randint(10, 45)]),
            rnd.choice([0, 0, rnd.randint(-4, 4)])])
    stock = pw._stock_ratios(model)
    rat = []
    for i, st in enumerate(stock):
        lo, hi = (0x200, 0x5FF) if i == 0 else (0x80, 0x4FF)
        rat.append(rnd.choice([st, st + 3 * rnd.randint((lo - st + 2) // 3, (hi - st) // 3)]))
    return tune, rat[0], rat[1:]


def tune_cars(s, rnd, slots, full=False):
    for slot in slots:
        b = SV_CARS + slot * 48
        tune, final, gears = random_tune(rnd, s.wram(b))
        if full:
            tune = [rnd.choice([-5, 5]) for _ in range(8)] + [5, -14, 9, 90, -4]
            st = pw._stock_ratios(s.wram(b))         # as far as the limits go
            final = st[0] + 3 * ((0x5FF - st[0]) // 3)
            gears = [g + 3 * ((0x4FF - g) // 3) if i % 2 else g - 3 * ((g - 0x80) // 3)
                     for i, g in enumerate(st[1:])]
        for i, v in enumerate(tune):
            s.nes[b + 34 + i] = v & 0xFF
        s.nes[b + 18], s.nes[b + 19] = final & 0xFF, final >> 8
        for i, g in enumerate(gears):
            s.nes[b + 20 + 2 * i], s.nes[b + 21 + 2 * i] = g & 0xFF, g >> 8


def show_passwords(s):
    s.garage_goto(G_OPTIONS)
    s.press(A)
    s.step(30)
    s.list_goto('ui_sel', 3)
    s.press(A)
    s.step(40)


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
            ver = 3
            if rnd.random() < .5:                    # swaps: version 4
                ver = 4
                cars = [c + ((0, 0) if c[0] == 12 or rnd.random() < .3 else
                             (rnd.choice([0] + [e for e in range(1, 18) if e != 13]),
                              rnd.randint(0, 3))) for c in cars]
                if not any(any(c[3:]) for c in cars):
                    ver = 3
                    cars = [c[:3] for c in cars]
            if ver == 4 and rnd.random() < .5:       # swaps paid for: version 5
                ver = 5
                own = lambda: (rnd.getrandbits(17) & ~(1 << 12)) | rnd.getrandbits(3) << pw.OWN_DRV
                cars = [c + (0 if c[0] == 12 or rnd.random() < .4 else own(),) for c in cars]
                if not any(c[5] for c in cars):
                    ver = 4
                    cars = [c[:5] for c in cars]
            cur = rnd.randrange(n)
            g = pw.encode_garage(cars, cur)
            self.assertEqual(len(g), pw.garage_len(n, ver, sum(1 for c in cars if c[5:] and c[5])))
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
        rom = ''.join(pw.ALPHABET[s.nes[PW_TEXT + i]] for i in range(s.mem('pw_len')))
        self.assertEqual(rom, g)
        p = pw.encode_player(**player)
        # a new console (no battery: nothing kept) takes both passwords
        t = to_password_screen()
        type_password(t, p)
        type_password(t, g)
        type_password(t, '')                         # no tunes
        t.step(60)
        self.assertEqual(t.mem('game_mode'), 1, 'in the garage')
        self.assertEqual(game_state(t), (player, cars, cur))

    def test_swaps_survive_a_fresh_console(self):
        s = new_game()
        for slot, model in enumerate([4, 1, 12, 9, 0, 5, 7, 2]):   # 8 cars: 85 letters
            give_car(s, slot, model, slot % 5)
        for slot, engine, drive in ((0, 14, 3), (1, 17, 0), (3, 0, 1), (7, 5, 2)):
            s.nes[SV_CARS + slot * 48 + 47] = engine | drive << 5
        s.nes[SV_CURCAR] = 3
        player, cars, cur = game_state(s)
        s.garage_goto(G_OPTIONS)
        s.press(A)
        s.step(30)
        s.list_goto('ui_sel', 3)
        s.press(A)
        s.step(40)
        g = pw.encode_garage(cars, cur)
        self.assertEqual(len(g), 85)
        rom = ''.join(pw.ALPHABET[s.nes[PW_TEXT + i]] for i in range(s.mem('pw_len')))
        self.assertEqual(rom, g)
        self.assertEqual(pw.decode_garage(g)['cars'][0][3:], (14, 3))
        t = to_password_screen()
        type_password(t, pw.encode_player(**player))
        type_password(t, g)
        type_password(t, '')
        t.step(60)
        self.assertEqual(t.mem('game_mode'), 1, 'in the garage')
        self.assertEqual(game_state(t), (player, cars, cur))
        # the crate car can't come back swapped
        bad = pw.encode_garage([(12, [0] * 14, 0x16, 2, 0)], 0)
        self.assertIsNone(pw.decode_garage(bad))
        t = to_password_screen()
        type_password(t, pw.encode_player(**player))
        type_password(t, bad)
        self.assertEqual(t.mem('pw_kind'), 1, 'refused: still on password 2')

    def test_wrong_password_is_refused(self):
        t = to_password_screen()
        type_password(t, 'ABCDEFGHJKLMNPQ')
        self.assertEqual(t.mem('pw_kind'), 0, 'still on password 1')
        self.assertEqual(t.mem('game_mode'), 0)
        t.press(SELECT)
        t.step(40)
        self.assertEqual(t.mem('game_mode'), 0, 'back on the title')
        self.assertEqual(t.mem('ui_count'), 4, 'the title menu')

    def test_v1_passwords_from_v3_0_still_work(self):
        p = pw.encode_player(250000, 40, 9, 10, 3, 0, 4)      # 15 letters (v3.0)
        g = pw.encode_garage([(5, [1] * 12, 0x16)], 0, version=1)
        t = to_password_screen()
        type_password(t, p)
        type_password(t, g)
        type_password(t, '')                         # no tunes
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
        type_password(t, '')                         # no tunes
        t.step(60)
        self.assertEqual(t.mem('game_mode'), 1)
        player, cars, cur = game_state(t)
        self.assertEqual(cars, [(8, [2] * 12 + [0, 0], 0x16), (2, [4] * 12 + [0, 0], 0x27)])
        self.assertEqual(cur, 1)

    def test_tune_reference_round_trip(self):
        rnd = random.Random(11)
        for _ in range(300):
            models = [rnd.randint(0, 12) for _ in range(rnd.randint(1, 8))]
            cars = []
            for m in models:
                tune, final, gears = random_tune(rnd, m)
                if rnd.random() < 0.3:
                    tune = [0] * 13
                elif rnd.random() < 0.3:
                    tune = tune[:12]                 # no nitrous: version 1
                cars.append((m, tune, final, gears))
            t = pw.encode_tune(cars)
            dec = pw.decode_tune(t, models)
            for (m, tune, final, gears), (dt, dr) in zip(cars, dec):
                self.assertEqual(dt or [0] * 13, tune + [0] * (13 - len(tune)))
                self.assertEqual(dr or pw._stock_ratios(m), [final] + gears)
            if t:
                v = 2 if any(c[1][12:13] != [0] and c[1][12:] for c in cars) else 1
                self.assertEqual(pw.Bits.from_text(t, pw.SEED_TUNE).get(2), v)
                i = rnd.randrange(len(t))
                bad = t[:i] + pw.ALPHABET[(pw.ALPHABET.index(t[i]) + rnd.randint(1, 31)) % 32] + t[i + 1:]
                self.assertIsNone(pw.decode_tune(bad, models), 'typo %s -> %s' % (t, bad))
        stock = [(2, [0] * 12, *(lambda r: (r[0], r[1:]))(pw._stock_ratios(2)))]
        self.assertEqual(pw.encode_tune(stock), '', 'nothing tuned: no password')

    def tune_round_trip(self, slots, models, full=False, owned=None):
        s = new_game()
        for slot, m in zip(slots, models):
            give_car(s, slot, m, 2)
        for slot, bits in (owned or {}).items():
            for i in range(3):
                s.nes[SV_OWNED + 3 * slot + i] = bits >> 8 * i & 0xFF
        s.nes[SV_CURCAR] = slots[-1]
        tune_cars(s, random.Random(len(slots)), slots[:-1] if not full else slots, full)
        player, cars, cur = game_state(s)
        tunes = garage_tunes(s)
        want = pw.encode_tune(tunes)
        show_passwords(s)
        g = ''.join(pw.ALPHABET[s.nes[PW_TEXT + i]] for i in range(s.mem('pw_len')))
        self.assertEqual(g, pw.encode_garage(cars, cur))
        s.press(A)                                   # page 2: the tune password
        s.step(40)
        rom = ''.join(pw.ALPHABET[s.nes[PW_TEXT + i]] for i in range(s.mem('pw_len')))
        self.assertEqual(rom, want)
        t = to_password_screen()
        type_password(t, pw.encode_player(**player))
        type_password(t, g)
        type_password(t, want)
        t.step(60)
        self.assertEqual(t.mem('game_mode'), 1, 'in the garage')
        self.assertEqual(garage_tunes(t), tunes)
        self.assertEqual(game_state(t), (player, cars, cur))
        self.assertEqual(t.mem('lag'), 0)
        self.garage = g
        return want

    def test_tunes_survive_a_fresh_console(self):
        t = self.tune_round_trip([0, 3, 5], [9, 2, 7])
        self.assertLess(len(t), 60)

    def test_eight_tuned_cars_scroll(self):
        t = self.tune_round_trip(list(range(8)), [11, 9, 8, 7, 10, 5, 2, 12], full=True)
        self.assertGreater(len(t), 160, 'long enough to scroll the entry')

    def test_paid_swaps_survive_a_fresh_console(self):
        # every car has paid-for swaps and a full tune: the longest passwords
        own = {k: (0x1EFFF & ~(1 << k)) | (5 << pw.OWN_DRV if k % 2 else 2 << pw.OWN_DRV)
               for k in range(8)}
        self.tune_round_trip(list(range(8)), [11, 9, 8, 7, 10, 5, 2, 0], full=True, owned=own)
        self.assertEqual(len(self.garage), 119)
        # the starter car and two more, one with one spare engine
        self.tune_round_trip([2, 6], [1, 4], owned={6: 1 << 14})
        self.assertEqual(len(self.garage), pw.garage_len(3, 5, spare=1))
        self.assertGreater(len(self.garage), pw.garage_len(3, 4))

    def test_paid_swaps_the_crate_car_cant_have(self):
        # the crate car paying for swaps, and anyone owning the crate car's engine
        for cars in ([(12, [0] * 14, 0x16, 0, 0, 1 << 3)],
                     [(4, [0] * 14, 0x16, 0, 0, 1 << 12)]):
            g = pw.encode_garage(cars, 0)
            self.assertIsNone(pw.decode_garage(g))
            t = to_password_screen()
            type_password(t, pw.encode_player(3000, 5, 1, 0, 0, 0, 0, dict.fromkeys(dict(pw.STATS), 0)))
            type_password(t, g)
            self.assertEqual(t.mem('pw_kind'), 1, 'refused: still on password 2')
        # version 4 cut short, or with a letter too many, is refused too
        g = pw.encode_garage([(4, [0] * 14, 0x16, 14, 1, 1 << 15)], 0)
        for wrong in (g[:-1], g + 'A'):
            self.assertIsNone(pw.decode_garage(wrong))
            t = to_password_screen()
            type_password(t, pw.encode_player(3000, 5, 1, 0, 0, 0, 0, dict.fromkeys(dict(pw.STATS), 0)))
            type_password(t, wrong)
            self.assertEqual(t.mem('pw_kind'), 1, 'refused: still on password 2')

    def test_wrong_tune_password_is_refused(self):
        s = new_game()
        give_car(s, 0, 9, 1)
        tune_cars(s, random.Random(3), [0])
        player, cars, cur = game_state(s)
        t_ok = pw.encode_tune(garage_tunes(s))
        other = pw.encode_tune([(9, [1] * 12, *(lambda r: (r[0], r[1:]))(pw._stock_ratios(9))),
                                (2, [1] * 12, *(lambda r: (r[0], r[1:]))(pw._stock_ratios(2)))])
        bad = t_ok[:-1] + pw.ALPHABET[(pw.ALPHABET.index(t_ok[-1]) + 1) % 32]
        for wrong in (bad, other):                   # a typo; another garage's
            t = to_password_screen()
            type_password(t, pw.encode_player(**player))
            type_password(t, pw.encode_garage(cars, cur))
            type_password(t, wrong)
            self.assertEqual(t.mem('pw_kind'), 2, 'still on password 3')
            self.assertEqual(t.mem('game_mode'), 0)

    def test_new_game_passwords(self):
        p = pw.encode_player(3000, 5, 1, 0, 0, 0, 0, dict.fromkeys(dict(pw.STATS), 0))
        g = pw.encode_garage([(0, [0] * 14, 0x27)], 0)
        t = to_password_screen()
        type_password(t, p)
        type_password(t, g)
        type_password(t, '')                         # no tunes
        t.step(60)
        self.assertEqual(t.mem('game_mode'), 1)
        self.assertEqual(t.wram(SV_CASH, 3), 3000)
        self.assertEqual(t.wram(SV_CARS), 0)
        self.assertEqual(t.wram(SV_CARS + 48), 0xFF)


if __name__ == '__main__':
    unittest.main()
