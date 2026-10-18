# BAZSET Sega System 1 / System 2 for MiSTer FPGA

**Source-code preview — B24 (13 October 2026)**  
**Platform:** MiSTer FPGA / DE10-Nano  
**Based on:** MiSTer-X's Sega System 1/2 FPGA core, maintained in Blackwine's [Arcade-SEGASYS1_MiSTer](https://github.com/blackwine/Arcade-SEGASYS1_MiSTer) repository.

BAZSET is an extended version of the existing MiSTer Sega System 1/2 arcade core. It retains the original project's foundations while adding numerous improvements to sound handling, video output, game-specific hardware support, controls, high-score handling and optional quality-of-life features.

The goal is to reproduce the Sega arcade hardware faithfully while offering useful *optional* MiSTer features that do not change how the games run.

**Important:** This is a **source-only project**, not a ROM download or a claim that every listed game has passed hardware testing.

**[Read the full layman's summary of all 15 major areas of development → RELEASE_NOTES.md](RELEASE_NOTES.md)**

## The biggest changes at a glance

- **Wonder Boy improvements:** corrected 2-way control description in associated game profiles, added a five-cheat beta feature set, improved Player 2/cocktail sprite flipping, and added high-score save/restore support.
- **Wonder Boy in Monster Land improvements:** English decrypted game-profile option, seven game-specific beta cheats, high-score configuration, optional enhanced stereo, and a new HDMI picture-position option useful for displays cropping the top of the score area.
- **Major sound-system work:** investigated the original missing/cut-out audio problem, corrected the System 2 sound-command/NMI handshake and address handling, retained authentic System 2 mute polarity, improved PCM handling, and added **optional enhanced stereo** while keeping the original mono sound as the default.
- **Better graphics and screen-flip behaviour:** fixes to System 2 flipped horizontal and vertical scrolling, row-scroll selection and the sprite flip path used by cocktail mode.
- **Better video handling:** corrected the difference between 240- and 256-pixel-wide games, fixed how the internal video processing centres and handles active pixels, and made raster generation less resource-intensive.
- **New HDMI Picture Down option:** move the *existing* game image down by 0, 2, 4, 6, 8, 10, 12 or 14 lines without changing the game's clocks or native picture.
- **More game versions:** the private B23/B24 beta distribution was assembled with **65 MRA configurations** for 26 main selections, 32 alternatives, four bootlegs and three experimental protected selections. These are configurations/versions, **not 65 separate games** or 65 proven working games.
- **Game-specific engineering:** additional work for UFO Senshi Yohko Chan, Toki no Senshi: Chrono Soldier, Choplifter, Block Gal, Dakkochan House and multiple alternative or unencrypted releases.
- **Cheats and high scores:** a game-memory cheat engine with read/write support and more comprehensive high-score testing. Not every game has cheats; save/restore still requires real MiSTer testing.
- **More dependable builds:** the B24 FPGA image was successfully compiled with Quartus Prime Lite 17.0 and positive *constrained* timing margins. Some external interfaces remain unconstrained; this is not a complete hardware certification.

## Wonder Boy: what changed?

The original **Wonder Boy** is a particular focus of this project.

1. **Controls:** associated MRA definitions were corrected from a four-way joystick description to **two-way left/right**, as specified by MAME. This changes the metadata, not the electrical joystick inputs.
2. **Five optional beta cheats:** Infinite Lives, Full Vitality, Invincibility, Keep Axe and Keep Skateboard. The cheats were checked against real MAME memory behaviour and simulated against the core's cheat hardware. They still need physical MiSTer gameplay confirmation.
3. **High scores:** additional game-specific score handling was included and checked in simulated save-and-restore tests. Actual SD-card persistence and cold reboot behaviour still need testing.
4. **Player 2 / cocktail cabinets:** added cabinet-selection settings in the associated Wonder Boy MRAs and wired game-controlled flipping through the sprite renderer. This is intended to fix previously incomplete sprite orientation when play changes sides; exact real-PCB behaviour still needs comparison.
5. **Graphics:** gains the System 1/2 fixes to scrolling, sprite/render paths, native picture width and video timing.
6. **Sound:** original two-chip mono is preserved, with optional wider stereo separation.
7. **Game versions:** seven Wonder Boy MRA configurations were staged and ROM-structure-checked for the private beta distribution; these are not all confirmed in gameplay.

**Credit where due:** Blackwine/MiSTer-X's earlier implementation already contained substantial Sega support, including the original Wonder Boy sprite-wobble correction. BAZSET builds on that work; it does not claim to have invented every original fix.

## Wonder Boy in Monster Land: what changed?

- The private main-game profile prioritises the **English Virtual Console-derived decrypted version**, rather than claiming every original encrypted board version is interchangeable.
- **Seven optional beta cheats:** Infinite Time, Infinite Gold, Infinite Pills, Always Key, Legend Sword, Legend Armour and Legend Boots.
- The sound path was investigated extensively because early test builds displayed gameplay but had missing or interrupted sound.
- The original **two SN76489-family sound chips** are kept, with their 40/60 mono mix and an optional enhanced stereo presentation.
- **HDMI Picture Down** provides a non-destructive way to reposition the visible picture. It cannot recover score/HUD pixels that were already outside the original arcade visible region.
- Work on System 2 flip and scrolling behaviour benefits Monster Land alongside the rest of the family.
- Five Monster Land MRA configurations were staged in the private beta; protected originals and some alternatives still need game-by-game verification.

## Expanded game and ROM-configuration work

Blackwine's published core already listed a number of these games. BAZSET's changes are **additional fixes, verification and configuration work**, not an assertion that every title was newly introduced.

| Game or group | What was changed or investigated | Current confidence |
| --- | --- | --- |
| **UFO Senshi Yohko Chan** | Added/corrected its game-profile ROM layout and MC-8123 317-0064 decryption path; checked fixed and banked program data against MAME; checked its three action buttons and System 2 input handling. | Decryption and input HDL tests passed; full MiSTer boot/audio/gameplay not yet certified. |
| **Toki no Senshi: Chrono Soldier** | Corrected its encrypted fixed/banked program loading using MC-8123 317-0040 and checked against MAME reference bytes. | Decryption tests passed; full MiSTer gameplay not yet certified. |
| **Choplifter** | Investigated the startup **BAD IC 0002** error; added narrowly scoped video-RAM readback/wait handling for the unprotected version. Researched the original protected 8751 controller separately. | RAM timing tests passed; cold-boot fix needs hardware proof. Original 8751-protected version remains incomplete. |
| **Block Gal** | Reworked the protected-program key/ROM assembly, game-specific input addresses, Z80 PIO-related writes and sound-command timing to better reflect the original board. | Source-level results improved, but full PIO emulation and the known black-screen issue remain unresolved. |
| **Dakkochan House** | Developed seven-row Mahjong-keyboard scanning and input selection support. | Input simulations passed; real controls and high-score storage still need verification. |
| **Rafflesia (unencrypted)** | Corrected the unencrypted US alternative's program-ROM selection instead of accidentally feeding it the encrypted parent program. | ROM assembly verified; MiSTer boot remains unverified. |
| **Shooting Master** | Researched its true ROM layout, extra sprite banks, light-gun controls and 8751 protection requirements. | Experimental only. Required protected MCU execution and extra sprite support are not complete. |
| **Noboranka and other protected boards** | Identified differences between original protected boards and simpler bootlegs or unprotected versions. | Original protected versions are not guaranteed working. |
| **More regional sets / bootlegs** | Expanded MRA variants, game-specific ROM ordering, decryption modes, inputs and English/US-first presentation. | ROM assembly checks passed; variants require individual gameplay testing. |

For **Chrono Soldier and UFO Senshi Yohko Chan**, a combined **393,216 fixed-and-banked opcode/data comparisons** matched MAME in the source audit, with zero differences. This is unusually thorough ROM-decryption verification, but it is **not** the same as playing either game through to completion on MiSTer.

## Additional sound improvements

The sound system received several separate rounds of engineering, not just a stereo switch.

- Corrected how System 2's **8255 sound-command handshake** triggers and acknowledges a sound-CPU NMI. Earlier builds could send an NMI at the wrong time or fail to retrigger commands.
- Preserved the **System 2-specific sound-mute polarity** shown by MAME. An earlier experimental change to this polarity was rejected rather than being carried into the final source.
- Improved sound-CPU command readback and relevant address mirroring.
- Retained the two independent SN76489 sound sources running at the expected **2 MHz and 4 MHz**.
- Improved PCM output interpretation and verified the original two-chip **40%/60% mono balance**.
- Added optional, smoothly applied stereo separation. **Off** is the original mono presentation.
- Tested real Z80 plus both sound-chip models against Wonder Boy in Monster Land sound-ROM and MAME activity; the initial **28 PSG register writes matched**. Complete waveform accuracy and sound quality on a real MiSTer still require listening tests.

## Additional graphics and video improvements

- **Flipped row scrolling:** corrected which background-scroll rows are read when the game flips its display.
- **Flipped vertical scrolling:** corrected the source register and retained the full nine-bit scrolling calculation.
- **Flipped horizontal scrolling:** fixed the background movement direction in System 2's flipped mode.
- **Cocktail sprites:** added the missing game-controlled horizontal/vertical sprite flip path and ran extensive synthetic rendering/collision checks.
- **240-pixel games:** fixed a mismatch where the output logic described a 240-pixel picture as 256 pixels wide, affecting later video processing.
- **Video resampling:** updated internal logic to detect the real active picture width, not assume the entire 320-pixel line contains game graphics.
- **Picture centring:** corrected an earlier sizing calculation that expanded the picture toward one side rather than around its centre. Experimental V3 sizing controls were later removed from the B24 on-screen menu; their presence should not be advertised as a current user-facing feature.
- **Raster efficiency:** replaced unnecessary division-style operations with simpler line/frame wrap logic; output was compared against the older implementation across **665,856** checks with identical results and reduced estimated FPGA logic use.
- **Shadow Mask integration:** corrected the MiSTer capability acknowledgement so supported Shadow Mask processing can be made available; actual display-menu behaviour still needs hardware confirmation.
- **Native video:** keeps the original 320 × 260 raster structure at approximately **60.096 Hz** rather than changing game timing to a forced 60.000 Hz.
- **HDMI picture adjustment (B24):** adjustable 0 to +14-line downward presentation, switched at frame boundaries; bypassed in Direct Video mode. The original game pixels and clocks are unchanged.

## High scores and cheat support

The existing score-save system was extended and audited for more game profiles. **64 configured score profiles out of 65 staged game configurations** passed simulated save/restore and invalid-initialisation tests. **Dakkochan House** has no verified score-table location and should not be represented as supported. Real SD-card save, cold reset and reload are still outstanding.

The cheat system now handles supported **8-bit work-RAM reads and writes**, rather than relying only on memory reads. This matters because some games rarely read the value being frozen. The Wonder Boy and Monster Land beta cheats were checked against authentic MAME cheat references. The system deliberately does not claim universal support for all 65 game profiles or unsupported 16-/32-bit codes. Cheat definitions were part of private game-profile MRAs, not embedded game ROMs.

## Development milestones

| Milestone | Main progress |
| --- | --- |
| **B02–B09** | Sound diagnosis, correct System 2 mute behaviour, sound-command NMI/ACK timing, memory-map and PCM work; obsolete experiments removed. |
| **B11–B13** | Choplifter VRAM timing investigation, Shadow Mask handshake, initial expanded beta packaging. |
| **B14–B16** | Correct flipped row/Y/X scrolling; added and extensively audited Chrono Soldier and UFO Senshi Yohko Chan configurations. |
| **B18–B20** | Active-width-aware video, centred geometry handling and corrected 240/256-pixel blanking. |
| **B21** | Lower-resource raster timing with identical output under exhaustive comparison. |
| **B22–B23** | Broader game-profile support, sound stereo option, cheats, high scores, cocktail sprites and special-game investigations; verified source and built beta FPGA release. |
| **B24** | Added HDMI Picture Down option, corrected FPGA RAM inference, finished another successful Quartus build and release-package audit. |

## Building the FPGA core

This repository contains the **complete staged Quartus source project** for B24, including the MiSTer wrapper and required FPGA HDL support files. It does **not** contain ROMs, MC-8123 key dumps, protected-game MCU ROMs, game archives, compiled FPGA bitstreams, or private test captures.

**Required software:** Intel Quartus Prime Lite **17.0** (the recorded reference build used 17.0.2 Lite), with support for the DE10-Nano Cyclone V **5CSEBA6U23I7**.

From the repository's root directory:

```sh
quartus_sh --flow compile Arcade-SEGASYS1
```

On successful completion, the generated RBF should be in:

```text
output_files/Arcade-SEGASYS1.rbf
```

The B24 reference build completed with **0 Quartus errors**, worst constrained setup slack **+0.741 ns**, and hold slack **+0.218 ns**. **These are reference build results, not a fresh compilation of this public-review copy**, and some external port/clock constraints remain incomplete.

Game selection on MiSTer also requires compatible **MRA game-profile definitions** and ROMs supplied by the user. To honour the request for **core-source only**, this preview does **not** bundle the private beta's 65 MRAs; they can be considered separately for a future, ROM-free repository addition.

## Project status and known limitations

**Completed:** actual B24 RBF compilation, source-code staging, scripted FPGA verification of multiple subsystems, and previous private release-package audits.

**Not yet certified:** full physical MiSTer game-by-game testing; HDMI Picture Down on different displays; all 65 game configurations; real high-score persistence; Wonder Boy cocktail mode on real hardware; beta cheats during real gameplay; authentic analog sound comparison; external interface timing constraints.

**Known incomplete or experimental:** Block Gal protected boot; original 8751-protected Choplifter; Shooting Master gun/sprite/MCU path; certain Noboranka/protected sets; Dakkochan House high-score mapping; exact arcade-board colour/sprite-priority details.

A verified ROM layout or passing simulator test does **not** establish that a game boots and plays correctly on real hardware.

## ROMs, licences and credit

**No commercial arcade ROMs or protection-key dumps are distributed with this source.** Game names are used solely to describe compatible arcade hardware.

This is a derivative of **MiSTer-X's** original Sega System 1/2 MiSTer FPGA core as published by **Blackwine**. Credit also goes to the MiSTer project and the authors of incorporated T80 Z80, SN76489 and other reusable FPGA modules.

- Original project: https://github.com/blackwine/Arcade-SEGASYS1_MiSTer
- The upstream project includes the **GNU GPL v3** licence, retained as `LICENSE` here.
- Individual incorporated components retain their original copyright notices and applicable licence terms (including the SN76489 component's notice and `COPYING` file).
- **BAZSET additions and modifications:** engineering and source updates developed through October 2026. This branch is distinctly marked as a modified version, not an official upstream or MiSTer-X release.

This project is provided **as-is**, without warranty. Contributors are welcome to report reproducible bugs, ideally with an exact game revision, FPGA build version and screenshots or test recordings.

