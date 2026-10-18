# Pixel Racer NES -- build with cc65 (ca65/ld65) and python3
AS      = ca65
LD      = ld65
PYTHON  = python3

ROM     = build/pxracer.nes
SRCS    = $(wildcard src/*.s) src/defs.inc
GEN     = build/tiles.inc build/cardata.inc build/music.inc build/splash.nam build/map.inc

all: $(ROM)

build/tiles.inc: tools/mkchr.py tools/art.py tools/font.py
	@mkdir -p build
	$(PYTHON) tools/mkchr.py build

build/splash.nam: tools/mksplash.py tools/mkchr.py tools/font.py
	@mkdir -p build
	$(PYTHON) tools/mksplash.py build

build/map.inc: tools/mkmap.py tools/japan_coast.json
	@mkdir -p build
	$(PYTHON) tools/mkmap.py build

build/cardata.inc: tools/mkdata.py tools/gamedata.py
	@mkdir -p build
	$(PYTHON) tools/mkdata.py $@

build/music.inc: tools/mkmusic.py
	@mkdir -p build
	$(PYTHON) tools/mkmusic.py $@

build/main.o: $(SRCS) $(GEN)
	$(AS) -I src -I . -g -o $@ src/main.s -l build/pxracer.lst

$(ROM): build/main.o cfg/pxracer.cfg
	$(LD) -C cfg/pxracer.cfg -o $@ --dbgfile build/pxracer.dbg -m build/pxracer.map -Ln build/pxracer.lbl build/main.o

test: $(ROM)
	$(PYTHON) -m unittest discover -s tests -v

soundtrack: tools/render_wav.py tools/mkmusic.py
	$(PYTHON) tools/render_wav.py release/soundtrack

clean:
	rm -rf build

.PHONY: all test clean soundtrack
