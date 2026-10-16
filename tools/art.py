"""Original pixel art for Pixel Racer NES.

Car sprites are 32x16, facing right.
  '.' transparent   'k' outline/tyres (colour 1)
  'p' paint (colour 2)   'w' glass on the top half, rims/lights on the bottom
Wheels are stamped on afterwards at the x positions given with each body.
"""

WHEEL = [
    ['..kkk..',
     '.kwkwk.',
     'kwkkkwk',
     'kkkwkkk',
     'kwkkkwk',
     '.kwkwk.',
     '..kkk..'],
    ['..kkk..',
     '.kkwkk.',
     'kkkwkkk',
     'kwwkwwk',
     'kkkwkkk',
     '.kkwkk.',
     '..kkk..'],
]

BODIES = {
    'HATCH': ([
        '................................',
        '................................',
        '...........kkkkkkkkkk...........',
        '.........kkppppppppppkk.........',
        '........kpkwwwwwkwwwwwkk........',
        '.......kppkwwwwwkwwwwwwwk.......',
        '......kpppkwwwwwkwwwwwwwwk......',
        '.....kppppkkkkkkkkkkkkkkkpkkk...',
        '...kkppppppppppkpppppppppppppkk.',
        '..kwppppppppppkpppppppppppppppwk',
        '..kpppp.......kppppp.......pppk.',
        '..kppp.........kpppp........ppk.',
        '..kkkk..........kkkk........kkk.',
        '................................',
        '................................',
        '................................',
    ], [8, 24]),
    'COUPE': ([
        '................................',
        '................................',
        '................................',
        '...........kkkkkkkkk............',
        '.........kkpwwwwkwwwwkk.........',
        '........kppkwwwwkwwwwwwkk.......',
        '......kkpppkwwwwkwwwwwwwwkk.....',
        '...kkkppppkkkkkkkkkkkkkkkkppkk..',
        '..kpppppppppppppkppppppppppppppk',
        '.kwppppppppppppkpppppppppppppwwk',
        '.kpppp.......pkppppp.......ppppk',
        '.kppp.........kpppp.........pppk',
        '.kkkk..........kkkk..........kk.',
        '................................',
        '................................',
        '................................',
    ], [8, 25]),
    'SEDAN': ([
        '................................',
        '................................',
        '...........kkkkkkkkkk...........',
        '.........kkpwwwwkwwwwkk.........',
        '........kppkwwwwkwwwwwkk........',
        '.......kpppkwwwwkwwwwwwwk.......',
        '...kkkkppppkwwwwkwwwwwwwwkk.....',
        '..kppppppppkkkkkkkkkkkkkkkppkkk.',
        '.kpppppppppppppkpppppppppppppppk',
        '.kwpppppppppppkppppppppppppppwwk',
        '.kpppp.......kpppppp.......ppppk',
        '.kppp.........kppppp........pppk',
        '.kkkk..........kkkkk........kkk.',
        '................................',
        '................................',
        '................................',
    ], [8, 24]),
    'MUSCLE': ([
        '................................',
        '................................',
        '................................',
        '..........kkkkkkkkk.............',
        '........kkpwwwwkwwwwk...........',
        '.......kppkwwwwkwwwwwk....kkk...',
        '..kkkkkpppkwwwwkwwwwwwkkkkpppk..',
        '.kpppppppkkkkkkkkkkkkkkpppppppk.',
        '.kpppppppppppppkpppppppppppppppk',
        '.kwppppppppppppkpppppppppppppwwk',
        '.kpppp.......pkpppppp.......pppk',
        '.kppp.........kppppp.........ppk',
        '.kkkk..........kkkkk.........kk.',
        '................................',
        '................................',
        '................................',
    ], [8, 25]),
    'TRUCK': ([
        '................................',
        '..................kkkkkkkk......',
        '.................kpwwwwwwwkk....',
        '................kppwwwwwwwwwk...',
        '...............kpppwwwwwwwwwwk..',
        '..kkkkkkkkkkkkkkppppkkkkkkkkkkk.',
        '..kppppppppppppkppppppppppppppk.',
        '..kpkkkkkkkkkkpkpppppppppppppppk',
        '.kkpppppppppppppkpppppppppppppwk',
        '.kwppppppppppppppkpppppppppppppk',
        '.kppp.........ppppkpp.........pk',
        '.kpp...........pppkp...........k',
        '.kkk............kkkk.........kk.',
        '................................',
        '................................',
        '................................',
    ], [8, 25]),
    'SUPER': ([
        '................................',
        '................................',
        '................................',
        '................................',
        '...........kkkkkkkk.............',
        '.........kkpwwwwwwwkk...........',
        '...kkk..kppkwwwwwwwwwkkk........',
        '..kpppkkpppkkkkkkkkkkkkpkkkk....',
        '.kppppppppppppppkpppppppppppkkk.',
        '.kwpppppppppppppkpppppppppppppwk',
        '.kpppp.......ppkppppppp......ppk',
        '.kppp.........kpppppp.........pk',
        '..kkk..........kkkkkk........kk.',
        '................................',
        '................................',
        '................................',
    ], [8, 24]),
}

SHAPE_ORDER = ['HATCH', 'COUPE', 'SEDAN', 'MUSCLE', 'TRUCK', 'SUPER']


def car_pixels(name, frame=0):
    rows, wheels = BODIES[name]
    assert len(rows) == 16, name
    grid = [list(r) for r in rows]
    for r in rows:
        assert len(r) == 32, (name, r, len(r))
    for cx in wheels:
        for dy, line in enumerate(WHEEL[frame]):
            for dx, ch in enumerate(line):
                if ch != '.':
                    grid[9 + dy][cx - 3 + dx] = ch
    return [''.join(r) for r in grid]
