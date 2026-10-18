"""Engine tuning (TUNE screen, fuel map), the new parts and their locks."""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from harness import *          # noqa: E402,F401,F403
from test_game import new_game, start_race, SV_CARS, G_TUNE, G_PARTS  # noqa: E402
from test_features import give_car, set_cash                        # noqa: E402

CR_PARTS, CR_FUEL, CR_TIMING, CR_TIREP, CR_BOOST, CR_LAUNCH = 1, 34, 42, 43, 44, 45
P_ECU, P_TURBO, P_ICOOL, P_WHEELIE, P_INJECT = 2, 3, 10, 12, 13
IGN, BOOST, TIRE, LAUNCH, RESET = 2, 3, 4, 5, 6


def signed(v):
    return v - 256 if v >= 128 else v


def car_with(model, **parts):
    s = new_game()
    give_car(s, 0, model, 0)
    for name, lv in parts.items():
        s.nes[SV_CARS + CR_PARTS + globals()['P_' + name.upper()]] = lv
    return s


def open_tune(s):
    s.garage_goto(G_TUNE)
    s.press(A)
    s.step(80)
    assert s.mem('ui_count') == 8


def nudge(s, row, n):
    s.list_goto('ui_sel', row)
    for _ in range(abs(n)):
        s.press(RIGHT if n > 0 else LEFT)
        s.step(45)


