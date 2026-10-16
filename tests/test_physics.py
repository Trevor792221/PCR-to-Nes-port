"""The 6502 physics must match the Python reference model in
tools/gamedata.py exactly, frame by frame."""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(os.path.dirname(HERE), 'tools'))

import gamedata as gd
from cpu import CPU

CR_PARTS, CR_FINAL, CR_GEARS = 1, 16, 18


def record(model, parts, final=None, gears=None):
    c = gd.CARS[model]
    rec = [0] * 32
    rec[0] = model
    parts = list(parts) + [0] * (gd.NPARTS - len(parts))
    rec[CR_PARTS:CR_PARTS + gd.NPARTS] = parts
    final = final if final is not None else gd.gear_raw(c[7])
    gears = gears or [gd.gear_raw(g) for g in gd.car_gears(model)]
    rec[CR_FINAL] = final & 0xFF
    rec[CR_FINAL + 1] = final >> 8
    for i, g in enumerate(gears):
        rec[CR_GEARS + 2 * i] = g & 0xFF
        rec[CR_GEARS + 2 * i + 1] = g >> 8
    return rec


class Physics(unittest.TestCase):
    def setup_car(self, cpu, slot, model, parts):
        rec = record(model, parts)
        base = cpu.sym['tmp_rec']
        cpu.mem[base:base + 32] = bytes(rec)
        cpu.put('ptr0', base, size=2)
        cpu.call('phys_setup', x=slot)
        return gd.Car(model, parts)

    def state(self, cpu, x):
        g = lambda n: cpu.get(n, x)
        return dict(v=g('ph_v0') | g('ph_v1') << 8 | g('ph_v2') << 16,
                    wv=g('ph_w0') | g('ph_w1') << 8 | g('ph_w2') << 16,
                    pos=g('ph_p0') | g('ph_p1') << 8 | g('ph_p2') << 16,
                    rpm=g('ph_rpm_l') | g('ph_rpm_h') << 8,
                    gear=g('ph_gear'), spool=g('ph_spool'),
                    spin=g('ph_spin'), slip=g('ph_slip'))

    def py_state(self, car):
        return dict(v=car.v, wv=car.wv, pos=car.pos, rpm=car.rpm, gear=car.gear,
                    spool=car.spool, spin=int(car.spin), slip=int(car.slip))

    def check_setup(self, cpu, x, car):
        self.assertEqual(cpu.get('ph_k0h_l', x) | cpu.get('ph_k0h_h', x) << 8, car.k0h)
        self.assertEqual(cpu.get('ph_trac_l', x) | cpu.get('ph_trac_h', x) << 8, car.trac)
        self.assertEqual(cpu.get('ph_dk_l', x) | cpu.get('ph_dk_h', x) << 8, car.dk)
        for gi in range(1, car.ngears + 1):
            i = x * 8 + gi
            self.assertEqual(cpu.get('ph_rs_l', i) | cpu.get('ph_rs_h', i) << 8, car.rs[gi])
            self.assertEqual(cpu.get('ph_kg_l', i) | cpu.get('ph_kg_h', i) << 8, car.kg[gi])
        for b in range(48):
            self.assertEqual(cpu.get('ph_curve', x * 48 + b), car.curve[b], 'curve %d' % b)
            self.assertEqual(cpu.get('ph_bcurve', x * 48 + b), car.bcurve[b], 'bcurve %d' % b)

    def run_race(self, model, parts, launch, x=0, frames=900):
        cpu = CPU()
        car = self.setup_car(cpu, x, model, parts)
        self.check_setup(cpu, x, car)
        car.reset()
        # rev up, launch, shift near the redline, nitrous from 2nd gear
        for f in range(frames):
            if f < 120:
                thr = car.rpm < launch
            else:
                thr = True
            car.throttle = thr
            cpu.put('ph_thr', int(thr), x)
            if f == 120:
                car.shift_up()
                cpu.call('phys_shift_up', x=x)
            elif f > 120 and car.gear < car.ngears and car.rpm >= car.redline - 250 \
                    and not car.shift_t and not car.slip:
                car.shift_up()
                cpu.call('phys_shift_up', x=x)
            if car.gear >= 2 and f % 7 == 0:
                car.nitrous()
                cpu.call('phys_nitrous', x=x)
            car.step()
            cpu.call('phys_step', x=x)
            self.assertEqual(self.state(cpu, x), self.py_state(car),
                             'model %d frame %d' % (model, f))
        return cpu

    def test_every_car_stock(self):
        for m in range(gd.NCARS):
            self.run_race(m, [0] * 12, launch=4500, frames=600)

    def test_upgraded_cars(self):
        self.run_race(2, [2, 2, 2, 2, 2, 2, 2, 2, 2, 2], launch=6000)
        self.run_race(8, [4] * 12, launch=3000, x=1)
        self.run_race(11, [4, 4, 4, 4, 4, 4, 4, 0, 0, 4], launch=7000)   # wheelspin
        self.run_race(9, [3, 3, 3, 3, 3, 0, 3, 3, 3, 3, 4, 4], launch=6000)  # intercooler, aero
        self.run_race(4, [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 3], launch=4000)  # no turbo

    def test_intercooler_and_aero_help(self):
        base = gd.Car(9, [0, 0, 0, 4] + [0] * 8)
        ic = gd.Car(9, [0, 0, 0, 4] + [0] * 6 + [4, 0])
        aero = gd.Car(9, [0, 0, 0, 4] + [0] * 7 + [4])
        self.assertGreater(ic.hpmult, base.hpmult)
        self.assertGreater(max(ic.bcurve), max(base.bcurve))
        self.assertLess(aero.dk, base.dk)
        self.assertGreater(aero.trac, base.trac)
        t0 = gd.run(base, dist=gd.HALF)[1]
        self.assertGreater(gd.run(aero, dist=gd.HALF)[1], t0, 'aero: higher trap speed')
        self.assertGreater(gd.run(ic, dist=gd.HALF)[1], t0, 'intercooler: higher trap speed')

    def test_crate_car_never_spins_and_does_400(self):
        for parts in ([0] * 12, [4] * 12):
            cpu = self.run_race(gd.CRATE_CAR, parts, launch=9000, frames=900)
            car = gd.Car(gd.CRATE_CAR, parts)
            spun = []
            orig = car.step

            def step():
                orig()
                spun.append(car.spin)
            car.step = step
            gd.run(car, dist=30000)
            self.assertFalse(any(spun), 'wheelspin with parts %r' % parts)
            self.assertGreaterEqual(car.mph(), 400)

    def test_speed_readout_goes_past_255(self):
        cpu = CPU()
        opts = 0x600E
        for v_raw, unit_kmh, expect in ((2150, 0, 285), (2150, 1, 461), (1000, 0, 132),
                                        (9000, 0, 999), (0, 0, 0)):
            cpu.mem[opts] = unit_kmh
            cpu.put('ph_v1', v_raw & 0xFF)
            cpu.put('ph_v2', v_raw >> 8)
            lo = cpu.call('phys_speed', x=0)
            self.assertEqual(lo | cpu.get('spd_hi') << 8, expect)
            cpu.call('fmt3w', a=lo)
            self.assertEqual(bytes(cpu.mem[cpu.sym['numbuf'] + 5:cpu.sym['numbuf'] + 8]).decode(),
                             '%3d' % expect)

    def test_maxed_hypercar_tops_255_mph(self):
        car = gd.Car(11, [4] * 12)
        _, trap, _ = gd.run(car, dist=gd.HALF)
        self.assertGreater(trap, 255)

    def test_step_is_fast_enough(self):
        cpu = self.run_race(10, [3] * 12, launch=5000, frames=300)
        cpu.call('phys_step', x=0)
        self.assertLess(cpu.cycles, 3500)


if __name__ == '__main__':
    unittest.main()
