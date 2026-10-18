# BAZSET Sega System 1/2 for MiSTer FPGA — What's Changed?

**B24 | October 2026 | Public source-code release**

This is an expanded and modified Sega System 1/2 FPGA core built on the excellent work of **MiSTer-X and Blackwine**. The aim has been to improve compatibility, correct hardware behaviour, make the core easier to use on MiSTer, and support more game versions.

The original core already supported many Sega titles and fixed important issues such as Wonder Boy's sprite wobble. These notes focus on the **additional BAZSET work**, without claiming those earlier contributions as our own.

## 1. More game versions and ROM configurations

The private beta distribution grew to **65 MRA game configurations**, including 26 main selections, 32 alternative revisions, four bootlegs and three experimental protected-game options.

That does **not** mean 65 independently working games. It means the ROM layouts and game configurations were prepared and checked. Every variant still needs its own gameplay test.

## 2. Wonder Boy — more than a few small changes

- Corrected the joystick description to match the original **two-way** controls.
- Added **five beta cheats**: Infinite Lives, Full Vitality, Invincibility, Keep Axe, and Keep Skateboard.
- Extended high-score saving support and verified memory save/restore in FPGA simulation.
- Added standard Wonder Boy **Upright/Cocktail cabinet** selection in compatible game configurations.
- Added the missing game-controlled **Player 2 sprite-flip path** for cocktail play.
- Included scrolling, video-width and native display timing corrections.
- Added optional enhanced stereo while retaining the original mono default.
- Prepared additional revisions and alternatives for the private beta.

**Verification note:** Cheat memory effects were checked in MAME and HDL tests, and sprite work passed extensive synthetic rendering checks. The actual MiSTer hardware experience still needs verification.

## 3. Wonder Boy in Monster Land — major additions

- Prioritised an **English decrypted version** in the main game configuration.
- Added **seven beta cheats**: Infinite Time, Infinite Gold, Infinite Pills, Always Key, Legend Sword, Legend Armour and Legend Boots.
- Extended high-score configuration and simulation coverage.
- Improved sound-system handling following missing/interrupted audio in early test builds.
- Added optional enhanced stereo using the two existing sound-chip sources.
- Added the B24 **HDMI Picture Down** option for displays with awkward picture positioning.
- Applied the System 2 scrolling and screen-flip improvements.

The core does not claim that every original encrypted Monster Land board is fully reproduced.

## 4. The sound system was investigated and repaired in stages

Early builds could show the game graphics but suffer silent or interrupted sound. That led to substantial work on the original hardware's sound-command system:

- Corrected the **8255 sound-command handshake** and sound Z80 NMI/acknowledgement sequencing.
- Preserved the authentic **System 2 sound-mute polarity**, after catching and rejecting an incorrect early experimental change.
- Corrected or checked sound-command addressing and readback behaviour.
- Tested the two **SN76489-family sound chips**, READY signalling and 2 MHz / 4 MHz clocks.
- Checked PCM output handling and retained the original **40/60 dual-chip mix**.
- Added **optional enhanced stereo**, smoothly separated from the original sources.

Real Z80 and sound-chip simulations matched the initial **28 sound-register writes** of a MAME Wonder Boy in Monster Land reference. That does not establish full 1:1 sound waveform accuracy.

## 5. UFO Senshi Yohko Chan — extra board-specific engineering

Blackwine's earlier release already listed UFO Senshi Yohko Chan. BAZSET added or verified:

- The **MC-8123 317-0064** protected CPU program path.
- Correct fixed and bank-switched ROM decryption against MAME.
- The game's **three-button controls** and related input-port mapping.
- ROM configuration and relevant System 2 flipped graphics behaviour.

This is genuine additional engineering, not a claim that BAZSET invented the original game's MiSTer support.

## 6. Chrono Soldier — correct encrypted program handling

Additional work checked **MC-8123 317-0040** decryption, ROM layout and banked program fetching against MAME. Together, UFO and Chrono Soldier passed **393,216** tested opcode/data byte comparisons with zero mismatches.

Successful decryption does not yet prove complete MiSTer gameplay.

## 7. Choplifter — investigated the BAD IC 0002 issue

The unprotected Choplifter path received targeted video RAM readback and CPU wait/grant corrections, including thousands of simulated checks.

The original 8751-protected board needs substantially more work on the microcontroller and bus handover; it is not advertised as complete.

## 8. Block Gal — different hardware, different fixes

Block Gal required special treatment rather than being assumed to use identical controls and sound wiring to the other Sega games.

