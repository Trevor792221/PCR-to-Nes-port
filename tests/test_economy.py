"""No car can be bought and sold back for a profit."""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), 'tools'))
import gamedata as gd


class Economy(unittest.TestCase):
    def test_every_car_costs_more_than_it_sells_for(self):
        for c in gd.CARS:
            price = c[10]
            sell = max(200, price // 2)      # stock car: see sell_value in src/menus.s
            self.assertGreater(price, sell, c[0])

    def test_parts_sell_for_less_than_they_cost(self):
        # each part level adds $400 to the sell price; the cheapest level costs more
        cheapest = min(gd.PART_PRICE[1] * m // 2 for m in gd.TIER_MULT)
        self.assertGreater(cheapest, 400)


if __name__ == '__main__':
    unittest.main()
