#!/usr/bin/env python3
"""Game data for Pixel Racer NES plus an integer reference model of the
drag-race physics.

The tables here are written out as ca65 source by ``mkdata.py``.  The
``Car`` class below follows the 6502 code in ``src/physics.s`` operation for
operation (same widths, same shifts), so it can be used to tune numbers and
to check the ROM's results.

Units
  v, wv     1/65536 pixel per frame (24 bit).  The top 16 bits ("v_raw") are
            1/256 px/frame.  1 m = 4 px, 60 frames/s, so
            m/s = v_raw * 15 / 256.
  pos       1/256 pixel (24 bit).  1/4 mile = 402.3 m = 1609 px.
  acc       1/65536 px/frame^2 (added to v).  1 m/s^2 = 72.8 units.
  rpm       engine rev/min (16 bit).
"""

# ---------------------------------------------------------------------------
# Torque curve shapes: 33 points over 0..redline (index = rpm*32/redline),
# plus 8 points past redline.  Values are fractions of peak torque * 255.
# ---------------------------------------------------------------------------

def _shape(points):
    out = []
    for i in range(41):
        x = i / 32.0
        for (x0, y0), (x1, y1) in zip(points, points[1:]):
            if x0 <= x <= x1:
                y = y0 + (y1 - y0) * (x - x0) / (x1 - x0)
                break
        else:
            y = points[-1][1]
        out.append(max(0, min(255, int(round(y)))))
    return out

CURVES = [
    # 0: high-revving four/six cylinder
    _shape([(0, 150), (.3, 190), (.5, 222), (.72, 255), (.9, 246), (1.0, 228), (1.3, 190)]),
    # 1: big V8, lots of low-end torque
    _shape([(0, 195), (.25, 238), (.45, 255), (.7, 244), (.9, 214), (1.0, 196), (1.3, 160)]),
    # 2: modern performance engine, flat curve
    _shape([(0, 172), (.3, 226), (.5, 250), (.65, 255), (.85, 250), (1.0, 236), (1.3, 200)]),
]

# ---------------------------------------------------------------------------
# Cars.  All names are made up.
# ---------------------------------------------------------------------------
FWD, RWD, AWD, AWDX = 0, 1, 2, 3
DRIVE_NAMES = ['FWD', 'RWD', 'AWD', 'AWD']
# share of weight usable for launch *256.  AWDX (crate car only) has
# ground-effect grip far above anything its engine can put down: no wheelspin.
DRIVE_FACTOR = [180, 225, 290, 8000]
DRIVE_K = [df * 457 >> 6 for df in DRIVE_FACTOR]   # traction per grip point *256


GEARSETS = {
    4: [2.97, 1.94, 1.34, 1.00],
    5: [3.30, 2.05, 1.45, 1.10, 0.87],
    6: [3.10, 2.10, 1.55, 1.20, 0.98, 0.80],
    7: [3.10, 2.25, 1.75, 1.40, 1.15, 0.95, 0.80],
}

# name, old body shape (unused: each car has its own sprite now, art.CAR_BODIES),
# hp, kg, redline, curve, gears, final, drive, CdA, price, gems, level
CARS = [
    ('PUKKU MINI',  0,  72,  760, 6800, 0, 4, 4.10, FWD, .60,    400,  0,  1),
    ('KOMET 1.6',   0, 125, 1020, 7800, 0, 5, 4.25, FWD, .62,   7000,  0,  1),
    ('SAKURA S2',   1, 165, 1180, 8200, 0, 5, 4.30, RWD, .60,  14000,  0,  2),
    ('VANTRA RS',   2, 210, 1360, 7200, 2, 5, 4.10, AWD, .66,  22000,  0,  3),
    ('HOLLIS SS',   3, 290, 1620, 6000, 1, 4, 3.55, RWD, .76,  26000,  0,  4),
    ('OKAMI 300',   1, 280, 1420, 7200, 0, 6, 3.90, RWD, .63,  34000,  0,  5),
    ('TORRO 4X4',   4, 330, 2150, 5600, 1, 4, 3.73, AWD, .98,  30000,  0,  5),
    ('ZEPHIR GT-X', 2, 320, 1480, 7600, 2, 6, 3.90, AWD, .65,  52000,  0,  7),
    ('BRENNAN 427', 3, 440, 1560, 6600, 1, 4, 3.40, RWD, .74,  72000,  0,  8),
    ('RAIJIN R',    1, 410, 1440, 8000, 2, 6, 3.80, AWD, .61,  98000,  0, 10),
    ('VELOCE V12',  5, 620, 1420, 8800, 2, 6, 3.60, RWD, .57, 190000,  0, 12),
    ('NOVA HYPER',  5, 950, 1520, 9200, 2, 7, 3.40, AWD, .55, 450000, 25, 15),
    # crate-only, ultra rare: 400 mph, never spins its tyres
    ('ZENITH X400', 6, 2300, 1150, 9500, 2, 7, 3.00, AWDX, .40, 600000, 0, 1),
]
NCARS = len(CARS)
NDEALER = 12                     # the dealer sells cars 0..NDEALER-1
CRATE_CAR = 12

