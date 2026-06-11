# Monaco Racer C64 - Assembly 6502 Test

This project is a small Commodore 64 experiment written in 6502 Assembly, inspired by the arcade mechanics of **Monaco GP** by Sega, originally released in 1979.

The project was created as a test using **Claude Fable5**, then manually reviewed, tested in a C64 emulator, and corrected where necessary.

## Project Description

The game is a simple top-down racing game where the player's car stays near the bottom of the screen while the road scrolls vertically.

<img width="327" height="230" alt="Screenshot 2026-06-11 091811" src="https://github.com/user-attachments/assets/748571cc-53d6-40a9-b92a-c519afc45b2d" />

<img width="319" height="222" alt="Screenshot 2026-06-11 092853" src="https://github.com/user-attachments/assets/4e527e31-4858-4aba-bd1f-8b71891a5ad8" />

<img width="334" height="248" alt="Screenshot 2026-06-11 092904" src="https://github.com/user-attachments/assets/f4e934d9-0c2c-499e-ae18-f58d7d4d71f9" />

<img width="658" height="475" alt="Screenshot 2026-06-11 133819" src="https://github.com/user-attachments/assets/c7530d5a-6847-4286-9a02-880e9a63e010" />


The project includes:

* 6502 Assembly source code using ACME syntax;
* C64Studio compatibility;
* player car, enemy cars, explosion and headlight sprites;
* custom character set;
* variable-width road;
* different track sections such as asphalt, ice, gravel, tunnel and bridge;
* score, lives and best-time table;
* joystick control on port 2.

## Included Files

The repository contains two source files and two executable PRG files:

1. **Original version**
   Generated with **Claude Fable5** as an initial test.

2. **Fixed version**
   Manually corrected by **Fabrizio Radica**, with a specific fix applied to the custom charset management.

This allows the original generated version and the manually fixed version to be compared directly.

## Charset Fix

During emulator testing, a text rendering issue was found in the author string:

```text
FABRIZIO RADICA 2026
```

The issue was caused by the custom tiles being copied into character positions `1`, `2` and `3` of the C64 charset.

On the Commodore 64 screen code table, these positions correspond to:

```text
1 = A
2 = B
3 = C
```

As a result, the letters A, B and C were overwritten by the game's custom graphic tiles, causing some text on screen to appear corrupted.

The fix was to move the custom characters to a safer area of the charset, using character positions `27`, `28` and `29` instead:

```asm
CH_LINE     = 27
CH_GRASS2   = 92
CH_GRAVEL   = 29
```

The custom character data is now copied starting from:

```asm
CHARSET+(27*8)
```

This keeps the standard text characters intact while preserving the custom road, grass and gravel tiles used by the game.

## Compilation

The project can be compiled using **ACME**:

```bash
acme -f cbm -o monaco.prg monaco_fix_charset.asm
```

Alternatively, the source can be opened and built directly with **C64Studio** using **Build & Run**.

## Author

Project test, review and charset fix by:

**Fabrizio Radica**
RadicaDesign

Website:
www.radicadesign.com

Email:
fabrizio@radicadesign.com
