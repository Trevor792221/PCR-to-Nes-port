"""Play the ROM in the cynes emulator: menus, races, saving."""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from harness import *          # noqa: F401,F403
sys.path.insert(0, os.path.join(HERE, '..', 'tools'))
import gamedata as gd          # noqa: E402

SV_CASH, SV_GEMS, SV_LEVEL, SV_LADDER = 0x6004, 0x6007, 0x600B, 0x600C
SV_CARS = 0x6020
SV_BESTS = 0x61A0
G_RACE, G_PARTS, G_MYCARS, G_TUNE, G_DEALER, G_PAINT, G_CRATES, G_DYNO, G_OPTIONS = range(9)


def new_game():
    s = Sim(boot=120)
    s.press(DOWN)
    s.press(A)                  # NEW GAME
    s.step(10)
    s.press(A)                  # confirm
    s.step(40)
    assert s.mem('game_mode') == 1
    return s


def start_race(s, item):
    s.garage_goto(G_RACE)
    s.press(A)
    s.step(30)
    s.press(A)                  # the map: race in the region shown
    s.step(30)
    s.list_goto('rs_sel', item)
    s.press(A)
    s.step(5)
    if item in (0, 8):                      # boss intro screen: A to race
        s.step(40)
        assert s.mem('bi_boss') < 12
        s.press(A)
        s.step(5)