Work covered ROM/key configurations, input addresses, **Z80 PIO** data and control ports, sound-command timing, and video blanking. These were compared with MAME traces.

**Important:** Full PIO execution and the observed black-screen issue are still outstanding. Do not interpret passing individual source tests as a fixed game.

## 9. Other game-specific improvements

- **Dakkochan House:** seven-row Mahjong keyboard/input scanning.
- **Rafflesia:** corrected the unencrypted alternative's program ROM mapping.
- **Shooting Master:** investigated extra sprite banks, light-gun behaviour and 8751-protected CPU requirements; experimental.
- **Noboranka:** separated original protected hardware needs from easier bootleg configurations.
- **Regional and bootleg releases:** expanded ROM ordering, inputs, encrypted/unencrypted selections and alternative game configurations.

## 10. Graphics, scrolling and cocktail display fixes

Several important differences from MAME were traced back to actual FPGA video signals:

- Flipped **horizontal scroll direction** was corrected.
- Flipped **row scrolling** now uses the proper rows.
- Flipped **vertical scrolling** uses the proper source and full nine-bit calculation.
- Game-controlled **sprite orientation** was added to the cocktail display path.
- Sprite rendering and collisions were exercised through realistic synthetic line-buffer tests.

## 11. Correct 240-pixel and 256-pixel picture handling

The FPGA had incorrectly reported a 240-pixel active image as 256 pixels in one video path. That width mismatch was corrected. The scaler was also adjusted to identify the genuine active picture rather than treating the entire 320-dot raster as visible game graphics.

The internal picture-resizing calculation was changed to keep the picture **centred** instead of widening it toward only one side. Experimental sizing controls later removed from B24 are not advertised as active menu features.

## 12. FPGA efficiency and timing improvements

Raster logic was simplified so basic horizontal and vertical line wrapping no longer needed unnecessary division-style hardware. The replacement matched the previous output through **665,856 automated comparisons**, while reducing estimated FPGA logic use.

The B24 project was compiled successfully in Quartus Prime Lite 17.0. Positive *constrained* setup and hold slack was recorded, but external interface timing remains incompletely constrained.

## 13. Better HDMI and retained CRT controls

**HDMI Picture Down** in B24 can reposition the already generated picture downward in two-line steps from **0 to +14**. It does not recover pixels the original raster never generated.

Existing analog CRT H/V positioning and the arcade's native ~60.096 Hz raster timing are retained. The HDMI convenience setting is not a change to the game's native clock.

## 14. MiSTer Shadow Mask integration

The MiSTer Shadow Mask capability acknowledgement was corrected so supported video-processing options can be made available to the core. Source tests passed. Final menu and display verification on real hardware is still pending.

## 15. More high-score and cheat functionality

The enhanced high-score path passed simulated save/restore checks for **64 configured score profiles**, while Dakkochan House still lacks a verified score-memory location.

The new cheat reader supports game-specific **8-bit RAM read/write** modification for the Wonder Boy and Monster Land beta cheat lists. It is **not** a claim of working cheat definitions for every game.

## Development progression

| Milestone | Main accomplishment |
| --- | --- |
| B02–B09 | Sound diagnosis, NMI/ACK corrections, mute polarity and PCM work |
| B11–B13 | Choplifter VRAM timing and Shadow Mask command acknowledgement |
| B14–B16 | Flipped-scroll repairs, UFO and Chrono Soldier encrypted game verification |
| B18–B20 | Correct active video width, centred picture geometry and 240/256 blanking |
| B21 | More efficient raster logic, output-equivalence verified |
| B22–B23 | High scores, cheats, enhanced stereo, cocktail sprite work, expanded game profiles |
| B24 | HDMI Picture Down, RAM-inference repairs, successful FPGA compilation |

## What this public repository contains

Only the **FPGA source and files needed for a Quartus build**, documentation, and original licence/attribution files. It contains **no commercial ROMs, protection-key dumps, game ZIP archives or compiled RBF**.

Game-profile MRAs and legally obtained matching game ROMs are separate from this source-only publication.

## Origins, credit and status

**Based on:** [MiSTer-X / Blackwine Sega System 1/2](https://github.com/blackwine/Arcade-SEGASYS1_MiSTer)

BAZSET builds on their achievements. The original project's GPL v3 licence and the applicable notices of incorporated third-party CPU, sound and MiSTer components are preserved.

**Status: B24 beta/source release.** FPGA compilation and many source/simulation checks passed. Physical MiSTer hardware, gameplay, cheat, high-score and timing verification remain open for some games and options.
