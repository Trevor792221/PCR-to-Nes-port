"""Every NMI must finish its PPU writes inside vblank.  On real hardware,
VRAM writes that spill into the visible frame land at the wrong addresses
and leave lasting garbage on screen (emulators are often more forgiving)."""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from harness import *          # noqa: F401,F403
from nmi_timing import nmi_cycles, VBLANK_BUDGET


class NMIBudget(unittest.TestCase):
    def watch(self, s, bank, frames, buttons=lambda i: 0):
        worst = 0
        for i in range(frames):
            s.step(1, buttons(i))
            c = nmi_cycles(s, bank)
            if c:
                worst = max(worst, c)
        return worst

    def leave(self, s):
        s.press(B, hold=12)
        s.step(40)
        self.assertEqual(s.mem('cur_bank'), 1, 'back in the garage')

    def check(self, name, cycles):
        self.assertLessEqual(cycles, VBLANK_BUDGET, '%s NMI takes %d cycles' % (name, cycles))

    def test_menus(self):
        s = Sim(boot=120)
        self.check('title', self.watch(s, 1, 30))
        s.press(A)
        self.check('garage', self.watch(s, 1, 60))
        s.garage_goto(4)
        s.press(A)
        self.check('dealer', self.watch(s, 1, 400, lambda i: RIGHT if i % 25 < 2 else 0))
        self.check('dealer fast', self.watch(s, 1, 200, lambda i: LEFT if i % 6 < 2 else 0))
        self.leave(s)
        s.garage_goto(2)
        s.press(A)
        self.check('my cars', self.watch(s, 1, 60))
        self.leave(s)
        s.garage_goto(1)
        s.press(A)
        self.check('parts', self.watch(s, 3, 120, lambda i: A if i == 40 else (DOWN if i % 10 == 0 else 0)))
        self.leave(s)
        s.nes[0x6020 + 1 + 2] = 1                    # an ECU: timing and the fuel map
        s.garage_goto(3)
        s.press(A)
        self.check('tune', self.watch(s, 3, 80))
        s.list_goto('ui_sel', 2)                     # ignition
        self.check('tune ignition', self.watch(s, 3, 200, lambda i: RIGHT if i % 40 < 2 else 0))
        s.list_goto('ui_sel', 1)                     # fuel map
        s.press(A)
        self.check('fuel map', self.watch(s, 3, 300, lambda i: A if i == 200 else
                                          (UP if i % 30 < 2 else (RIGHT if i % 60 == 10 else 0))))
        s.press(B, hold=12)
        s.step(80)
        s.list_goto('ui_sel', 0)                     # gear ratios
        s.press(A)
        self.check('gears', self.watch(s, 3, 120, lambda i: RIGHT if i % 6 < 2 else 0))
        s.press(B, hold=12)
        s.step(80)
        self.leave(s)
        s.garage_goto(5)
        s.press(A)
        self.check('paint', self.watch(s, 3, 80, lambda i: RIGHT if i % 8 < 2 else 0))
        self.leave(s)
        s.garage_goto(7)
        s.press(A)
        self.check('dyno', self.watch(s, 3, 150))
        self.leave(s)
        s.nes[0x6007] = 99                           # gems for a swap
        s.garage_goto(10)
        s.press(A)
        self.check('swap', self.watch(s, 3, 200, lambda i: A if i == 150 else
                                      (RIGHT if i % 20 < 2 else 0)))
        self.leave(s)

    def test_two_player_race(self):
        # two tachs, gears, speeds and nitrous bars must still fit in vblank
        s = Sim(boot=120)
        s.press(A)
        s.step(40)
        s.garage_goto(0)
        s.press(A)
        s.step(30)
        s.press(A)                  # the map
        s.step(30)
        s.list_goto('rs_sel', 6)
        s.press(A)
        worst, f, gears = 0, 0, set()
        while s.mem('game_mode') == 2 and f < 3000:
            bs = []
            for c in (0, 1):
                b = A
                g = s.mem('ph_gear', c)
                r = s.mem('ph_rpm_l', c) | s.mem('ph_rpm_h', c) << 8
                red = s.mem('ph_redl_l', c) | s.mem('ph_redl_h', c) << 8
                if g == 0:
                    b |= RIGHT if s.mem('rc_green') and f % 4 < 2 else 0
                elif r >= red - 300 and s.mem('ph_shift_t', c) == 0 and f % 4 < 2:
                    b |= RIGHT
                bs.append(b)
            s.step(1, bs[0] | bs[1] << 8)
            f += 1
            gears.add(s.mem('hud_gear1'))
            c = nmi_cycles(s, 2)
            if c:
                worst = max(worst, c)
        self.check('two-player race', worst)
        self.assertEqual(s.mem('lag'), 0)
        self.assertGreater(len(gears), 2, "player 2's gear shown")
        self.assertNotEqual(s.mem16('tach_k1'), 0, "player 2's tach scaled")

    def test_street_race(self):
        s = Sim(boot=120)
        s.nes[s.sym['weather_force']] = 3           # rain: the busiest VRAM queue
        s.press(A)
        s.step(40)
        s.garage_goto(0)
        s.press(A)
        s.step(30)
        s.press(A)                  # the map
        s.step(30)
        s.list_goto('rs_sel', 3)
        s.press(A)
        worst, f = 0, 0
        while s.mem('game_mode') == 2 and f < 4000:
            st, b = s.mem('rc_state'), 0
            if st == 0:
                b = A if rpm(s) < 5000 else 0
            elif st == 1:
                b = A
                if s.mem('ph_gear') == 0:
                    b |= RIGHT if f % 4 < 2 else 0
                elif rpm(s) >= redline(s) - 300 and s.mem('ph_shift_t') == 0 and f % 4 < 2:
                    b |= RIGHT
                if f % 200 == 100:
                    b |= UP
            s.step(1, b)
            f += 1
            c = nmi_cycles(s, 2)
            if c:
                worst = max(worst, c)
        self.check('street race', worst)
        self.check('results', self.watch(s, 1, 60))


if __name__ == '__main__':
    unittest.main()
