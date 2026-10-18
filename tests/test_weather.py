"""Weather: cloudy, rain and snow, picked per race by region."""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'tools'))
import gamedata as gd          # noqa: E402
from harness import *          # noqa: E402,F401,F403
from test_game import new_game, start_race   # noqa: E402

SV_LEVEL = 0x600B
FUKUOKA, SAPPORO = 0, 5


def race_in(weather=None, region=FUKUOKA, wait=0):
    s = new_game()
    s.nes[SV_LEVEL] = 40                         # every region open
    s.nes[s.sym['map_region']] = region
    if weather is not None:
        s.nes[s.sym['weather_force']] = weather + 1
    s.step(wait)
    start_race(s, 4)                             # test run
    s.step(20)
    return s


class Weather(unittest.TestCase):
    def test_odds(self):
        for odds in gd.WEATHER_ODDS:
            self.assertEqual(len(odds), 16)
        for region, odds in enumerate(gd.WEATHER_ODDS):
            self.assertEqual(gd.SNOW in odds, region in (4, 5), 'snow only in Gunma and Sapporo')
            if region != SAPPORO:                    # Sapporo: snow more often than not
                self.assertEqual(max(range(4), key=odds.count), gd.CLEAR, 'clear the most common')
        self.assertGreater(gd.WEATHER_ODDS[SAPPORO].count(gd.SNOW), 4)

    def test_weather_by_region(self):
        seen = {FUKUOKA: set(), SAPPORO: set()}
        for i in range(14):
            for region in seen:
                s = race_in(region=region, wait=i * 7)
                w = s.mem('race_weather')
                seen[region].add(w)
                self.assertEqual(s.mem('race_scene'), s.mem('race_theme') + (3 if w else 0))
        self.assertNotIn(gd.SNOW, seen[FUKUOKA])
        self.assertIn(gd.SNOW, seen[SAPPORO])
        self.assertGreater(len(seen[FUKUOKA] | seen[SAPPORO]), 2)

    def test_rain_and_snow_cost_grip(self):
        trac = {}
        for w in (gd.CLEAR, gd.CLOUDY, gd.RAIN, gd.SNOW):
            s = race_in(w)
            self.assertEqual(s.mem('race_weather'), w)
            trac[w] = s.mem('ph_trac_l') | s.mem('ph_trac_h') << 8
            self.assertEqual(trac[w], gd.Car(0, weather=w).trac)
        self.assertEqual(trac[gd.CLOUDY], trac[gd.CLEAR])
        self.assertLess(trac[gd.SNOW], trac[gd.RAIN])
        self.assertLess(trac[gd.RAIN], trac[gd.CLEAR])

    def test_rain_falls_and_stops_after_the_race(self):
        for w, moving in ((gd.CLEAR, False), (gd.RAIN, True), (gd.SNOW, True)):
            s = race_in(w)
            road = lambda: s.frame[150:200, 20:120].copy()   # still on the line
            a = road()
            s.step(4)
            self.assertEqual(bool((road() != a).any()), moving, gd.WEATHER_NAMES[w])
            self.assertEqual(s.mem('lag'), 0)
        drive_race(s)
        s.step(120)
        self.assertEqual(s.mem('race_weather'), 0, 'clear again outside races')


if __name__ == '__main__':
    unittest.main()
