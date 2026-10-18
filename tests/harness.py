"""Drive Pixel Racer NES in the cynes emulator."""
import os
import re
from cynes import NES, NES_INPUT_A, NES_INPUT_B, NES_INPUT_START, NES_INPUT_SELECT
from cynes import NES_INPUT_UP, NES_INPUT_DOWN, NES_INPUT_LEFT, NES_INPUT_RIGHT

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROM = os.path.join(ROOT, 'build', 'pxracer.nes')
LBL = os.path.join(ROOT, 'build', 'pxracer.lbl')

A, B, START, SELECT = NES_INPUT_A, NES_INPUT_B, NES_INPUT_START, NES_INPUT_SELECT
UP, DOWN, LEFT, RIGHT = NES_INPUT_UP, NES_INPUT_DOWN, NES_INPUT_LEFT, NES_INPUT_RIGHT


def labels():
    out = {}
    with open(LBL) as f:
        lines = f.readlines()
    for line in lines:
        m = re.match(r'al ([0-9A-F]+) \.(\S+)', line)
        if m:
            out[m.group(2)] = int(m.group(1), 16)
    return out


class Sim:
    def __init__(self, rom=ROM, boot=60, skip_splash=True):
        self.nes = NES(rom)
        self.sym = labels()
        self.frame = None
        self.step(boot)
        if skip_splash and self.mem('game_mode') == 4:
            self.press(START)
            for _ in range(200):
                if self.mem('game_mode') == 0:
                    break
                self.step(1)
            self.step(60)

    def step(self, n=1, hold=0):
        self.nes.controller = hold
        for _ in range(n):
            self.frame = self.nes.step()
        assert not self.nes.has_crashed, 'CPU crashed'

    def press(self, buttons, hold=2, release=4):
        self.step(hold, buttons)
        self.step(release, 0)

    def mem(self, name, off=0):
        return self.nes[self.sym[name] + off]

    def mem16(self, name, off=0):
        return self.mem(name, off) | self.mem(name, off + 1) << 8

    def wram(self, addr, size=1):
        v = 0
        for i in range(size):
            v |= self.nes[addr + i] << (8 * i)
        return v

    def garage_goto(self, item):
        """Move the garage cursor (3 columns) to item."""
        for _ in range(20):
            cur = self.mem('g_sel')
            if cur == item:
                return
            cr, cc = divmod(cur, 3)
            tr, tc = divmod(item, 3)
            if cr < tr:
                self.press(DOWN)
            elif cr > tr:
                self.press(UP)
            else:
                self.press(RIGHT)
        raise AssertionError('cursor stuck')

    def list_goto(self, var, item, limit=20):
        for _ in range(limit):
            if self.mem(var) == item:
                return
            self.press(DOWN)
        raise AssertionError('list cursor stuck')

    def save_png(self, path):
        from PIL import Image
        Image.fromarray(self.frame).resize((512, 480), Image.NEAREST).save(path)


def rpm(s, car=0):
    return s.mem('ph_rpm_l', car) | s.mem('ph_rpm_h', car) << 8


def redline(s, car=0):
    return s.mem('ph_redl_l', car) | s.mem('ph_redl_h', car) << 8


def drive_race(s, launch=4500, shift_margin=300, max_frames=4000, nitrous_gear=2, lanes=False):
    """Play a race: rev to `launch` during the tree, go on green, shift
    near the redline.  Returns when the results screen is up."""
    frames = 0
    while s.mem('game_mode') == 2 and frames < max_frames:
        state = s.mem('rc_state')
        btn = 0
        if state == 0:
            btn = A if rpm(s) < launch else 0
        elif state == 1:
            btn = A
            g = s.mem('ph_gear')
            if g == 0:
                btn |= RIGHT if frames % 4 < 2 else 0
            elif (rpm(s) >= redline(s) - shift_margin and s.mem('ph_shift_t') == 0
                  and s.mem('ph_slip') == 0 and frames % 4 < 2):
                btn |= RIGHT
            if g >= nitrous_gear and frames % 4 < 2:
                btn |= B
        s.step(1, btn)
        frames += 1
    return frames
