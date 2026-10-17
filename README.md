# Pixel Racer NES

[![Download ROM](https://img.shields.io/badge/Download-Pixel%20Racer%20ROM%20(.nes)-2ea44f?style=for-the-badge&logo=github)](https://github.com/Trevor792221/PCR-to-Nes-port/releases/latest/download/pxracer.nes)
[![Download soundtrack](https://img.shields.io/badge/Download-Soundtrack%20(.zip)-1f6feb?style=for-the-badge&logo=github)](https://github.com/Trevor792221/PCR-to-Nes-port/releases/latest/download/pixel-racer-soundtrack.zip)

Every version is on the [Releases page](https://github.com/Trevor792221/PCR-to-Nes-port/releases).
What changed in each one: [patch notes](CHANGELOG.md).

An NES demake of the drag-racing and car-building game style made popular by
**Pixel Car Racer** on Android. It's written from scratch in 6502 assembly and
runs on real NES / Famicom hardware or any accurate emulator.

> **Unofficial fan project.** It isn't made by, endorsed by, or affiliated
> with Studio Furukawa or the makers of Pixel Car Racer. No code, graphics,
> sounds, music or text from the original game are used. The game rules and
> features are reimplemented, and every car sprite, background, tune and car
> name in this ROM is original.

![Splash](docs/splash.png) ![Title](docs/title.png) ![Garage](docs/garage.png)
![Race](docs/race.png) ![Dyno](docs/dyno.png)

## What carried over from the Android game

| Pixel Car Racer feature | NES version |
|---|---|
| Garage as the game hub, with your car on display | Garage screen: your car shown 2x size in a workshop (ceiling lamps, roll-up door, pegboard, tire stack, tool chest), plus cash, gems and level. The game boots to a splash screen: an original 90s-style sports coupe in front of a neon sunset |
| Car dealership | 12 original cars from hatchbacks to a hypercar, each with its own shape, power, weight, redline, gear count, drivetrain (FWD/RWD/AWD) and level requirement |
| Owning several cars | 8 garage slots. Switch cars, or sell them for half the car's price plus part value |
| Engine and performance parts | 12 parts at 5 levels each (Stock, Street, Sport, Race, Pro), on two pages (Left/Right to switch). **Engine:** intake, exhaust, ECU tune (also raises the redline), turbo (with boost lag and spool), intercooler (a little power on its own, more boost with a turbo), internals, nitrous. **Chassis:** gearbox (faster shifts), tires, suspension, weight reduction, aero kit (less drag for a higher top speed, plus downforce grip). Each part is priced by how much it actually speeds a car up (measured with the physics model, `tools/part_value.py`): turbo and tires cost the most, intake, exhaust and intercooler the least. Selling a car refunds half of what its upgrades cost |
| Tuning | Final-drive and individual gear ratios. Each gear shows its top speed. Gear tuning unlocks with any gearbox upgrade |
| Dyno | Live dyno run that plots horsepower and torque curves, with peak HP and Nm and the rpm where each peaks. The peak HP is the same figure shown in the garage and dealer |
| Paint shop | Body, rim and window colours (24 colours each) with a live preview. Painting is free |
| Crates | Standard (cash) and Premium (gems) crates. Rewards are cash, gems, free part upgrades or a whole car. Very rarely (1 in 256 standard, 5 in 256 premium) they hold the **Zenith X400**, a crate-only prototype racer that never spins its tires and tops out over 400 mph. Keep a garage slot free, or the roll goes to a normal reward. Once you beat The Legend (the last ladder boss), the dealer also sells it for $600,000 |
| Drag racing with manual shifting | 1/4 mile, 1/2 mile and full-mile drag races (set the distance in race select). Rev on the line, launch on green, shift by hand, fire nitrous. Shift feedback: Perfect, Good, Early or Late |
| Launch / wheelspin | Clutch-dump launch model: too many revs spin the tires (with smoke), too few bog the engine |
| Street racing | Half-mile street race on 3 lanes with traffic. Change lanes to dodge cars; crashing costs you your speed. Traffic is a mix of sedans, hatchbacks, pickups, minivans and box trucks, each with its own speed range (trucks crawl, hatchbacks nip along). Traffic colours change from race to race, and cruise traffic comes in two colours at once |
| Race scenery | Every race picks one of three backgrounds at random: **day** (pale sky, clouds, grey city), **sunset** (purple-to-orange sky, low sun, black skyline) or **night** (navy sky, moon, lit windows) |
| Story / ladder progression | Ladder of 10 street bosses, plus a final "Legend" boss. A hidden 12th boss, **Eclipse**, appears in race select only while you drive the Zenith X400. Beating it pays $500,000 and, the first time, 25 gems. Before every boss race an intro screen shows the boss, their car in its colours with its HP, a short bio and the prize; B backs out. The intro plays its own theme, "Showdown" |
| Quick races with bets | Random rival on Easy, Medium or Hard, betting $300, $1,000 or $2,500 |
| Free roam | **Cruise**: endless driving on the 3-lane road, no rival and no finish line. Press Left/Right on CRUISE to turn traffic on or off. Nitrous is unlimited: the bottle refills as soon as a shot ends. START pauses, then SELECT returns to the garage |
| Multiplayer | **2 PLAYER** in race select: a head-to-head drag race on one console. Player 2 uses controller 2 with the same buttons (A gas, Right launch/shift up, Left shift down, B nitrous) and drives any car from your garage (Left/Right on the 2 PLAYER row picks it). Distance follows the DISTANCE setting. Either player can foul by launching early. The camera keeps both cars on screen until the leader is far ahead. No money, XP or stats are at stake. Online play from the Android game isn't possible on an NES |
| Practice / test runs | Solo test run with elapsed time, trap speed, reaction time and 0-60 time. The best 1/4-mile time is kept per car |
| XP, levels and premium currency | XP from every race. Levelling up gives gems, and higher levels unlock better cars |
| Saving | **Passwords**, like classic NES games. OPTIONS → PASSWORD shows two: a 32-letter **player** password (cash, gems, level, XP, bosses beaten, options, and the stats page: races, wins, losses, crates, street wins, best 1/4-mile time and fastest trap speed with their cars) and a **garage** password (every car with all its parts and body colour, and the car you drive) that is 11 letters for one car and grows by about 8 letters per car, up to 66. Enter them from TITLE → PASSWORD. Gear tunes, rim and glass colours and each car's own best time start fresh after a password. The letters skip I, O, 0 and 1 so nothing looks alike, and a CRC-8 check rejects any password with a wrong letter. 15-letter player passwords from v3.0 (no stats) still work |
| Stats | Garage → STATS: races completed, wins and losses, your best 1/4-mile time and the car that set it, your fastest trap speed and car, a boss tracker (+ beaten, - not yet), and crates opened |
| Options | MPH or km/h, music on/off, manual or automatic shifting, quit to title |

Some features were left out or reduced to fit the NES. These include online
multiplayer (local 2-player races are in), the in-app shop, tournaments, the parts market, real car
brands, and engine swaps. The hundreds of parts are condensed into 12
categories. Sprites are 32x16 pixels in races and 64x32 in menus.

## Game Genie codes

[CHEATS.md](CHEATS.md) has Game Genie codes for unlimited money, starting
with any car, and a hidden debug menu that adds cars, money and gems or
jumps to any ladder boss.

## Controls

| Button | In races | In menus |
|---|---|---|
| A | Gas. Hold it on the line to rev | Select |
| Right | Shift up (the first press launches) | Change value |
| Left | Shift down | Change value |
| B | Nitrous | Back |
| Up / Down | Change lane (street race) | Move cursor |
| Start | Pause | |
| Select | Quit, while paused | Sell car (My Cars) |

**How to race.** Hold **A** to rev while the amber lights come on. When the
light turns green, press **Right** to drop the clutch. Pressing it before
green is a foul start, and you lose. Shift when the tach is deep in the red
zone, just under the limiter, for a *Perfect* shift, which also makes the
gear change faster. Pick your launch revs to suit your tires: high revs with
street tires just make smoke.

## Building

You need [cc65](https://cc65.github.io/) (`ca65`/`ld65`) and Python 3. The
graphics, car tables and music are generated by the Python tools in `tools/`.

```sh
make            # -> build/pxracer.nes
make test       # needs: pip install cynes py65 numpy pillow
```

A prebuilt ROM is also in the repo at [`release/pxracer.nes`](release/pxracer.nes).

To publish a new release, add its patch notes as `release/notes/vX.Y.md`
(and to `CHANGELOG.md`), then push a version tag (`git tag v1.1 && git push
origin v1.1`) or run the **release** workflow from the Actions tab. It
builds and tests the ROM, then attaches it and the soundtrack to a GitHub
Release, which is where the download buttons point. The release text starts
with that version's notes. The **patch-notes** workflow rewrites the text of
every existing release from `release/notes/`.

## Soundtrack

The game's original music is also available as WAV files (44.1 kHz,
16-bit mono) in [`release/soundtrack/`](release/soundtrack):

| File | Track |
|---|---|
| `01-midnight-garage.wav` | "Midnight Garage", the title and garage theme (two loops, 68 s) |
| `02-win.wav` | Race win jingle |
| `03-lose.wav` | Race lose jingle |
| `04-showdown.wav` | "Showdown", the boss intro theme (two loops, 34 s) |
| `05-neon-boulevard.wav` | "Neon Boulevard", the second garage theme (one loop, 34 s) |
| `06-after-hours.wav` | "After Hours", the garage at night (one loop, 34 s) |

`make soundtrack` regenerates them. `tools/render_wav.py` plays the same
music data as the ROM through an emulation of the game's sound engine and
the NES APU: two pulse channels, the triangle and the noise channel, mixed
the way the console mixes them.

## Cartridge

| Part | Size | Notes |
|---|---|---|
| Mapper | MMC1 (SNROM), iNES mapper 1 | NES 2.0 header |
| PRG-ROM | 128 KB | 8 x 16 KB banks. Bank 7 is fixed at `$C000` |
| CHR-RAM | 8 KB | Tiles are uploaded or generated at run time (dyno graph, 2x cars) |
| PRG-RAM | 8 KB, no battery | Game state plus work buffers. Progress is saved with passwords |

It runs on flash carts (EverDrive N8, PowerPak and similar) or on any SNROM
board. Timing is tuned for **NTSC**. PAL consoles get the same game, but the
physics runs at 50 Hz.

| Bank | Contents |
|---|---|
| 0 | Tile data, background maps |
| 1 | Title, garage, race select, my cars, dealer, results |
| 2 | Race engine (drag, street, test), HUD, AI, traffic |
| 3 | Parts, tune, paint, crates, dyno, options |
| 4 | Race scenery (day, sunset, night) and the boot splash screen |
| 5 | Passwords (encode, decode, entry and display screens) |
| 7 (fixed) | Reset/NMI, PPU helpers, math, physics, sound, game state, car data |

## How it works

* **Physics** (`src/physics.s`). Fixed-point 24-bit speed and position per
  car. It models:
  * a torque curve stretched to each car's redline;
  * turbo boost that ramps in with rpm and spools over time;
  * gearing, aero drag and rolling resistance;
  * a traction limit set by tires, suspension and drivetrain;
  * wheelspin, with separate wheel and car speeds;
  * clutch slip on launch, timed gear shifts and nitrous.

  `tools/gamedata.py` holds a Python reference model of the same maths, and
  `tests/test_physics.py` checks that the 6502 code matches it frame by frame
  for every car.
* **Rendering.** The HUD at the top doesn't scroll. A sprite-0 hit splits it
  from the city skyline, which scrolls at 1/4 speed for parallax. A timed
  second split starts the road, which scrolls at full speed. The start and
  finish lines are streamed into the nametables as columns. Race logic is
  budgeted to fit in one frame, so races run at a steady 60 fps.
* **Vblank budget.** The NMI uploads sprites, the palette, a VRAM update
  queue and (for the menus' 2x car previews) 32 bytes of tile data per
  frame. Tile streaming is skipped on frames that already upload the palette
  or a long queue, so all PPU writes finish inside vblank on real hardware.
  `tests/test_nmi.py` times the NMI on real game frames (including the
  514-cycle sprite DMA) and fails if any frame would overrun.
* **Sound** (`src/sound.s`). A 4-channel music player plays an original
  theme and jingles. The theme starts on the first frame of the boot splash
  and keeps playing through the title and the garage. After every race the
  garage rolls day or night at random. By day it plays "Midnight Garage" or
  "Neon Boulevard"; at night the roll-up door is open on a starry sky and a
  lit skyline, the walls go dark blue, and "After Hours" plays. Choosing a title
  option or a race blips an engine rev (a pulse growl that follows the race
  engine's rpm-to-pitch curve, plus an exhaust rumble) over the music. In races, an engine synthesizer drives pulse 1 and the
  triangle from your rpm and pulse 2 from the rival's. The noise channel
  handles exhaust rumble, tire squeal, nitrous hiss, blow-off valve and
  shift sounds.
* **Multiplication** uses quarter-square tables, so 16x16 multiplies take
  about 300 cycles.

## Tests

`make test` runs these suites:

* `tests/test_physics.py` runs the physics on a 6502 emulator (py65) and
  checks it against the Python model, frame by frame.
* `tests/test_nmi.py` checks that every NMI's PPU writes fit in vblank
  (menus, dealer browsing, a street race).
* `tests/test_password.py` checks the passwords: the reference encoder in
  `tools/password.py` round-trips, the ROM's passwords match it, both typed
  into a fresh console restore the game, and wrong passwords are refused.
* `tests/test_cheats.py` runs the game with each Game Genie code applied
  and checks that the cheat works, and that the debug menu stays hidden
  without the code.
* `tests/test_game.py` plays the ROM in the cynes NES emulator. It covers new
  game, buying parts, state kept across a reset, a test run, beating the
  first ladder boss, foul starts, a street race with no dropped frames, the
  dealer and crates.

## Layout

```
src/        6502 source (main.s includes everything)
tools/      graphics (mkchr.py, art.py), data (gamedata.py, mkdata.py), music (mkmusic.py)
cfg/        ld65 memory map
tests/      emulator test suites
docs/       screenshots
release/    prebuilt ROM
```
