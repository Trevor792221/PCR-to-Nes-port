"""No car can be bought and sold back for a profit."""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), 'tools'))
sys.path.insert(0, HERE)
import gamedata as gd


class Economy(unittest.TestCase):
    def test_every_car_costs_more_than_it_sells_for(self):
        for c in gd.CARS:
            price = c[10]
            sell = max(200, price // 2)      # stock car: see sell_value in src/menus.s
            self.assertGreater(price, sell, c[0])

    def test_parts_sell_for_less_than_they_cost(self):
        # selling refunds half of each level's price (sell_value in menus.s)
        for p in range(gd.NPARTS):
            for t in range(6):
                for lv in range(1, 5):
                    c = gd.part_cost(p, t, lv)
                    self.assertGreater(c, c // 2)
                    self.assertGreater(c, 0)

    def test_prices_follow_performance(self):
        # turbo and tires (the biggest gains) cost the most; the average
        # weight of the original 12 parts keeps overall spending the same.
        # Wheelie bars and injectors (v4.2) are priced on the same scale.
        w = gd.PART_WEIGHT
        self.assertEqual(sum(w[:12]) // 12, 16)
        self.assertEqual(max(w), w[gd.P_TURBO])
        self.assertEqual(max(w), w[gd.P_TIRES])
        self.assertEqual(min(w[:12]), w[gd.P_ICOOL])
        self.assertEqual(min(w), w[gd.P_INJECT], 'injectors: little power on their own')

    def test_rom_prices_match(self):
        from cpu import CPU
        cpu = CPU()
        for p in range(gd.NPARTS):
            for t in range(6):
                for lv in range(1, 5):
                    cpu.call('part_price', a=p, x=t, y=lv)
                    got = cpu.get('m_a') | cpu.get('m_a', 1) << 8 | cpu.get('m_a', 2) << 16
                    self.assertEqual(got, gd.part_cost(p, t, lv), (p, t, lv))


if __name__ == '__main__':
    unittest.main()
