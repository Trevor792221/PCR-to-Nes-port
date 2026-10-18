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

CR_PARTS, CR_PAINT, CR_FINAL, CR_GEARS = 1, 15, 18, 20
CR_FUEL, CR_TIMING, CR_TIREP, CR_BOOST, CR_LAUNCH, CR_NOS, CR_SWAP = 34, 42, 43, 44, 45, 46, 47
CR_SIZE = 48


def record(model, parts, final=None, gears=None, tune=None, engine=0, drive=0):
    c = gd.CARS[model]
    rec = [0] * CR_SIZE
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
    if tune:
        for k, f in enumerate(tune.fuel):
            rec[CR_FUEL + k] = f & 0xFF
        rec[CR_TIMING] = tune.timing & 0xFF
        rec[CR_TIREP] = tune.tirep & 0xFF
        rec[CR_BOOST] = tune.boost & 0xFF
        rec[CR_LAUNCH] = tune.launch
        rec[CR_NOS] = tune.nos & 0xFF
    rec[CR_SWAP] = engine | drive << 5            # engine + 1, drivetrain + 1
    return rec


class Physics(unittest.TestCase):
    def setup_car(self, cpu, slot, model, parts, tune=None, engine=0, drive=0, weather=0):
        rec = record(model, parts, tune=tune, engine=engine, drive=drive)
        base = cpu.sym['tmp_rec']
        cpu.mem[base:base + CR_SIZE] = bytes(rec)
        cpu.put('ptr0', base, size=2)
        cpu.put('race_weather', weather)
        cpu.call('phys_setup', x=slot)
        return gd.Car(model, parts, tune=tune, engine=engine, drive=drive, weather=weather)

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
        self.assertEqual(cpu.get('ph_mass_l', x) | cpu.get('ph_mass_h', x) << 8, car.mass)
        self.assertEqual(cpu.get('ph_redl_l', x) | cpu.get('ph_redl_h', x) << 8, car.redline)
        self.assertEqual(cpu.get('ph_hpm_l', x) | cpu.get('ph_hpm_h', x) << 8, car.hpmult & 0xFFFF)
        self.assertEqual((cpu.get('ph_nos_add', x), cpu.get('ph_nos_fr', x)),
                         (car.nos_add, car.nos_frames))
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

    def run_race(self, model, parts, launch, x=0, frames=900, tune=None, engine=0, drive=0):
        cpu = CPU()
        car = self.setup_car(cpu, x, model, parts, tune, engine, drive)
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

    def test_tune_maths_match_the_model(self):
        import random
        rnd = random.Random(5)
        cpu = CPU()
        for n in range(400):
            model = rnd.randrange(gd.NCARS)
            parts = [rnd.randint(0, 4) for _ in range(gd.NPARTS)]
            if n % 3 == 0:
                parts[gd.P_TURBO] = 0
            tune = gd.Tune([rnd.randint(-5, 5) for _ in range(8)], rnd.randint(-5, 5),
                           rnd.randint(gd.TIREP_MIN, gd.TIREP_MAX), rnd.randint(-12, 12),
                           rnd.choice([0, 0, rnd.randint(20, 90)]), rnd.randint(-4, 4))
            engine = drive = 0
            if model != gd.CRATE_CAR and n % 2:
                engine = rnd.choice([0] + [e + 1 for e in gd.SWAP_ENGINES])
                drive = rnd.randint(0, 3)
            weather = rnd.choice([0, 0, 1, 2, 3])
            car = self.setup_car(cpu, n & 1, model, parts, tune, engine, drive, weather)
            tn, x = car.tune, n & 1
            got = dict(hpm=cpu.get('tn_hpm', size=2), bmul=cpu.get('tn_bmul'),
                       grip=cpu.get('tn_grip'), roll=cpu.get('ph_roll', x),
                       launch=cpu.get('ph_ls_l', x) | cpu.get('ph_ls_h', x) << 8,
                       psi=cpu.get('tn_psi'), knock=cpu.get('tn_knock'), lean=cpu.get('tn_lean'),
                       band=[cpu.get('tn_band', k) or 256 for k in range(8)])
            want = dict(tn, hpm=tn['hpm'] & 0xFFFF, grip=tn['grip'] & 0xFF)
            self.assertEqual(got, want, 'model %d parts %r tune %r swap %d %d weather %d'
                             % (model, parts, vars(tune), engine, drive, weather))
            self.assertEqual((cpu.get('ph_eng', x), cpu.get('ph_drv', x), cpu.get('ph_ecv', x)),
                             (car.engine, car.drive, gd.ENGINES[car.engine][4]))
            self.check_setup(cpu, x, car)

    def test_tuned_races(self):
        T = gd.Tune
        # overboost on big injectors, a lean top end, some advance
        self.run_race(9, [2, 2, 2, 4, 2, 2, 2, 3, 2, 2, 4, 2, 2, 4], launch=6000,
                      tune=T([0, 0, 1, 2, 3, 3, 3, 3], 3, -6, 6, 0))
        # knock and lean everywhere, boost turned down, hard tires
        self.run_race(7, [0, 0, 1, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], launch=5000,
                      tune=T([5] * 8, 5, 8, -5, 0))
        # 2-step launch control, wheelie bars, soft tires on a RWD car
        self.run_race(8, [1, 1, 2, 0, 1, 1, 1, 2, 1, 1, 0, 0, 4, 0], launch=9000,
                      tune=T([-2] * 8, -1, -14, 0, 38), x=1)
        # swaps: a rotary in the Pukku turned RWD, a big block in an AWD Komet
        self.run_race(0, [2] * 14, launch=7000, engine=14, drive=2)
        self.run_race(1, [1, 1, 1, 2, 1, 0, 1, 2, 1, 0, 0, 0, 0, 0], launch=5000, engine=17, drive=3, x=1)

    def test_nitrous_power_for_duration(self):
        parts = [0] * 5 + [3] + [0] * 8              # race nitrous: 136 boost, 210 frames
        even = gd.Car(9, parts)
        hit = gd.Car(9, parts, tune=gd.Tune(nos=-4))
        long_ = gd.Car(9, parts, tune=gd.Tune(nos=4))
        self.assertEqual((even.nos_add, even.nos_frames), (136, 210))
        self.assertEqual((hit.nos_add, hit.nos_frames), (204, 140), 'x1.5 for x2/3')
        self.assertEqual((long_.nos_add, long_.nos_frames), (68, 255), 'x1/2, capped at 255 frames')
        self.assertEqual(gd.Car(9, [0] * 14, tune=gd.Tune(nos=-4)).nos_add, 0, 'no kit, no nitrous')
        for n in range(-4, 3):                       # about the same nitrous in total
            a, f = gd.nos_tuned(2, n)                # (until the shot hits 255 frames)
            self.assertAlmostEqual(a * f / (96 * 180), 1, delta=.07)
        cpu = CPU()
        for n in (-4, 0, 4):
            car = self.setup_car(cpu, 1, 9, [0] * 5 + [4] + [0] * 8, tune=gd.Tune(nos=n))
            self.check_setup(cpu, 1, car)

    def test_weather_grip(self):
        parts = [2] * 14
        dry, wet, snow = (gd.Car(8, parts, weather=w) for w in (gd.CLEAR, gd.RAIN, gd.SNOW))
        self.assertEqual(gd.Car(8, parts, weather=gd.CLOUDY).trac, dry.trac, 'clouds: no change')
        self.assertLess(wet.trac, dry.trac)
        self.assertLess(snow.trac, wet.trac)
        self.assertEqual(dry.k0h, snow.k0h, 'grip only')
        cpu = CPU()
        for w in range(4):
            car = self.setup_car(cpu, 0, 8, parts, weather=w)
            self.check_setup(cpu, 0, car)

    def test_swaps(self):
        stock = gd.Car(4, [0] * 14)                  # Hollis SS: RWD, 5.7 V8
        awd = gd.Car(4, [0] * 14, drive=3)
        self.assertEqual(awd.mass - stock.mass, gd.DRIVE_KG[2] - gd.DRIVE_KG[1])
        self.assertGreater(awd.trac, stock.trac, 'AWD launches harder')
        self.assertLess(awd.hpmult, stock.hpmult, 'but loses more through the driveline')
        fwd = gd.Car(4, [0] * 14, drive=1)
        self.assertLess(fwd.mass, stock.mass)
        self.assertLess(fwd.trac, stock.trac)
        rot = gd.Car(4, [0] * 14, engine=14)         # twin rotor
        self.assertEqual(rot.redline, 9000)
        self.assertEqual(rot.mass, stock.mass - 220 + 106)
        self.assertEqual(gd.Car(4, [0] * 14, engine=5).k0h, stock.k0h, 'its own engine = stock')

    def test_tuning_does_what_it_says(self):
        base = [2, 2, 2, 3, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0]
        stock = gd.Car(9, base)
        adv = gd.Car(9, base, tune=gd.Tune(timing=2))
        self.assertGreater(adv.hpmult, stock.hpmult, 'a little advance: more power')
        self.assertFalse(adv.tune['knock'])
        knock = gd.Car(9, base, tune=gd.Tune(timing=5, boost=7))
        self.assertTrue(knock.tune['knock'], 'too much advance on overboost knocks')
        lean = gd.Car(9, base, tune=gd.Tune(fuel=[3] * 8))
        self.assertEqual(lean.tune['lean'], 0xFF, 'stock injectors: no lean headroom')
        inj = base[:13] + [1]
        ok = gd.Car(9, inj, tune=gd.Tune(fuel=[3] * 8))
        self.assertEqual(ok.tune['lean'], 0, 'injectors give headroom')
        self.assertGreater(ok.hpmult, gd.Car(9, inj).hpmult)
        more = gd.Car(9, base[:13] + [4], tune=gd.Tune(boost=6))
        self.assertGreater(more.hpmult, gd.Car(9, base[:13] + [4]).hpmult, 'overboost')
        soft = gd.Car(8, [0] * 14, tune=gd.Tune(tirep=-10))
        self.assertGreater(soft.trac, gd.Car(8, [0] * 14).trac, 'soft tires grip')
        self.assertGreater(soft.roll, gd.ROLL)
        bars = gd.Car(8, [0] * 12 + [4, 0])
        self.assertGreater(bars.trac, gd.Car(8, [0] * 14).trac, 'wheelie bars (RWD)')
        self.assertGreater(gd.Car(1, [0] * 12 + [4, 0]).trac, gd.Car(1, [0] * 14).trac,
                           'FWD too: less squat keeps weight on the front')
        two = gd.Car(8, [0, 0, 1] + [0] * 11, tune=gd.Tune(launch=40))
        two.throttle = True
        for _ in range(200):
            two.step()
        self.assertEqual(two.rpm, 4000, '2-step holds the launch rpm')
        self.assertEqual(gd.Car(8, [0] * 14, tune=gd.Tune(launch=40)).launch, 0, 'needs the ECU')
        noecu = base[:2] + [0] + base[3:]
        for tune in (gd.Tune(timing=3), gd.Tune(fuel=[-3] * 8), gd.Tune(timing=5, fuel=[5] * 8)):
            self.assertEqual(gd.Car(9, noecu, tune=tune).tune, gd.Car(9, noecu).tune,
                             'timing and the fuel map need the ECU')

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