class Game(unittest.TestCase):
    def test_boot_title(self):
        s = Sim(boot=120)
        self.assertEqual(s.mem('game_mode'), 0)
        self.assertGreater(s.mem16('frame'), 50)     # NMI running

    def test_splash_screen(self):
        s = Sim(boot=30, skip_splash=False)
        self.assertEqual(s.mem('game_mode'), 4, 'splash on boot')
        self.assertEqual(s.mem('cur_bank'), 4)
        s.step(400)                                  # times out to the title
        self.assertEqual(s.mem('game_mode'), 0)
        s = Sim(boot=60, skip_splash=False)
        s.press(START)                               # or skip it with START
        s.step(40)
        self.assertEqual(s.mem('game_mode'), 0)

    def test_new_game_state(self):
        s = new_game()
        self.assertEqual(s.wram(SV_CASH, 3), 3000)
        self.assertEqual(s.wram(SV_CARS), 0)         # starter car
        self.assertEqual(s.wram(SV_CARS + 48), 0xFF)  # rest empty

    def test_buy_part_and_save(self):
        s = new_game()
        s.garage_goto(G_PARTS)
        s.press(A)
        s.step(30)
        s.press(A)                                   # intake level 1
        s.step(10)
        cash = 3000 - gd.part_cost(gd.P_INTAKE, 0, 1)
        self.assertEqual(s.wram(SV_CARS + 1), 1)
        self.assertEqual(s.wram(SV_CASH, 3), cash)
        # soft reset keeps the work RAM: the game must still be valid
        s.nes.reset()
        s.step(120)
        s.press(A)                                   # CONTINUE
        s.step(40)
        self.assertEqual(s.wram(SV_CARS + 1), 1)
        self.assertEqual(s.wram(SV_CASH, 3), cash)

    def test_test_run(self):
        s = new_game()
        start_race(s, 4)
        frames = drive_race(s, launch=6600, shift_margin=200)
        self.assertEqual(s.mem('game_mode'), 3, 'results screen')
        et = s.mem16('res_et')
        self.assertTrue(16500 < et < 19000, et)       # stock mini: ~17.5 s
        self.assertLessEqual(s.mem('lag'), 1)
        s.step(30)
        self.assertNotEqual(s.wram(SV_BESTS, 2), 0, 'best time saved')

    def test_ladder_win(self):
        s = new_game()
        start_race(s, 0)
        drive_race(s, launch=6600, shift_margin=200)
        self.assertEqual(s.mem('game_mode'), 3)
        self.assertTrue(s.mem('res_flags') & 1, 'should beat the first boss')
        s.step(30)
        self.assertEqual(s.wram(SV_LADDER), 1)
        self.assertEqual(s.wram(SV_CASH, 3), 3800)
        self.assertEqual(s.wram(SV_LEVEL), 2)

    def test_jump_start_is_a_foul(self):
        s = new_game()
        start_race(s, 0)
        s.step(20)
        s.press(RIGHT)
        s.step(200)
        self.assertEqual(s.mem('game_mode'), 3)
        self.assertTrue(s.mem('res_flags') & 2)

    def test_street_race_runs_at_full_speed(self):
        s = new_game()
        start_race(s, 3)
        drive_race(s, launch=5000, shift_margin=300)
        self.assertEqual(s.mem('game_mode'), 3)
        self.assertLessEqual(s.mem('lag'), 1)

    def test_dealer_and_crate(self):
        s = new_game()
        # give the player money through WRAM, then fix the checksum by
        # letting the game save after a purchase
        s.nes[SV_CASH] = 0x50
        s.nes[SV_CASH + 1] = 0xC3                    # $50000
        s.garage_goto(G_DEALER)
        s.press(A)
        s.step(40)
        s.press(RIGHT)                               # KOMET 1.6 ($7000)
        s.step(30)
        s.press(A)
        s.step(5)
        s.press(A)                                   # confirm
        s.step(10)
        self.assertEqual(s.wram(SV_CARS + 48), 1)
        self.assertEqual(s.wram(0x600D), 1)          # now driving it
        s.press(B)
        s.step(40)
        s.garage_goto(G_CRATES)
        s.press(A)
        s.step(40)
        cash = s.wram(SV_CASH, 3)
        s.press(A)                                   # standard crate
        s.step(60)
        self.assertNotEqual(s.wram(SV_CASH, 3), cash)
        self.assertEqual(s.wram(0x6013), 1)          # crates opened

    def test_dealer_streams_the_right_big_car(self):
        # every model's 2x tiles must come from its own shape (odd shapes
        # used to start 128 bytes early)
        here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        with open(os.path.join(here, 'build', 'bigcars.chr'), 'rb') as f:
            big = f.read()
        sys.path.insert(0, os.path.join(here, 'tools'))
        import gamedata as gd
        s = new_game()
        s.garage_goto(G_DEALER)
        s.press(A)
        s.step(40)
        for _ in range(gd.NDEALER):
            model = s.mem('dl_model')
            shape = model                            # every car has its own sprite
            wbuf = bytes(s.nes[0x6400 + i] for i in range(512))
            self.assertEqual(wbuf, big[shape * 512:shape * 512 + 512], 'model %d' % model)
            s.press(RIGHT)
            s.step(40)

    def test_ultra_rare_crate_car(self):
        s = new_game()
        s.nes[SV_GEMS] = 20                          # premium crate costs 10
        s.garage_goto(G_CRATES)
        s.press(A)
        s.step(40)
        s.press(DOWN)                                # premium crate
        # seed the RNG so the crate's first roll is a hit (< 5 of 256)
        lo, hi = seed_for(lambda r: r < 5)
        s.nes[s.sym['rng']] = lo
        s.nes[s.sym['rng'] + 1] = hi
        s.press(A)
        s.step(80)
        self.assertEqual(s.wram(SV_CARS + 48), 12, 'crate car in slot 1')
        self.assertEqual(s.wram(SV_CARS + 48 + 15), 0x28, 'painted gold')
        # the dealer never sells it: browsing left from the first car wraps to 11
        s.press(B, hold=12)
        s.step(40)
        s.garage_goto(G_DEALER)
        s.press(A)
        s.step(40)
        s.press(LEFT)
        s.step(30)
        self.assertEqual(s.mem('dl_model'), 11)


def rand_step(lo, hi):
    """One call of the ROM's rand (8-step Galois LFSR) -> (result, hi)."""
    a = lo
    for _ in range(8):
        c = a >> 7
        a = (a << 1) & 0xFF
        c2 = hi >> 7
        hi = ((hi << 1) | c) & 0xFF
        if c2:
            a ^= 0x2D
    return a, hi


def seed_for(want):
    for hi in range(1, 256):
        for lo in range(256):
            if want(rand_step(lo, hi)[0]):
                return lo, hi
    raise AssertionError('no seed')


if __name__ == '__main__':
    unittest.main()
