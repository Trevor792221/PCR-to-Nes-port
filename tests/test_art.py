"""Car and traffic sprites have no see-through pixels inside their bodies
(only the frames drawn to be open: roof racks, the gap under a wing)."""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'tools'))
import art          # noqa: E402

OPEN = {3: 'roof rack', 7: 'under the wing', 'LADDER': 'ladder rack'}
OPEN_ROWS = {3: {2}, 7: {6}, 'LADDER': {2, 3, 4}}


def holes(name):
    """Transparent pixels that can't be reached from the sprite's edge."""
    found = set()
    for frame in (0, 1):
        g = art.car_pixels(name, frame)
        H, W = len(g), len(g[0])
        seen, stack = set(), [(x, y) for x in range(W) for y in (0, H - 1)] + \
            [(x, y) for y in range(H) for x in (0, W - 1)]
        while stack:
            x, y = stack.pop()
            if not (0 <= x < W and 0 <= y < H) or (x, y) in seen or g[y][x] != '.':
                continue
            seen.add((x, y))
            stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
        found |= {(x, y) for y in range(H) for x in range(W) if g[y][x] == '.' and (x, y) not in seen}
    return found


class Art(unittest.TestCase):
    def test_bodies_are_solid(self):
        for name in list(range(art.NCAR_SHAPES)) + art.TRAFFIC_ORDER:
            h = {(x, y) for x, y in holes(name) if y not in OPEN_ROWS.get(name, ())}
            self.assertEqual(h, set(), 'see-through pixels in %r' % (name,))


if __name__ == '__main__':
    unittest.main()
