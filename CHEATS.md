# Game Genie codes

These work with the original NES Game Genie (and with emulators that accept
Game Genie codes) for **v1.4 and later** of Pixel Racer NES. The game reads its
cheat switches from fixed addresses (`$FFC0`-`$FFC2`), so the codes don't
change when the game is updated.

## Codes

| Code | Effect |
|---|---|
| `PEKYOYAA` | **Extra money.** Your cash is set to $9,999,999 (the game's maximum) every time you enter the garage. It works on new and existing saves. |
| `PEKYXYAA` | **Debug menu.** Press **SELECT** in the garage. |

### Start with any car

Enter one of these, then pick **NEW GAME** on the title screen. The car
replaces the usual Pukku Mini. (Continuing an existing save isn't affected.)

| Code | Starting car |
|---|---|
| `PEKYEYAA` | KOMET 1.6 |
| `ZEKYEYAA` | SAKURA S2 |
| `LEKYEYAA` | VANTRA RS |
| `GEKYEYAA` | HOLLIS SS |
| `IEKYEYAA` | OKAMI 300 |
| `TEKYEYAA` | TORRO 4X4 |
| `YEKYEYAA` | ZEPHIR GT-X |
| `AEKYEYAE` | BRENNAN 427 |
| `PEKYEYAE` | RAIJIN R |
| `ZEKYEYAE` | VELOCE V12 |
| `LEKYEYAE` | NOVA HYPER |
| `GEKYEYAE` | ZENITH X400 |

## The debug menu

With `PEKYXYAA` entered, press **SELECT** on the garage screen:

| Item | What it does |
|---|---|
| ADD CAR | LEFT/RIGHT picks any car, including the crate-only Zenith X400. **A** puts it in your first free garage slot. |
| BOSS RACE | LEFT/RIGHT picks any of the 11 ladder bosses or the secret 12th boss. **A** starts the race; for a ladder boss it also moves your ladder progress to that boss. |
| ADD $100000 | Adds $100,000. |
| ADD 100 GEMS | Adds 100 gems. |
| ADD 1000 XP | Adds 1,000 XP. You level up as you would after a race, gems included. |
| SOUND TEST | MUSIC: LEFT/RIGHT picks one of the 5 songs, **A** plays it (even with music switched off). SOUND: LEFT/RIGHT picks one of the 17 sound effects, **A** plays it. STOP silences the music. Leaving goes back to the garage theme. |

Everything the debug menu does is saved, just like normal play.

## How the codes work

A Game Genie sits between the cartridge and the console. Each code names one
address in the cartridge's ROM (`$8000`-`$FFFF`) and a byte value. Whenever
the console reads that address, the Game Genie hands back the code's byte
instead of the real one.

* A **6-letter** code always replaces the byte.
* An **8-letter** code also carries a *compare* byte, and only replaces the
  byte when the real one matches. This game swaps 16 KB banks in and out
  (MMC1 mapper), so an address can hold different things at different times.
  The compare byte stops a code from hitting the wrong bank.

All the codes here are 8-letter codes aimed at the game's fixed bank. Each
cheat switch normally holds `$00`, and the code makes the game read a
different value:

| Address | Normal | Meaning |
|---|---|---|
| `$FFC0` | `$00` | Model number of the new-game car (0-12) |
| `$FFC1` | `$00` | Non-zero: keep the cash at $9,999,999 |
| `$FFC2` | `$00` | Non-zero: SELECT in the garage opens the debug menu |

The letters encode address, value and compare bits in a scrambled order.
`tools/gamegenie.py` encodes and decodes them:

```sh
python3 tools/gamegenie.py                   # list all codes
python3 tools/gamegenie.py decode PEKYXYAA     # -> address $FFC2 value $01 compare $00
```

The original Game Genie takes up to three codes at once, so you can combine,
for example, the money code, the debug code and a starting car.
