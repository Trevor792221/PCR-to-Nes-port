"""Original pixel art for Pixel Racer NES.

Car sprites are 32x16, facing right; menu cars are 64x32.
  '.' transparent   'k' outline/tyres (colour 1)
  'p' paint (colour 2)   'w' glass on the top half, rims/lights on the
  bottom half (rows 8-15 use the rim palette)

Each body is drawn as fill only: paint, glass and interior detail lines
(door seams, pillars, grille) in 'k'.  car_pixels() then
  1. cuts round wheel arches around the wheel centres,
  2. outlines the whole silhouette in 'k',
  3. draws round, spoked wheels (two frames, for rolling).
big_car_pixels() scales the fill art 2x with an edge-smoothing pixel-art
scaler (EPX) before the same steps, with larger hand-tuned wheels, so the
garage and dealer cars get smooth curves instead of fat pixels.
"""

# Fill art: rows 0-12 (wheels sit on rows 9-15).  Front of the car is on the
# right.  Taillights are 'w' at the rear (left), headlights 'w' at the front.
BODIES = {
    # small city hatchback: tall glasshouse, stubby nose
    'HATCH': ([
        '................................',
        '................................',
        '................................',
        '...........pppppppppppp.........',
        '.........ppwwwwwwkwwwwwpp.......',
        '........pwwwwwwwwkwwwwwwwp......',
        '.......ppwwwwwwwwkwwwwwwwwp.....',
        '.......ppppppppppkppppppppppp...',
        '.......ppppppppppkpppppppppppp..',
        '......wppppppppppkppppppppppppw.',
        '......pppppppppppkppppppppppppk.',
        '.......ppppppppppppppppppppppp..',
        '................................',
    ], [9, 25]),
    # two-door coupe: long hood, fastback roof, small lip spoiler
    'COUPE': ([
        '................................',
        '................................',
        '................................',
        '.............ppppppppp..........',
        '...........ppwwwwkwwwwpp........',
        '.........ppwwwwwwkwwwwwwpp......',
        '..pp...ppppwwwwwwkwwwwwwwwpp....',
        '..pppppppppppppppkpppppppppppp..',
        '..pppppppppppppppkpppppppppppppp',
        '..wppppppppppppppkppppppppppppww',
        '..pppppppppppppppkpppppppppppppk',
        '...pppppppppppppppppppppppppppp.',
        '................................',
    ], [8, 25]),
    # four-door sedan: three-box shape, two windows, trunk
    'SEDAN': ([
        '................................',
        '................................',
        '................................',
        '............pppppppppppp........',
        '..........ppwwwwkwwwwwwkpp......',
        '.........pwwwwwwkwwwwwwwkwp.....',
        '...pppppppwwwwwwkwwwwwwwwkpppp..',
        '..ppppppppppppppkpppppppppppppp.',
        '..ppppppppppppppkppppppkppppppp.',
        '..wpppppppppppppkppppppkpppppppw',
        '..ppppppppppppppkppppppkppppppkk',
        '...pppppppppppppppppppppppppppp.',
        '................................',
    ], [8, 25]),
    # muscle car: long hood with a scoop, short deck, chunky haunches
    'MUSCLE': ([
        '................................',
        '................................',
        '................................',
        '............pppppppp............',
        '..........ppwwwwkwwwpp...pp.....',
        '.........pwwwwwwkwwwwwpppppp....',
        '..pppppppwwwwwwwkwwwwwwpppppppp.',
        '..ppppppppppppppkpppppppppppppp.',
        '..ppppppppppppppkppppppppppppppp',
        '..wpppppppppppppkpppppppppppppww',
        '..ppppppppppppppkppppppppppppkkp',
        '...ppppppppppppppppppppppppppppp',
        '................................',
    ], [8, 25]),
    # pickup: cab up front, open bed behind
    'TRUCK': ([
        '................................',
        '................................',
        '..................ppppppppp.....',
        '.................pwwwwwkwwwp....',
        '................pwwwwwwkwwwwp...',
        '................pwwwwwwkwwwwwp..',
        '..pppppppppppppppppppppkpppppppp',
        '..pkkkkkkkkkkkkkpppppppkpppppppp',
        '..pppppppppppppppppppppkpppppppw',
        '..wppppppppppppppppppppkpppppppp',
        '..pppppppppppppppppppppkppppppkk',
        '..ppppppppppppppppppppppppppppp.',
        '................................',
    ], [8, 25]),
    # mid-engine supercar: low wedge, glass canopy, side intake, wing
    'SUPER': ([
        '................................',
        '................................',
        '................................',
        '................................',
        '..pppp.......pppppppppp.........',
        '...pp......ppwwwwwwwwwwpp.......',
        '..pppppppppwwwwwwwwwwwwwwppp....',
        '..ppppppppppppppppppppppppppppp.',
        '..pppppppkkkkpppppppppppppppppp.',
        '..wppppppkkkppppppppppppppppppww',
        '..ppppppppppppppppppppppppppppkk',
        '...ppppppppppppppppppppppppppp..',
        '................................',
    ], [8, 24]),
    # prototype racer: low, long nose, tall rear wing, bubble cockpit
    'PROTO': ([
        '................................',
        '................................',
        '................................',
        '.pppppp.........................',
        '.pppppp.........................',
        '...pp.........ppppppp...........',
        '...pp.......ppwwwwwwwpp.........',
        '..pppppppppppwwwwwwwwwwppppp....',
        '..ppppppppppppppppppppppppppppp.',
        '..wpppppppppppppppppppppppppppww',
        '..ppppppppppppppppppppppppppppkk',
        '...ppppppppppppppppppppppppppp..',
        '................................',
    ], [8, 25]),
}