# gear sets that differ from the default for their gear count
CUSTOM_GEARS = {12: [1.80, 1.45, 1.20, 1.00, 0.85, 0.72, 0.60]}


def car_gears(model):
    c = CARS[model]
    return CUSTOM_GEARS.get(model, GEARSETS[c[6]])

# ---------------------------------------------------------------------------
# Parts: 14 categories x 5 levels (0 = stock)
# ---------------------------------------------------------------------------
PARTS = ['INTAKE', 'EXHAUST', 'ECU TUNE', 'TURBO', 'INTERNALS',
         'NITROUS', 'GEARBOX', 'TIRES', 'SUSPENSION', 'WEIGHT RED.',
         'INTERCOOLER', 'AERO KIT', 'WHEELIE BARS', 'INJECTORS']
NPARTS = len(PARTS)
P_INTAKE, P_EXHAUST, P_ECU, P_TURBO, P_INTERNALS, P_NITROUS, P_GEARBOX, \
    P_TIRES, P_SUSP, P_WEIGHT, P_ICOOL, P_AERO, P_WHEELIE, P_INJECT = range(14)
LEVEL_NAMES = ['STOCK', 'STREET', 'SPORT', 'RACE', 'PRO']
PART_PRICE = [0, 600, 1800, 4500, 11000]           # times tier multiplier
TIER_MULT = [2, 3, 4, 6, 9, 14]                    # /2
# Price weight per part (/16), set from how much each part speeds a car up:
# the average 1/4 + 1/2 mile time gain of one level, over 8 cars at every
# level (tools/part_value.py).  The average weight is 16, so overall
# upgrade spending stays where it was; turbo and tires cost the most.
PART_WEIGHT = [9, 9, 15, 42, 12, 12, 11, 42, 12, 10, 8, 11, 12, 6]


def part_cost(part, tier, level):
    """Price of one level of a part on a car of this tier, to $50."""
    if level == 0:
        return 0
    v = PART_PRICE[level] * TIER_MULT[tier] / 2 * PART_WEIGHT[part] / 16
    return max(50, int(round(v / 50)) * 50)

HP_BONUS = {P_INTAKE: 10, P_EXHAUST: 10, P_ECU: 8, P_INTERNALS: 13,
            P_ICOOL: 5, P_INJECT: 3}                          # *256ths per level
TURBO_BOOST = [0, 72, 128, 184, 240]
TURBO_START = [0, 8, 12, 15, 18]       # curve index (of 32) where boost starts
TURBO_RATE = [0, 9, 7, 5, 4]           # spool per frame
NOS_ADD = [0, 64, 96, 136, 184]
NOS_FRAMES = [0, 150, 180, 210, 240]
SHIFT_FRAMES = [24, 18, 13, 9, 5]
TIRE_GRIP = [100, 112, 126, 142, 165]
SUSP_GRIP = 4
AERO_GRIP = 3                # downforce, per aero level
AERO_CUT = 12                # drag: CdA * (256 - AERO_CUT*level) >> 8
WEIGHT_CUT = 10
ECU_RPM = 200

# ---------------------------------------------------------------------------
# Engine tune (TUNE screen).  Stored per car as signed bytes, 0 = stock:
#   fuel[8]  fuel map, one cell per eighth of the redline: -5 rich .. +5 lean
#   timing   ignition advance, -5 .. +5 degrees
#   tirep    tire pressure, psi above/below 32 (-14 .. +8)
#   boost    psi above/below the turbo's own boost
#   launch   2-step launch rpm / 100 (0 = off; needs an ECU upgrade)
# ---------------------------------------------------------------------------
NCELLS = 8
TURBO_PSI = [0, 6, 9, 12, 16]          # each turbo's stock boost
TURBO_PSI_MAX = [0, 9, 14, 19, 25]
PSI_MIN = 3
TIRE_PSI = 32
TIREP_MIN, TIREP_MAX = -14, 8
OVERBOOST_HP = 6             # *256ths per psi over stock boost
LEAN_STEP = 3                # lean / overboost headroom per injector level
WHEELIE_GRIP = [3, 5, 3, 3]  # launch grip per level by drive: FWD (less squat keeps
                             # weight on the front), RWD, AWD


