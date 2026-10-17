#!/usr/bin/env python3
"""How much each part speeds a car up, and the price weights that follow.

For 8 cars and every level L, every part starts at L-1 and one part is
raised to L.  The gain is the average of the 1/4 and 1/2 mile time cuts (%).
Price weights (/16, average 16) are proportional to each part's mean gain:
these are PART_WEIGHT in gamedata.py.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gamedata as gd

CARS = [1, 2, 3, 5, 7, 9, 10, 11]


def gains():
    tot = [[0.0] * 5 for _ in range(gd.NPARTS)]
    for m in CARS:
        for lv in range(1, 5):
            base = [lv - 1] * gd.NPARTS
            bq = gd.run(gd.Car(m, base), dist=gd.QUARTER)[0]
            bh = gd.run(gd.Car(m, base), dist=gd.HALF)[0]
            for p in range(gd.NPARTS):
                parts = list(base)
                parts[p] = lv
                q = gd.run(gd.Car(m, parts), dist=gd.QUARTER)[0]
                h = gd.run(gd.Car(m, parts), dist=gd.HALF)[0]
                tot[p][lv] += ((bq - q) / bq + (bh - h) / bh) / 2 * 100 / len(CARS)
    return [sum(t[1:]) / 4 for t in tot]


if __name__ == '__main__':
    g = gains()
    mean = sum(g) / len(g)
    for p, v in enumerate(g):
        print('%-12s %5.2f%%  weight %2d  (now %d)' % (gd.PARTS[p], v, round(v / mean * 16),
                                                     gd.PART_WEIGHT[p]))
