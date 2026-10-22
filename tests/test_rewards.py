"""Race rewards (apply_rewards, bank 1) on py65."""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from cpu import CPU             # noqa: E402

RK_QUICK, RF_WIN = 1, 1
SV_LEVEL = 0x600B


def rewards(won, diff, region):
    c = CPU(bank=1)
    c.mem[SV_LEVEL] = 1
    c.put('race_kind', RK_QUICK)
    c.put('res_flags', RF_WIN if won else 0)
    c.put('race_diff', diff)
    c.put('map_region', region)
    c.put('race_bet', 300, size=3)
    c.mem[0x6004:0x6007] = (5000).to_bytes(3, 'little')
    c.call('apply_rewards')
    return c.get('rw_xp', size=2)


class Rewards(unittest.TestCase):
    def test_harder_quick_races_pay_more_xp(self):
        for region in range(7):
            easy, medium, hard = (rewards(True, d, region) for d in range(3))
            self.assertEqual((easy, medium, hard),
                             (100 + 10 * region, 150 + 10 * region, 200 + 10 * region))
            for d in range(3):
                self.assertEqual(rewards(False, d, region), 25, 'a loss is 25 at any difficulty')


if __name__ == '__main__':
    unittest.main()
