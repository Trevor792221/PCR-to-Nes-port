"""Traffic hits are pixel perfect: two vehicles crash when, and only when,
their drawn pixels overlap."""
import os
import random
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'tools'))
import art                     # noqa: E402
from cpu import CPU            # noqa: E402

SHAPES = list(range(art.NCAR_SHAPES)) + art.TRAFFIC_ORDER
LANE_Y = [147, 179, 211]


def pixels(shape):
    a, b = art.car_pixels(SHAPES[shape], 0), art.car_pixels(SHAPES[shape], 1)
    return {(x, y) for y in range(16) for x in range(32) if a[y][x] != '.' or b[y][x] != '.'}


PIX = [pixels(s) for s in range(len(SHAPES))]


def overlap(sa, sb, dx, dy):
    """B drawn dx right and dy down of A: do any pixels meet?"""
    return any((x - dx, y - dy) in PIX[sb] for x, y in PIX[sa])


class TrafficHits(unittest.TestCase):
    def pix_hit(self, cpu, sa, sb, dx, dy):
        """Car shape sa (0-12) against traffic shape sb (13-17)."""
        cpu.put('hb_sa', sa)
        cpu.put('hb_sb', sb - 13)
        cpu.put('hb_dx', dx & 0xFF)
        cpu.put('hb_dy', dy & 0xFF)
        cpu.call('pix_hit')
        return bool(cpu.mpu.p & 1)

    def test_pixels_match_the_art(self):
        cpu = CPU()
        rnd = random.Random(4)
        cases = [(sa, sb, dx, dy) for sa in (0, 4, 12) for sb in (13, 15, 17)
                 for dx in (-31, -30, -20, -1, 0, 1, 20, 30, 31) for dy in (-15, -9, 0, 9, 15)]
        cases += [(rnd.randrange(13), rnd.randrange(13, 18), rnd.randint(-31, 31), rnd.randint(-15, 15))
                  for _ in range(3000)]
        worst = 0
        for sa, sb, dx, dy in cases:
            self.assertEqual(self.pix_hit(cpu, sa, sb, dx, dy), overlap(sa, sb, dx, dy),
                             'shapes %d, %d at %d, %d' % (sa, sb, dx, dy))
            worst = max(worst, cpu.cycles)
        self.assertLess(worst, 1500, 'cheap enough for every frame')

    def scene(self, model, shape_type, car_y, lane, dx):
        """Car 0 (model) at x 64, y car_y; traffic of type shape_type in lane,
        dx right of it.  -> crashed?"""
        cpu = CPU()
        cpu.put('ph_model', model)
        cpu.put('ph_p1', 0)
        cpu.put('ph_p2', 0)
        cpu.put('car_y', car_y)
        cpu.put('crash_t', 0)
        cpu.put('tr_lane', lane)
        cpu.put('tr_type', shape_type)
        cpu.put('tr_x_l', (64 + dx) & 0xFF)
        cpu.put('tr_x_h', (64 + dx) >> 8 & 0xFF)
        cpu.put('tr_on', 1)
        cpu.put('tmp7', 0)
        cpu.call('crash_check', y=0)
        return cpu.get('crash_t') != 0

    def test_crashes_are_pixel_perfect(self):
        rnd = random.Random(9)
        hits = misses = 0
        for _ in range(400):
            model, ttype = rnd.randrange(13), rnd.randrange(5)
            lane = rnd.randrange(3)
            dy = rnd.randint(-17, 17)                # the car changing lanes, or level
            dx = rnd.randint(-34, 34)
            want = abs(dx) < 32 and abs(dy) < 16 and overlap(model, 13 + ttype, dx, dy)
            got = self.scene(model, ttype, LANE_Y[lane] - dy, lane, dx)
            self.assertEqual(got, want, 'model %d type %d dx %d dy %d' % (model, ttype, dx, dy))
            hits += want
            misses += not want
        self.assertGreater(hits, 50)
        self.assertGreater(misses, 50)

    def test_a_close_shave_is_not_a_crash(self):
        # level in the lane, nose to tail: the Pukku's bumper one pixel short
        # of the van's (the old box called this a crash 4 pixels early)
        front = max(x for x, y in PIX[0])
        rear = min(x for x, y in PIX[14])
        gap = front - rear + 1                       # first dx that doesn't touch
        self.assertFalse(self.scene(0, 1, LANE_Y[1], 1, gap))
        self.assertTrue(self.scene(0, 1, LANE_Y[1], 1, gap - 1))


    def test_near_misses_never_slow_the_race(self):
        """The costliest near miss (boxes overlapping, pixels not) held on both
        cars every frame of a street race: no frame is late."""
        from harness import Sim, A, RIGHT, rpm, redline     # noqa: F401
        from test_game import new_game, start_race
        from test_features import give_car
        s = new_game()
        give_car(s, 0, 12, 0)
        start_race(s, 3)
        lag0, f, sym = s.mem('lag'), 0, s.sym
        while s.mem('game_mode') == 2 and f < 600:
            st = s.mem('rc_state')
            b = A if (st == 0 and rpm(s) < 4500) or st == 1 else 0
            if st == 1 and f % 4 < 2 and (s.mem('ph_gear') == 0 or (
                    rpm(s) >= redline(s) - 300 and s.mem('ph_shift_t') == 0)):
                b |= RIGHT
            for i in range(2):
                lane = s.mem('car_lane', i)
                x = (68 + (s.mem('ph_p1', i) | s.mem('ph_p2', i) << 8)) & 0xFFFF
                s.nes[sym['tr_on'] + i], s.nes[sym['tr_type'] + i] = 1, 1
                s.nes[sym['tr_lane'] + i] = lane
                s.nes[sym['tr_x_l'] + i], s.nes[sym['tr_x_h'] + i] = x & 0xFF, x >> 8
                s.nes[sym['car_y'] + i] = LANE_Y[lane] + 10
            s.step(1, b)
            f += 1
        self.assertFalse(overlap(12, 14, 4, -10), 'a near miss')
        self.assertEqual((s.mem('crash_t'), s.mem('crash_t', 1)), (0, 0))
        self.assertEqual(s.mem('lag') - lag0, 0)


if __name__ == '__main__':
    unittest.main()