class Tune:
    def __init__(self, fuel=None, timing=0, tirep=0, boost=0, launch=0):
        self.fuel = list(fuel or [0] * NCELLS)
        self.timing, self.tirep, self.boost, self.launch = timing, tirep, boost, launch


def tune_calc(model, parts, tune):
    """What the tune does (mirrors tune_calc in src/tune.s).  Returns a dict:
    hpm (added to the power multiplier, /256), band (power factor per fuel
    cell, /256), bmul (boost scale /256 below stock boost, 0 = none), grip,
    roll, launch rpm, psi, and knock / lean bit masks per cell."""
    tl, ic, inj = parts[P_TURBO], parts[P_ICOOL], parts[P_INJECT]
    psi = ob = bmul = 0
    if tl:
        d = TURBO_PSI[tl]
        psi = max(PSI_MIN, min(TURBO_PSI_MAX[tl], d + tune.boost))
        ob = max(0, psi - d)
        if psi < d:
            bmul = psi * 256 // d
    start = TURBO_START[tl]
    ecu = parts[P_ECU]                # timing and the fuel map need an ECU
    t = tune.timing if ecu else 0
    ds, knock, lean = [], 0, 0
    for k in range(NCELLS):
        f = tune.fuel[k] if ecu else 0
        obk = ob if tl and 4 * k + 3 >= start else 0
        ln = max(0, f + obk - LEAN_STEP * inj)
        lim = 3 + ic + ((-f) >> 1 if f < 0 else 0) - (obk >> 1) - ln
        if t <= lim:
            tim = 3 * t
        else:
            tim = 3 * lim - 12 * (t - lim)
            knock |= 1 << k
        if ln:
            lean |= 1 << k
        ds.append(max(-120, tim + 2 * f - 12 * ln))
    top = max(ds)
    band = [256 + d - top for d in ds]
    band = [max(64, b) for b in band]
    c = CARS[model]
    grip = WHEELIE_GRIP[c[8]] * parts[P_WHEELIE] - 2 * tune.tirep
    roll = max(3, ROLL - tune.tirep)
    launch = tune.launch * 100 if parts[P_ECU] and tune.launch else 0
    return dict(hpm=top + OVERBOOST_HP * ob, band=band, bmul=bmul, grip=grip,
                roll=roll, launch=launch, psi=psi, knock=knock, lean=lean)


IDLE = 900
REDLINE_PAD = 200            # limiter = redline + this
ROLL = 9
KC_HALF = 24849              # K0h = T*KC_HALF/m ; kg = K0h*R >> 15
DKC = 9828                   # dk = DKC*CdA_raw / m
RPM_K = 447                  # rs = R_raw*447 >> 8  (rpm per v_raw, 8.8)
TRAC_K = 457                 # trac = grip*df*457 >> 14 ... see setup
QUARTER = 1609
HALF = 3218


def peak_torque(hp, redline, curve):
    """Peak torque (Nm) such that the curve's power peak equals hp."""
    import math
    best = 0
    for i in range(33):
        rpm = redline * i / 32
        best = max(best, CURVES[curve][i] / 255 * rpm)
    return int(round(hp * 745.7 * 60 / (2 * math.pi * best)))


def gear_raw(r):
    return int(round(r * 256))


def car_torque(i):
    c = CARS[i]
    return peak_torque(c[2], c[4], c[5])


def u16(x):
    assert 0 <= x < 65536, x
    return x


