"""Family keyboard on the password screen: kb_scan on py65 with a keyboard
modelled on the expansion port ($4016 writes, $4017 reads)."""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from cpu import CPU, Memory          # noqa: E402

# [row][column][bit 1-4 of $4017], as Mesen and FCEUX have it
MATRIX = [
    [['F8', 'RETURN', '[', ']'], ['KANA', 'RSHIFT', 'YEN', 'STOP']],
    [['F7', '@', ':', ';'], ['_', '/', '-', '^']],
    [['F6', 'O', 'L', 'K'], ['.', ',', 'P', '0']],
    [['F5', 'I', 'U', 'J'], ['M', 'N', '9', '8']],
    [['F4', 'Y', 'G', 'H'], ['B', 'V', '7', '6']],
    [['F3', 'T', 'R', 'D'], ['F', 'C', '5', '4']],
    [['F2', 'W', 'S', 'A'], ['X', 'Z', 'E', '3']],
    [['F1', 'ESC', 'Q', 'CTR'], ['LSHIFT', 'GRPH', '1', '2']],
    [['CLR', 'UP', 'RIGHT', 'LEFT'], ['DOWN', 'SPACE', 'DEL', 'INS']],
]
ALPHA = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
KB_DEL, KB_RET, KB_BAD, KB_NONE = 0x40, 0x41, 0x42, 0xFF


class Port(Memory):
    """The expansion port: a keyboard (keys held in .down), nothing at all,
    or a device that only drives $4017 bit 1 (an expansion pad)."""

    def __getitem__(self, a):
        if a == 0x4017:
            t = self.cpu.processorCycles
            assert t - self.wrote >= 50, 'read %d cycles after a write' % (t - self.wrote)
            if self.device == 'none':
                return 0x40
            if self.device == 'pad':
                return 0x40 | (self.cpu.processorCycles & 2)
            if not self.on or self.row == 9:
                return 0x40 if not self.on else 0x5E
            bits = 0
            for i, k in enumerate(MATRIX[self.row][self.col]):
                if k in self.down:
                    bits |= 2 << i
            return 0x40 | (bits ^ 0x1E)
        return bytearray.__getitem__(self, a)

    def __setitem__(self, a, v):
        if a == 0x4016:
            col = v >> 1 & 1
            if self.col and not col:
                self.row = (self.row + 1) % 10
            self.col = col
            if v & 1:
                assert self.cpu.processorCycles - self.wrote >= 0
                self.row = 0
            self.on = bool(v & 4)
            self.wrote = self.cpu.processorCycles
        Memory.__setitem__(self, a, v)


class Keyboard(unittest.TestCase):
    def setUp(self):
        c = CPU(bank=5)
        port = Port(0x10000)
        port[:] = c.mem
        port.rom, port.shift, port.count = c.mem.rom, 0, 0
        port.row = port.col = port.wrote = 0
        port.on, port.down, port.device = False, set(), 'keyboard'
        c.mem = c.mpu.memory = port
        port.cpu = c.mpu
        self.c, self.port = c, port

    def scan(self, *keys):
        self.port.down = set(keys)
        return self.c.call('kb_scan')

    def key_of(self, name):
        for r, row in enumerate(MATRIX):
            for c, col in enumerate(row):
                if name in col:
                    return r * 8 + c * 4 + col.index(name)

    def test_every_letter_types_itself(self):
        kb_map = self.c.sym['kb_map']
        for ch in ALPHA:
            self.scan()
            k = self.scan(ch)
            self.assertEqual(k, self.key_of(ch), ch)
            self.assertEqual(ALPHA[self.c.mem[kb_map + k]], ch)
        self.assertLess(self.c.cycles, 3000, 'a tenth of a frame')

    def test_del_return_and_keys_not_in_passwords(self):
        kb_map = self.c.sym['kb_map']
        for name, want in (('DEL', KB_DEL), ('RETURN', KB_RET), ('I', KB_BAD), ('O', KB_BAD),
                           ('0', KB_BAD), ('1', KB_BAD), ('SPACE', KB_NONE), ('F1', KB_NONE)):
            self.scan()
            self.assertEqual(self.c.mem[kb_map + self.scan(name)], want, name)

    def test_a_held_key_types_once(self):
        self.scan()
        self.assertEqual(self.scan('A'), self.key_of('A'))
        self.assertEqual(self.scan('A'), KB_NONE)
        self.assertEqual(self.scan('A', 'B'), self.key_of('B'), 'the next key while A is held')
        self.assertEqual(self.scan(), KB_NONE)
        self.assertEqual(self.scan('A'), self.key_of('A'))

    def test_no_keyboard_types_nothing(self):
        for device in ('none', 'pad'):
            self.port.device = device
            for _ in range(3):
                self.assertEqual(self.scan(), KB_NONE, device)

    def test_scan_leaves_the_keyboard_off(self):
        self.scan('A')
        self.assertFalse(self.port.on, 'so it does not answer the controller reads')


if __name__ == '__main__':
    unittest.main()
