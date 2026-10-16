"""Measure how long the NMI's PPU work takes on real game frames.

The game runs in cynes; whenever a frame has been handed to the NMI
(nmi_ready = 1), the RAM is copied into py65 and the NMI handler is run
up to nmi_ppu_done.  All PPU writes must finish inside vblank:
20 scanlines * 341 / 3 = 2273 CPU cycles on NTSC, minus the NMI's own
latency (7 cycles) and a small safety margin.
"""
from cpu import CPU

VBLANK_BUDGET = 2273 - 7 - 60
OAM_DMA = 514           # py65 doesn't stall for the $4014 sprite DMA


def nmi_cycles(sim, bank):
    if not sim.mem('nmi_ready'):
        return None
    cpu = CPU(bank=bank)
    for a in range(0x800):
        cpu.mem[a] = sim.nes[a]
    for a in range(0x6000, 0x8000):
        cpu.mem[a] = sim.nes[a]
    mpu = cpu.mpu
    mpu.sp = 0xF0
    mpu.pc = cpu.sym['nmi']
    start = mpu.processorCycles
    stop = cpu.sym['nmi_ppu_done']
    n = 0
    while mpu.pc != stop:
        mpu.step()
        n += 1
        assert n < 20000, 'NMI runaway'
    return mpu.processorCycles - start + 7 + OAM_DMA
