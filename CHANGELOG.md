# Patch notes

Every version of Pixel Racer NES, newest first. Downloads are on the
[Releases page](https://github.com/Trevor792221/PCR-to-Nes-port/releases).

## v5.5: Battery saves, boss cars, data recorder (2026-10-22)

* **Win the bosses' cars.** The first time you beat a boss, their car is yours, just as they raced it: the same model, parts and paint, marked BOSS CAR in the garage. Its tune, parts and swaps are locked (it stays as the boss built it), but you can repaint it, and race it or sell it. It sells for half the car's price, since its parts came free. With a full garage it's sold for you straight away. The garage password keeps boss cars as they are, and passwords for garages without one are unchanged.
* Two-player races: each player's tach updates every other frame, in turns, which keeps things smoother when both players launch at once.
* **Famicom Data Recorder.** Save your game to cassette and load it back on a Famicom with the Family BASIC keyboard and its data recorder. It's under OPTIONS → DATA RECORDER, and on the title screen so a fresh console can load a tape. To save, press RECORD on the deck, then A; it takes about 3 seconds of tape. To load, rewind, press A, then PLAY; B gives up. A tape only replaces your game if every byte checks out and it's a save from this version, so a bad or wrong tape leaves your game alone. The battery save and passwords work as before.
* **Battery saves are back.** The game saves itself as you play and CONTINUE picks up where you left off, even after the power goes off. It also keeps a backup of the last save, so a power cut while saving loses at most that one change instead of the whole game. Passwords still work as before.
* **Sunset garage.** After a race the garage can now come up at sunset too: the roll-up door is open on a purple and red sky with the sun going down behind the city, and the brick walls and floor glow warm. Day, sunset and night each come up a third of the time.
* Crates are paid in gems only: the Standard crate is now 5 gems (it was $2,500) and the Premium crate is still 10. Cash-bought crates made it too easy to max out a car's parts.
* Engine swaps cost 5 gems more: 10 to 35 gems instead of 5 to 30.
* Each car pays for an engine or drivetrain only once. Swap away from one it has had fitted and you can swap it back in for free. The SWAP screen shows these as "A: SWAP BACK (FREE)". Selling a car forgets them.
* The garage password remembers the swaps each car has paid for, so they stay free after a password. Passwords for garages with no spare paid-for swaps are unchanged.
* Harder quick races give more XP for a win: 100 on Easy, 150 on Medium and 200 on Hard, plus 10 per map region as before. Before, every difficulty gave 100. A loss is still 25.
* Fixed: pressing START (race again) after beating a boss raced the next boss even when its region wasn't open yet or it lives in another region. It now checks the same as race select, and if the boss can't be raced there it says why ("BOSS IS IN HIROSHIMA" or "LOCKED: REACH LEVEL 7").

## v5.4: Perfect launches, keyboard passwords (2026-10-19)

* A perfect launch now reads **0.000** reaction time, as on a real drag strip: the time counts from the green light, so pressing Right on the first frame you can launch scores 0.000. One frame earlier is still a foul start. Before, the best possible time was 0.016.
* **Famicom keyboard.** Passwords can be typed on a Family BASIC keyboard plugged into the Famicom's expansion port: letter and number keys type (the cursor jumps to the letter), DEL deletes, RETURN finishes. I, O, 0 and 1 aren't in passwords and just buzz. The controller works as before, and with no keyboard plugged in nothing changes.

## v5.3: Fixes (2026-10-19)

* Fixed: right after you buy a turbo, the intercooler now shows its price instead of LOCKED. Before, it only updated when the screen was redrawn.
* Fixed: wheelie bars now meet each car's own rear bumper in races. On some cars (the Pukku Mini most of all) they used to float a pixel or two behind the car, and on others they overlapped the body.
* Traffic hits are now pixel perfect for every car and traffic vehicle. You crash only when the two vehicles' pixels actually touch, even partway through a lane change. Before, you crashed as soon as you pressed toward a lane with a car in it (even while still sliding across), and nose-to-tail hits used a fixed box about 4 pixels too generous.
* Fixed: graphical glitches in busy street races. The NES can only show 8 sprites on a line. Exhaust smoke, nitrous flames and wheelie bars are now drawn after every car, so when a lane gets crowded the console drops an effect rather than part of a car. Before, the front of a traffic car could go missing.

## v5.2: Balance, nitrous tuning, bosses race at home (2026-10-18)

* Each ladder boss can now only be raced in its home region. Bosses 1-2 are in Fukuoka, 3-4 in Hiroshima, 5-6 in Osaka, 7 in Nagoya, 8 in Gunma, 9 in Sapporo, and 10-11 in Tokyo. Elsewhere, race select tells you where the next boss is, e.g. "BOSS IS IN OSAKA". Before, any region worked once your level was high enough.
* **Balance.**
  * Regions open later, at about the level you'll have reached when your car can beat the previous region's bosses: Fukuoka 1, Hiroshima 7, Osaka 12, Nagoya 17, Gunma 21, Sapporo 23, Tokyo 31. Before, they opened at 1, 2, 4, 6, 8, 11 and 14.
  * Each region's bosses are now a clear step faster than the last. Rosa (Osaka) has level-2 parts instead of level 3, and Iron Jo (Sapporo) now drives a Nova Hyper with level-3 parts instead of a fully upgraded Brennan 427.
  * Easy quick races are easier to win. Easy rivals drive sloppily (slow off the line, poor shifts) and are 12.5% down on power, so a clean race beats them even in the starter car.
* **Nitrous tuning.** The TUNE screen has a NITROUS slider from POWER to DURATION; it needs a nitrous kit. Each step toward power gives a bigger hit for a shorter shot, up to 1.5x the boost for 2/3 of the time. Each step toward duration gives a gentler shot that lasts longer, down to half the boost for twice as long. RESET ENGINE TUNE and engine swaps put it back in the middle. It is saved in the TUNE password, and tune passwords without nitrous tuning are unchanged.

## v5.1: Weather (2026-10-18)

* **Weather.** Every race now has weather as well as a time of day:
  * **Cloudy:** a low cloud bank over the day, sunset or night sky. Grey clouds by day, orange-lit clouds at sunset, and grey clouds over the city lights at night.
  * **Rain:** rain falls over the road and the sky, and the road turns dark and wet. Every car in the race has less launch grip.
  * **Snow:** snow drifts down and the pavements turn white. Grip drops even more than in the rain.
* Weather depends on the region. Rain and clouds can come anywhere. Snow only falls in Gunma and Sapporo, and Sapporo snows more often than not. Elsewhere clear skies are the most common.
* There's no sun, moon or stars when it's cloudy, raining or snowing.
* The dyno now shows torque in lb-ft, and plots power and torque on one shared scale, so the two curves cross at 5252 rpm like a real dyno sheet.
* The dyno has a colour key left of the graph: HP with an orange square and TQ with a blue one, matching the two curves.
* Boss cars on the boss intro screen now sit on a lit stage, so black and dark grey cars no longer disappear into the black background.
* Fixed glitches in the dyno graph. The bottom strip was drawn in the wrong colours, the power line turned blue where it crossed the grid, and steep parts of a curve (a big turbo coming on boost) broke into dashes. Both curves are now smooth, unbroken lines in their own colours.

## v5.0: Engine and drivetrain swaps (2026-10-18)

* **Engine swaps** (garage → SWAP, paid in gems). Choose any dealer car's engine or one of four swap-only crate engines: a twin-rotor rotary, a high-rev I4, a flat six and a big-block V8. Each engine brings its own power, redline, torque curve and weight. Prices run from 5 to 30 gems, and the bigger engines unlock at higher levels. The old engine's parts go back to stock and you get 3/4 of what they cost back in cash. The engine tune is reset.
* **Drivetrain swaps** for 10 gems: FWD, RWD or AWD. AWD launches hardest but is heavier and loses a little power through the driveline. FWD is the lightest but has the least launch grip.
* Going back to a car's own engine or drivetrain is free. The Zenith X400 can't be swapped.
* A rotary engine has its own sound in races.
* The garage menu is now laid out in three columns, with SWAP as the 11th item.
* Swaps are saved in the garage password, which becomes 14-85 letters when a car is swapped. Garages with no swaps keep the same passwords as before, and all older passwords still work.
* The garage now shows your XP towards the next level, as a counter ("XP 120/300") and a progress bar.
* The debug menu has a new ADD 1000 XP item.
* The splash screen shows the version number in the bottom right corner.

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

