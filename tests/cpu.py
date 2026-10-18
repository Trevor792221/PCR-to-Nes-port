"""Run routines from the ROM's fixed bank on py65 (for unit tests)."""
import os
import re

from py65.devices.mpu6502 import MPU

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROM = os.path.join(ROOT, 'build', 'pxracer.nes')
LBL = os.path.join(ROOT, 'build', 'pxracer.lbl')
RET = 0x07FF            # BRK-free trap address in RAM


def labels():
    out = {}
    with open(LBL) as f:
        lines = f.readlines()
    for line in lines:
        m = re.match(r'al ([0-9A-F]+) \.(\S+)', line)
        if m:
            out[m.group(2)] = int(m.group(1), 16)
    return out


class Memory(bytearray):
    """64 KB with MMC1 PRG banking: writes to $8000+ go to the mapper's
    shift register instead of the ROM (FARCALL switches banks this way)."""

    def __setitem__(self, a, v):
        if isinstance(a, int) and a >= 0x8000:
            if v & 0x80:
                self.shift = self.count = 0
                return
            self.shift |= (v & 1) << self.count
            self.count += 1
            if self.count == 5:
                if a >= 0xE000:
                    b = self.shift & 0x0F
                    bytearray.__setitem__(self, slice(0x8000, 0xC000),
                                          self.rom[b * 0x4000:(b + 1) * 0x4000])
                self.shift = self.count = 0
            return
        bytearray.__setitem__(self, a, v)


class CPU:
    def __init__(self, bank=2):
        with open(ROM, 'rb') as f:
            rom = f.read()[16:]
        self.mem = Memory(0x10000)
        self.mem.rom, self.mem.shift, self.mem.count = rom, 0, 0
        self.mem[0x8000:0xC000] = rom[bank * 0x4000:(bank + 1) * 0x4000]
        self.mem[0xC000:0x10000] = rom[7 * 0x4000:8 * 0x4000]
        self.mpu = MPU(memory=self.mem)
        self.sym = labels()
        self.cycles = 0

    def call(self, name, a=0, x=0, y=0, limit=500000):
        mpu = self.mpu
        mpu.a, mpu.x, mpu.y = a, x, y
        mpu.sp = 0xFD
        ret = RET - 1
        self.mem[0x100 + mpu.sp] = ret >> 8
        mpu.sp -= 1
        self.mem[0x100 + mpu.sp] = ret & 0xFF
        mpu.sp -= 1
        mpu.pc = self.sym[name]
        start = mpu.processorCycles
        n = 0
        while mpu.pc != RET:
            mpu.step()
            n += 1
            if n > limit:
                raise RuntimeError('%s did not return' % name)
        self.cycles = mpu.processorCycles - start
        return mpu.a

    def __getitem__(self, name):
        return self.mem[self.sym[name]]

    def get(self, name, off=0, size=1):
        a = self.sym[name] + off
        v = 0
        for i in range(size):
            v |= self.mem[a + i] << (8 * i)
        return v

    def put(self, name, value, off=0, size=1):
        a = self.sym[name] + off
        for i in range(size):
            self.mem[a + i] = (value >> (8 * i)) & 0xFF