class Tune(unittest.TestCase):
    def rec(self, s, off):
        return signed(s.wram(SV_CARS + off))

    def test_ignition_and_tire_pressure_limits(self):
        s = car_with(9, ecu=1)
        open_tune(s)
        nudge(s, IGN, 2)
        self.assertEqual(self.rec(s, CR_TIMING), 2)
        nudge(s, IGN, 8)
        self.assertEqual(self.rec(s, CR_TIMING), 5, 'max +5')
        nudge(s, TIRE, -16)
        self.assertEqual(self.rec(s, CR_TIREP), -14, '18 psi at the least')
        nudge(s, TIRE, 25)
        self.assertEqual(self.rec(s, CR_TIREP), 8, '40 psi at most')
        self.assertEqual(s.mem('lag'), 0)
        s.list_goto('ui_sel', RESET)
        s.press(A)
        s.step(60)
        self.assertEqual([s.wram(SV_CARS + CR_FUEL + i) for i in range(12)], [0] * 12)

    def test_boost_needs_a_turbo_and_stays_in_its_range(self):
        s = car_with(9)
        open_tune(s)
        nudge(s, BOOST, 2)
        self.assertEqual(self.rec(s, CR_BOOST), 0, 'no turbo: no boost to set')
        s = car_with(9, turbo=1)                     # 6 psi, 9 at most
        open_tune(s)
        nudge(s, BOOST, 6)
        self.assertEqual(self.rec(s, CR_BOOST), 3)
        self.assertEqual(s.mem('tn_psi'), 9)
        nudge(s, BOOST, -9)
        self.assertEqual(s.mem('tn_psi'), 3, 'down to 3 psi')

    def test_two_step_needs_the_ecu(self):
        s = car_with(8)
        open_tune(s)
        nudge(s, LAUNCH, 1)
        self.assertEqual(s.wram(SV_CARS + CR_LAUNCH), 0)
        s = car_with(8, ecu=1)
        open_tune(s)
        nudge(s, LAUNCH, 3)
        self.assertEqual(s.wram(SV_CARS + CR_LAUNCH), 24, '2000, then 200 rpm steps')
        nudge(s, LAUNCH, -3)
        self.assertEqual(s.wram(SV_CARS + CR_LAUNCH), 0, 'off again')

    def test_fuel_map(self):
        s = car_with(9, inject=1, ecu=1)
        open_tune(s)
        s.list_goto('ui_sel', 1)
        s.press(A)
        s.step(60)
        s.press(UP)
        s.step(40)
        s.press(UP)
        s.step(40)
        fuel = lambda: [self.rec(s, CR_FUEL + k) for k in range(8)]
        self.assertEqual(fuel(), [2] + [0] * 7)
        s.press(A)                                   # same for every cell
        s.step(90)
        self.assertEqual(fuel(), [2] * 8)
        self.assertEqual(s.mem('tn_lean'), 0, 'one injector level: 3 steps of headroom')
        s.press(RIGHT)
        s.step(5)
        for _ in range(4):
            s.press(UP)
            s.step(40)
        self.assertEqual(fuel()[1], 5)
        self.assertEqual(s.mem('tn_lean'), 2, 'cell 2 runs lean')
        s.press(SELECT)
        s.step(90)
        self.assertEqual(fuel(), [0] * 8)
        self.assertEqual(s.mem('lag'), 0)
        s.press(B)
        s.step(60)
        self.assertEqual(s.mem('ui_count'), 8, 'back on the tune screen')

    def test_timing_and_fuel_map_need_the_ecu(self):
        s = car_with(9, inject=1)
        open_tune(s)
        nudge(s, IGN, 2)
        self.assertEqual(self.rec(s, CR_TIMING), 0, 'no ECU: no timing')
        s.list_goto('ui_sel', 1)
        s.press(A)
        s.step(60)
        self.assertEqual(s.mem('ui_count'), 8, 'no ECU: the fuel map stays shut')
        s.nes[SV_CARS + CR_TIMING] = 5               # e.g. from a TUNE password
        for k in range(8):
            s.nes[SV_CARS + CR_FUEL + k] = 5
        s.list_goto('ui_sel', TIRE)                  # re-measure the car
        s.press(RIGHT)
        s.step(45)
        self.assertEqual((s.mem('tn_knock'), s.mem('tn_lean')), (0, 0), 'ignored without one')
        self.assertEqual(s.mem16('tn_hpm'), 0)

    def test_two_step_holds_the_revs_on_the_line(self):
        s = car_with(8, ecu=1)
        s.nes[SV_CARS + CR_LAUNCH] = 45
        start_race(s, 4)                             # test run
        s.step(20)
        rpms = []
        for _ in range(100):                         # floor it before green
            s.step(1, A)
            rpms.append(s.mem('ph_rpm_l') | s.mem('ph_rpm_h') << 8)
        self.assertEqual(max(rpms), 4500)
        self.assertEqual(rpms[-30:], [4500] * 30)

    def test_part_locks(self):
        s = car_with(9)                              # AWD, no turbo
        set_cash(s, 9000000)
        s.garage_goto(G_PARTS)
        s.press(A)
        s.step(60)
        s.list_goto('ui_sel', 4)                     # intercooler
        s.press(A)
        s.step(20)
        self.assertEqual(s.wram(SV_CARS + CR_PARTS + P_ICOOL), 0, 'needs a turbo')
        s.list_goto('ui_sel', 3)                     # turbo, then the intercooler
        s.press(A)
        s.step(20)
        s.list_goto('ui_sel', 4)
        s.press(A)
        s.step(20)
        self.assertEqual(s.wram(SV_CARS + CR_PARTS + P_ICOOL), 1)
        s.list_goto('ui_sel', 5)                     # injectors
        s.press(A)
        s.step(20)
        self.assertEqual(s.wram(SV_CARS + CR_PARTS + P_INJECT), 1)
        s.press(RIGHT)                               # chassis page
        s.step(60)
        s.list_goto('ui_sel', 5)                     # wheelie bars on AWD: fine
        s.press(A)
        s.step(20)
        self.assertEqual(s.wram(SV_CARS + CR_PARTS + P_WHEELIE), 1)
        s = car_with(1)                              # FWD
        set_cash(s, 9000000)
        s.garage_goto(G_PARTS)
        s.press(A)
        s.step(60)
        s.press(RIGHT)
        s.step(60)
        s.list_goto('ui_sel', 5)
        s.press(A)
        s.step(20)
        self.assertEqual(s.wram(SV_CARS + CR_PARTS + P_WHEELIE), 1, 'FWD cars can fit them too')

    def test_wheelie_bar_graphics(self):
        oam = lambda s: [(s.nes[0x200 + i + 1], s.nes[0x200 + i + 2]) for i in range(0, 256, 4)]
        for model, bars, shown in ((8, 2, True), (8, 0, False), (1, 3, True)):  # RWD; FWD
            s = car_with(model, wheelie=bars)
            start_race(s, 4)
            s.step(30)
            self.assertEqual((0x28, 1) in oam(s), shown, 'model %d bars %d' % (model, bars))

    def test_a_safe_tune_makes_more_power(self):
        s = car_with(9, turbo=3, icool=3, inject=3, ecu=2)
        open_tune(s)
        nudge(s, IGN, 3)
        nudge(s, BOOST, 3)
        self.assertEqual(s.mem('tn_knock'), 0)
        self.assertEqual(s.mem('tn_lean'), 0)
        self.assertGreater(s.mem16('tn_hpm'), 0)
        nudge(s, IGN, 2)                             # +5 on 15 psi: the
        self.assertEqual(s.mem('tn_knock'), 0)       # intercooler copes
        nudge(s, BOOST, 3)                           # 18 psi: it knocks
        self.assertNotEqual(s.mem('tn_knock'), 0)
        sys.path.insert(0, os.path.join(HERE, '..', 'tools'))
        import gamedata as gd
        parts = [0] * 14
        parts[P_TURBO], parts[P_ICOOL], parts[P_INJECT], parts[P_ECU] = 3, 3, 3, 2
        self.assertGreater(gd.Car(9, parts, tune=gd.Tune(timing=3, boost=3)).hpmult,
                           gd.Car(9, parts).hpmult)


if __name__ == '__main__':
    unittest.main()
