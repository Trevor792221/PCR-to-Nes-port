#!/usr/bin/env python3
"""The level a typical player reaches by the time their car can beat each
region's bosses: that sets region_lv (src/ui.s), the level that opens the
next region.

The player races in the region whose bosses they're after, taking whichever
pays more on average: easy quick races (winning 90%) or street races
(winning half).  After every race they check whether they can afford a car
fast enough: any dealer car their level allows (selling the old one) plus
the cheapest parts that get its 1/4 mile time under the region's fastest
boss (both driven perfectly, tools/gamedata.py).  Then they beat the
region's bosses and move on.  Boss tables as in src/menus.s.

    python3 tools/progress.py
"""
import os
import sys
from functools import lru_cache

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gamedata as gd           # noqa: E402
from mkdata import TIERS        # noqa: E402

BOSS_MODEL = [0, 1, 2, 4, 3, 5, 6, 7, 11, 9, 11]
BOSS_LEVEL = [0, 1, 1, 1, 2, 2, 3, 3, 3, 4, 4]
BOSS_HOME = [0, 0, 1, 1, 2, 2, 3, 4, 5, 6, 6]
BOSS_CASH = [800, 1500, 2500, 4000, 6000, 9000, 12000, 18000, 26000, 40000, 100000]
P_QUICK, P_STREET = 0.9, 0.5


@lru_cache(None)
def et(model, parts):
    return gd.run(gd.Car(model, list(parts)))[0]


@lru_cache(None)
def build(model, target):
    """Cheapest greedy part set that gets model under target: (cost, parts) or None."""
    parts, cost = [0] * gd.NPARTS, 0
    while et(model, tuple(parts)) > target:
        cur, best = et(model, tuple(parts)), None
        for p in range(gd.NPARTS):
            if parts[p] < 4:
                q = list(parts)
                q[p] += 1
                c = gd.part_cost(p, TIERS[model], q[p])
                g = cur - et(model, tuple(q))
                if g > 0 and (not best or g / c > best[0]):
                    best = (g / c, c, q)
        if not best:
            return None
        cost += best[1]
        parts = best[2]
    return cost, tuple(parts)


def value(model, parts):              # what selling the car brings
    return gd.CARS[model][10] // 2 + sum(gd.part_cost(p, TIERS[model], l)
                                         for p in range(gd.NPARTS) for l in range(1, parts[p] + 1)) // 2


def plan(st, target):
    """Cheapest way to a car under target the player's level allows: (cash needed, model)."""
    best = None
    for m in range(gd.NDEALER):
        c = gd.CARS[m]
        if c[11] or c[12] > st['level']:
            continue
        if m == st['model']:
            b = build(m, target)
            if not b:
                continue
            # parts already fitted count as paid: the greedy build from stock,
            # less what's already in (approximate)
            have = value(m, st['parts']) * 2 - c[10]
            need = max(0, b[0] - have)
        else:
            b = build(m, target)
            if not b:
                continue
            need = c[10] + b[0] - value(st['model'], st['parts'])
        if not best or need < best[0]:
            best = (need, m, b[1])
    return best


def xp_needed(level):
    return 100 + 40 * level


def add_xp(st, xp):
    st['xp'] += xp
    while st['xp'] >= xp_needed(st['level']):
        st['xp'] -= xp_needed(st['level'])
        st['level'] += 1


def race(st, region):
    tier = TIERS[st['model']]
    quick = 300 * (2 + region) / 2
    street = (1200 + 600 * tier) * (2 + region) / 2
    eq = P_QUICK * quick - (1 - P_QUICK) * quick
    es = P_STREET * street
    if eq >= es:
        st['cash'] += eq
        add_xp(st, P_QUICK * (100 + 10 * region) + (1 - P_QUICK) * 25)
    else:
        st['cash'] += es
        add_xp(st, P_STREET * (120 + 10 * region) + (1 - P_STREET) * 25)
    st['races'] += 1


def main():
    st = dict(model=0, parts=(0,) * gd.NPARTS, cash=3000, xp=0, level=1, races=0)
    levels = []
    for region in range(7):
        bosses = [b for b in range(11) if BOSS_HOME[b] == region]
        target = min(et(BOSS_MODEL[b], (BOSS_LEVEL[b],) * gd.NPARTS) for b in bosses)
        start = st['races']
        while True:
            p = plan(st, target)
            if p and p[0] <= st['cash']:
                break
            race(st, region)
        need, m, parts = p
        st['cash'] -= need
        st['model'], st['parts'] = m, parts
        levels.append(st['level'])
        print('region %d (%s): beats its bosses at level %2d, %3d races here, %4d in all: %s %s'
              % (region, gd.CARS[st['model']][0][:11], st['level'], st['races'] - start, st['races'],
                 gd.CARS[m][0], parts))
        for b in bosses:
            st['cash'] += BOSS_CASH[b]
            add_xp(st, 150 + 10 * region)
            st['races'] += 1
    print('next-region levels:', [1] + levels[:-1])


if __name__ == '__main__':
    main()