class Car:
    """Integer model of one car.  Mirrors src/physics.s."""

    def __init__(self, model, parts=None, final=None, gears=None, tune=None):
        c = CARS[model]
        parts = list(parts or [])
        parts += [0] * (NPARTS - len(parts))
        self.model = model
        tn = self.tune = tune_calc(model, parts, tune or Tune())
        self.ngears = c[6]
        final = final if final is not None else gear_raw(c[7])
        gears = gears or [gear_raw(g) for g in car_gears(model)]
        # --- engine ---------------------------------------------------------
        hpm = 256 + sum(HP_BONUS.get(p, 0) * parts[p] for p in range(NPARTS)) + tn['hpm']
        self.hpmult = hpm
        teff = car_torque(model) * hpm >> 8
        self.redline = c[4] + ECU_RPM * parts[P_ECU]
        self.limiter = self.redline + REDLINE_PAD
        m = c[3] * (256 - WEIGHT_CUT * parts[P_WEIGHT]) >> 8
        self.mass = m
        self.k0h = min(65535, teff * KC_HALF // m)
        # curve stretched over this redline: idx = rpm*32/redline
        shape = CURVES[c[5]]
        tl = parts[P_TURBO]
        boost, start = TURBO_BOOST[tl], TURBO_START[tl]
        if boost:                        # intercooler: +1/16 boost per level
            boost = min(255, boost + (boost * parts[P_ICOOL] >> 4))
            if tn['bmul']:               # turned down below the turbo's own boost
                boost = boost * tn['bmul'] >> 8
        self.curve, self.bcurve = [], []
        for b in range(48):
            rpm = b * 256 + 128
            idx = min(40, rpm * 32 // self.redline)
            v = shape[idx]
            fb = tn['band'][min(7, idx >> 2)]
            if fb != 256:                # fuel map / timing for this cell
                v = v * fb >> 8
            self.curve.append(v)
            # boost ramps in over 6 curve steps from 'start'
            if tl == 0 or idx < start:
                bc = 0
            else:
                ramp = min(6, idx - start)
                bc = (v * boost >> 8) * ramp // 6
            self.bcurve.append(bc)
        self.spool_rate = TURBO_RATE[tl]
        self.spool_start = 0
        self.nos_add = NOS_ADD[parts[P_NITROUS]]
        self.nos_frames = NOS_FRAMES[parts[P_NITROUS]]
        self.shift_frames = SHIFT_FRAMES[parts[P_GEARBOX]]
        # --- gearing --------------------------------------------------------
        self.rs, self.kg = [0], [0]
        for g in gears[:self.ngears]:
            r = g * final >> 8
            self.rs.append(u16(r * RPM_K >> 8))
            self.kg.append(u16(self.k0h * r >> 15))
        # --- grip / aero ----------------------------------------------------
        grip = (TIRE_GRIP[parts[P_TIRES]] + SUSP_GRIP * parts[P_SUSP]
                + AERO_GRIP * parts[P_AERO] + tn['grip'])
        self.roll = tn['roll']
        self.launch = tn['launch']
        self.trac = u16(grip * DRIVE_K[c[8]] >> 8)
        self.trac_k = self.trac - (self.trac >> 2) - (self.trac >> 4)
        cda = int(round(c[9] * 256)) * (256 - AERO_CUT * parts[P_AERO]) >> 8
        self.dk = u16(DKC * cda // m)
        self.reset()

    def reset(self):
        self.v = self.wv = self.pos = 0
        self.rpm = IDLE
        self.gear = 0
        self.shift_t = 0
        self.spool = 0
        self.nos_t = 0
        self.nos_on = False
        self.spin = False
        self.slip = False
        self.throttle = False
        self.limit_flip = 0

    # --- helpers -----------------------------------------------------------
    def vraw(self, v=None):
        return (self.v if v is None else v) >> 8

    def wheel_rpm(self, gear=None):
        g = self.gear if gear is None else gear
        return min(65535, (self.wv >> 8) * self.rs[g] >> 8)

    def mph(self):
        return self.vraw() * 34 >> 8

    def torque_frac(self):
        b = min(47, self.rpm >> 8)
        tq = self.curve[b] + (self.bcurve[b] * self.spool >> 8)
        if self.nos_on:
            tq += tq * self.nos_add >> 8
        return tq

    # --- controls ----------------------------------------------------------
    def shift_up(self):
        if self.gear >= self.ngears or self.shift_t:
            return False
        if self.gear == 0:
            self.gear = 1
            self.slip = self.rpm > self.wheel_rpm() + 200
            return True
        self.gear += 1
        self.shift_t = self.shift_frames
        if self.spool > 128:
            self.spool = self.spool * 3 >> 2
        return True

    def nitrous(self):
        if self.nos_frames and not self.nos_on and self.nos_t == 0:
            self.nos_on = True
            self.nos_t = self.nos_frames

    # --- one frame -----------------------------------------------------------
    def step(self):
        tq = self.torque_frac() if self.throttle else 0
        if self.nos_on:
            self.nos_t -= 1
            if self.nos_t == 0:
                self.nos_on = False
                self.nos_t = 1         # used up
        if self.rpm >= self.limiter:
            tq = 0
        drive = 0
        if self.gear == 0:
            if self.throttle and self.rpm < self.limiter:
                self.rpm += tq >> 1
                if self.launch and self.rpm > self.launch:
                    self.rpm = self.launch       # 2-step: held at the launch rpm
            elif self.rpm >= self.limiter:
                self.rpm -= 400
            else:
                self.rpm = max(IDLE, self.rpm - 120)
        elif self.shift_t:
            self.shift_t -= 1
            target = self.wheel_rpm()
            self.rpm += (target - self.rpm) >> 2
            if self.shift_t == 0:
                self.slip = self.rpm > target + 200
        else:
            kg = self.kg[self.gear]
            if self.slip:
                wr = self.wheel_rpm()
                diff = self.rpm - wr
                if diff < 200:
                    self.slip = False
                else:
                    drive = (tq + (diff >> 5)) * kg >> 8 if self.throttle else 0
                    self.rpm -= 24 if self.throttle else 80
            if not self.slip:
                drive = tq * kg >> 8
        resist = self.roll + (min(255, self.v >> 12) ** 2 * self.dk >> 16)
        if not self.throttle and self.gear:
            resist += 20
        # traction
        if not self.spin and drive > self.trac:
            self.spin = True
        if self.spin:
            acc = self.trac_k
            self.wv += (drive - self.trac_k) * 2
            if self.wv <= self.v:
                self.spin = False
        else:
            acc = drive
        self.v = max(0, self.v + acc - resist)
        if not self.spin:
            self.wv = self.v
        self.pos += self.v >> 8
        if self.gear and not self.shift_t and not self.slip:
            self.rpm = max(IDLE, self.wheel_rpm())
        # turbo
        if self.spool_rate and self.throttle and self.bcurve[min(47, self.rpm >> 8)]:
            self.spool = min(255, self.spool + self.spool_rate)
        else:
            self.spool = max(0, self.spool - 8)

    # --- AI helpers ---------------------------------------------------------
    def best_launch(self):
        """Launch rpm the AI aims for: most kick that doesn't spin the tyres."""
        target = self.trac * 256 // self.kg[1]
        best = 2000
        for rpm in range(1500, self.redline, 128):
            b = min(47, rpm >> 8)
            if self.curve[b] + (rpm >> 5) <= target + target // 16:
                best = rpm
        return best

    def shift_rpm(self):
        return self.redline - 250


def run(car, dist=QUARTER, launch=None, shift=None, nos_gear=2, verbose=False):
    """Drag run with a perfect driver.  Returns (et_s, trap_mph, t60)."""
    car.reset()
    launch = launch or car.best_launch()
    shift = shift or car.shift_rpm()
    car.throttle = True
    for _ in range(240):                 # rev up
        if car.rpm < launch:
            car.throttle = True
        else:
            car.throttle = False
        car.step()
    car.throttle = True
    car.shift_up()
    t = 0
    t60 = None
    while car.pos >> 8 < dist and t < 60 * 60:
        if car.gear < car.ngears and car.rpm >= shift and not car.shift_t and not car.slip:
            car.shift_up()
        if car.gear >= nos_gear:
            car.nitrous()
        car.step()
        t += 1
        if t60 is None and car.mph() >= 60:
            t60 = t / 60
        if verbose and t % 30 == 0:
            print(t, car.gear, car.rpm, car.mph(), car.pos >> 8, car.spin, car.slip)
    return t / 60, car.mph(), t60


if __name__ == '__main__':
    for i, c in enumerate(CARS):
        car = Car(i)
        et, trap, t60 = run(car)
        full = Car(i, [4] * 10)
        et2, trap2, t602 = run(full)
        print('%-12s T=%3d trac=%3d L=%4d  stock %5.2fs %3dmph 0-60 %.2f | maxed %5.2fs %3dmph 0-60 %.2f k0h=%d'
              % (c[0], car_torque(i), car.trac, car.best_launch(), et, trap, t60 or 0,
                 et2, trap2, t602 or 0, full.k0h))
