# Patch notes

Every version of Pixel Racer NES, newest first. Downloads are on the
[Releases page](https://github.com/Trevor792221/PCR-to-Nes-port/releases).

## v4.9: ECU tuning (2026-10-18)

* The fuel map and ignition timing now need an ECU upgrade, like the 2-step. On a stock ECU the TUNE screen shows NEEDS ECU for both. Fuel and timing values a car already has (from a save or a TUNE password) are kept, but they only take effect once the car has an ECU upgrade.

## v4.8: New wheelie bars (2026-10-18)

* Wheelie bars are redrawn as an angled truss down to a small wheel. In races the struts are painted in your car's colour.
* Filled the see-through pixel beside each wheel on every car and traffic vehicle, so the background no longer shows through the body.

## v4.7: New highway traffic (2026-10-18)

* All five traffic vehicles are redrawn: a company van, a work pickup with a ladder rack, a camper van with a pop-top roof, a removal truck with a square cab, and a yellow taxi with a roof sign.
* All traffic now has light blue windows.
* Taxis only drive in cruise mode, where they are always yellow; street races keep the other four. Cruise traffic's second colour is yellow too.

## v4.6: Every car redesigned (2026-10-18)

* All 13 cars have a new, original sprite of their own (they used to share 7 body shapes):
  * Pukku Mini: kei box
  * Komet 1.6: hot hatch with a roof spoiler
  * Sakura S2: roadster
  * Vantra RS: rally estate with a roof rack
  * Hollis SS: 70s notchback
  * Okami 300: twin-turbo GT with a wing
  * Torro 4x4: off-roader
  * Zephir GT-X: AWD coupe with a short wing
  * Brennan 427: modern V8 coupe
  * Raijin R: sleek ducktail with a lip spoiler
  * Veloce V12: 80s wedge
  * Nova Hyper: electric-era hypercar
  * Zenith X400: land-speed streamliner
* The new sprites appear everywhere: races, the garage, the dealer and the boss intros.
* Highway traffic keeps its own generic cars, so it never looks like a car you can buy.

## v4.5: Wheelie bars for every car (2026-10-18)

* FWD cars can now fit wheelie bars too: they stop the rear from squatting and keep weight on the front wheels at launch. Every level adds +3 launch grip on FWD and AWD, +5 on RWD.
* They show on FWD cars in the garage and in races like on any other car.

## v4.4: Eclipse in Tokyo, visible wheelie bars (2026-10-18)

* The secret boss Eclipse now only shows up in race select in the Tokyo region (still only while you drive the Zenith X400).
* Wheelie bars now show on the car: a bar behind the rear wheel with a small wheel at the end, in races and in the garage showroom. Rivals with wheelie bars show them too.

## v4.3: Tunes in a password (2026-10-18)

* Tuned cars now get a third password, **PASSWORD 3: TUNES**. It holds each tuned car's fuel map, ignition timing, boost, tire pressure, 2-step and gear ratios. OPTIONS → PASSWORD shows it: press A on the first page.
* Cars left on the stock tune add nothing to it. If nothing is tuned there's no third password: just press START at PASSWORD 3.
* Long tune passwords scroll while you type them, with a letter count.
* Passwords from older versions still work: enter the first two and press START at PASSWORD 3.

## v4.2: Engine tuning (2026-10-18)

* Two new parts: **wheelie bars** (more launch grip on RWD and AWD cars) and **injectors** (a little power, and the fuel to run lean or overboost).
* The intercooler now needs a turbo. It also raises the knock limit.
* TUNE is now an engine tune screen that shows peak power, and whether the engine knocks or runs lean, as you change:
  * **Fuel map**: its own screen with 8 cells across the rev range, each from rich to lean. Lean makes power until the injectors run out; rich is safe but slower.
  * **Ignition timing**: advance makes power until the engine knocks.
  * **Boost**: set the psi once a turbo is fitted.
  * **Tire pressure**: soft tires grip at launch but drag at speed.
  * **2-step launch control**: after an ECU upgrade, hold A on the line and the revs wait at your launch rpm.
  * **Gear ratios**: as before.
* Garage passwords now hold the new parts (12 letters for one car, up to 74). Older garage passwords still work. Engine tunes start fresh after a password, like gear tunes.

## v4.1: Road to Tokyo (2026-10-18)

* The world map has its own song, "Road to Tokyo": an upbeat travel theme with a Japanese scale. The garage music comes back when you leave the map.
* The debug menu's SOUND TEST can play it, and it's in the soundtrack download as `07-road-to-tokyo.wav`.

## v4.0: World map of Japan (2026-10-18)

* RACE now opens a map of Japan. Pick the region you race in: Fukuoka, Hiroshima, Osaka, Nagoya, Gunma, Sapporo and Tokyo open at levels 1, 2, 4, 6, 8, 11 and 14.
* Later regions have tougher quick and street rivals (better-tuned and faster cars, sharper drivers). They also pay more: bets and street prizes scale from x1 up to x4 in Tokyo, and wins give extra XP.
* Every ladder boss now comes from a region and needs the level that opens it. The boss intro shows where they're from, and race select shows the level you need.
* The results screen tells you when a race opens a new region. Entering a password puts you on the furthest region you've opened.
* Fixed quick and street rivals always having every part at level 3, whatever the difficulty. They now match your car and the difficulty, as intended.

## v3.9: Player 2 HUD and a shift marker (2026-10-17)

* 2 PLAYER races now show a full HUD for both players: each gets a rev counter with its own red zone, gear, speed and nitrous bar, with the race clock in the middle.
* An orange mark on the rev counter shows where a Perfect shift starts (450 rpm under the redline): shift when the bar reaches it.
* Player 2 now gets the quicker Perfect shift too.

## v3.8: The garage at night (2026-10-17)

* After every race the garage is day or night at random.
* At night the door is open on a starry skyline, and a new song, "After Hours", plays.

## v3.7: Neon Boulevard (2026-10-17)

* New garage song, "Neon Boulevard". After every race the garage picks a song at random.
* Debug menu: SOUND TEST plays any song or sound effect.

## v3.6: Compact stats (2026-10-17)

* Every screen now shows stats as "3599HP 1282KG AWD", and the dyno as "PEAK 3599HP AT 10199 RPM".

## v3.5: Parts screen fix (2026-10-17)

* Fixed the stats line next to the car name being cut off (a lone "A") on fast or heavy cars.

## v3.4: Music and engine revs (2026-10-17)

* The music starts at power-on and carries on through the title and garage.
* Picking a title option or a race revs the engine.
* Fixed the garage going silent after a race (the theme now comes back).

## v3.3: Two players and a boss theme (2026-10-17)

* New 2 PLAYER drag races on one console: controller 2 drives a car from your garage.
* New boss theme, "Showdown", on the boss intro screen.
* Fixed a rare vblank overrun at the start of street races.

## v3.2: Boss intros and fair prices (2026-10-17)

* Part prices now follow how much speed each part adds: turbo and tires cost the most.
* Selling a car refunds half of what its parts cost.
* Every boss race opens with an intro screen: the boss, their car and HP, a short bio and the prize.

## v3.1: Stats in the password (2026-10-16)

* The player password (now 32 letters) also keeps your stats page.
* A CRC check rejects any password with a wrong letter.
* v3.0 passwords still work.

## v3.0: Passwords (2026-10-16)

* The battery save is replaced by two passwords: PLAYER (progress) and GARAGE (your cars).
* OPTIONS > PASSWORD shows them; TITLE > PASSWORD enters them.
* Note: battery saves from v2.x are not read. Write your passwords down before updating.

## v2.5: Bridge to passwords (2026-10-17)

* For players with a battery save from v1.0 to v2.4: OPTIONS > PASSWORD shows the two passwords that v3.1 and later accept.
* Load your old save in this version, write both passwords down, then enter them in the latest version (TITLE > PASSWORD) to carry on with your cars, money, bosses and stats.
* Otherwise the same as v2.4 (battery save). Use the latest release for new games.

## v2.4: Intercooler and aero (2026-10-16)

* Two new parts: intercooler (more power, much more with a turbo) and aero kit (less drag, more grip).
* The parts screen has ENGINE and CHASSIS pages.
* Gear tuning unlocks with any gearbox upgrade, and painting is free.
* Cursor presses are no longer missed on the parts and tune screens.

## v2.3: Traffic variety (2026-10-16)

* Traffic is now a mix of sedans, hatchbacks, pickups, minivans and box trucks, each with its own speed.
* Traffic colours change from race to race; cruise traffic comes in two colours.

## v2.2: Empty roads and the mile (2026-10-16)

* Cruise can be played without traffic (Left/Right on CRUISE).
* New 1-mile distance for ladder, quick races and test runs.

## v2.1: Tuning and dyno fixes (2026-10-16)

* RESET TO STOCK and BACK now show on the tune screen for 7-gear cars.
* Dyno peak HP now matches the HP shown in the garage and dealer.
* Unlimited nitrous while cruising.

## v2.0: Cruise mode (2026-10-16)

* New CRUISE mode: endless driving on the 3-lane road with traffic. Pause, then SELECT to leave.
* Quitting from the pause menu is now immediate.

## v1.9: Zenith at the dealer (2026-10-16)

* After beating The Legend, the dealer sells the Zenith X400 for $600,000.

## v1.8: Garage and splash screen (2026-10-16)

* Back to the original car art style.
* The garage now has scenery: ceiling lamps, a roll-up door, pegboard, tire stack and tool chest.
* New boot splash screen with an original 90s-style coupe.

## v1.7: Race backgrounds (2026-10-16)

* Every race picks day, sunset or night scenery at random.

## v1.6: New car art (2026-10-16)

* Redrawn car sprites.
* Fixed the 2x car preview for some body shapes.

## v1.5: Secret boss and stats (2026-10-16)

* Cash is capped at $9,999,999, fixing the display glitch at $10 million.
* Hidden 12th boss, Eclipse, appears in race select while you drive the Zenith X400.
* New stats page: races, wins and losses, best 1/4 mile, fastest trap speed, boss tracker and crates opened.

## v1.4: Game Genie codes (2026-10-16)

* Cheat switches at fixed ROM addresses for Game Genie codes: unlimited money, start with any car, and a hidden debug menu.
* See CHEATS.md for the codes.

## v1.3: The Zenith X400 (2026-10-16)

* New ultra-rare crate-only car: the Zenith X400, a 400 mph prototype that never spins its tires.
* Odds: 1 in 256 from standard crates, 5 in 256 from premium crates (keep a garage slot free).

## v1.2: Faster speedometer (2026-10-16)

* Speeds above 255 mph (and km/h) now display correctly, up to 999.

## v1.1: Economy fix (2026-10-16)

* The Pukku Mini now costs $400, so it can no longer be bought and sold back for free money.

## v1.0: First release (2026-10-16)

* Pixel Racer NES: an unofficial NES drag-racing and car-building demake, written in 6502 assembly (MMC1, 128 KB).
* Garage hub, 12 original cars, 10 upgradeable parts, gear tuning, a live dyno, paint shop, crates, XP and levels.
* Ladder of 10 street bosses plus The Legend, quick races with bets, street races with traffic and test runs.
* Manual shifting with Perfect/Good/Early/Late feedback, launch control, wheelspin and nitrous.
* Fixed garbled graphics on real hardware after browsing the dealer (screen updates now always fit in vblank).
* The soundtrack is available as WAV files, and the ROM has a download button on GitHub.