SHAPE_ORDER = ['HATCH', 'COUPE', 'SEDAN', 'MUSCLE', 'TRUCK', 'SUPER', 'PROTO']

WHEEL_Y = 12            # wheel centre row (small sprite)
WHEEL_R = 3.6           # tyre radius
ARCH_R = 4.4            # arch cut radius


def _wheel(grid, cx, cy, r, frame, rim_r, hub_r, spokes):
    """Draw a round tyre + rim with `spokes` spokes, rotated by frame."""
    import math
    h, w = len(grid), len(grid[0])
    rot = (math.pi / spokes) * frame
    for y in range(h):
        for x in range(w):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            if d > r:
                continue
            if d > rim_r or d < hub_r:
                grid[y][x] = 'k'
                continue
            a = (math.atan2(dy, dx) - rot) % (2 * math.pi / spokes)
            width = 2 * math.pi / spokes
            # a spoke covers the middle of each sector
            grid[y][x] = 'w' if abs(a - width / 2) < width * 0.28 else 'k'


def _carve_and_outline(grid, centres, cy, arch_r):
    import math
    h, w = len(grid), len(grid[0])
    for cx in centres:
        for y in range(h):
            for x in range(w):
                if math.hypot(x + 0.5 - cx, y + 0.5 - cy) <= arch_r and y >= cy - arch_r:
                    grid[y][x] = '.'
    out = [row[:] for row in grid]
    for y in range(h):
        for x in range(w):
            if grid[y][x] != '.':
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and grid[ny][nx] in 'pw':
                    out[y][x] = 'k'
                    break
    return out


def _rows(name):
    rows, wheels = BODIES[name]
    rows = list(rows) + ['.' * 32] * (16 - len(rows))
    for r in rows:
        assert len(r) == 32, (name, r, len(r))
    return rows, wheels


def car_pixels(name, frame=0):
    """32x16 sprite.  frame 0/1 turns the wheels."""
    rows, wheels = _rows(name)
    grid = [list(r) for r in rows]
    centres = [cx + 0.5 for cx in wheels]
    grid = _carve_and_outline(grid, centres, WHEEL_Y + 0.5, ARCH_R)
    for cx in centres:
        _wheel(grid, cx, WHEEL_Y + 0.5, WHEEL_R, frame, 2.6, 0.9, 4)
    return [''.join(r) for r in grid]


def _epx(rows):
    """Scale 2x with EPX (Scale2x): keeps hard pixel edges, smooths diagonals."""
    h, w = len(rows), len(rows[0])
    get = lambda x, y: rows[y][x] if 0 <= x < w and 0 <= y < h else '.'
    out = [[''] * (w * 2) for _ in range(h * 2)]
    for y in range(h):
        for x in range(w):
            p = get(x, y)
            a, b, c, d = get(x, y - 1), get(x + 1, y), get(x - 1, y), get(x, y + 1)
            e1 = e2 = e3 = e4 = p
            if c == a and c != d and a != b:
                e1 = a
            if a == b and a != c and b != d:
                e2 = b
            if d == c and d != b and c != a:
                e3 = c
            if b == d and b != a and d != c:
                e4 = d
            out[2 * y][2 * x], out[2 * y][2 * x + 1] = e1, e2
            out[2 * y + 1][2 * x], out[2 * y + 1][2 * x + 1] = e3, e4
    return out


def big_car_pixels(name):
    """64x32 menu car: EPX-scaled body, outlined, with large spoked wheels."""
    rows, wheels = _rows(name)
    grid = _epx(rows)
    centres = [cx * 2 + 1 for cx in wheels]
    cy = (WHEEL_Y + 0.5) * 2
    grid = _carve_and_outline(grid, centres, cy, ARCH_R * 2)
    for cx in centres:
        _wheel(grid, cx, cy, WHEEL_R * 2, 0, 5.4, 1.6, 5)
    return [''.join(r) for r in grid]
