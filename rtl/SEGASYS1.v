/********************************************************************
        FPGA Implementation of SEGA System 1,2 (Top Module)

											Copyright (c) 2017,19 MiSTer-X
*********************************************************************/
module SEGASYSTEM1
(
	input				clk40M,
	input				reset,

	input   [7:0]	INP0,
	input   [7:0]	INP1,
	input   [7:0]	INP2,

	input   [7:0]	DSW0,
	input   [7:0]	DSW1,

	input   system2,
	input   debug_audio_unmute, // beta diagnosis only; default OFF
	input   choplift_vram_wait_fix, // MRA opt-in for stable E000-EFFF readback
	input   rowscroll,
	input   [7:0]  quirks,

	output  mux_clock,

	input   [8:0]  PH,         // PIXEL H
	input   [8:0]  PV,         // PIXEL V
	output        PCLK_EN,
	output  [11:0]	POUT, 	   // PIXEL OUT

	output  [15:0] SOUT,			// Sound Out (PCM)
	output  [7:0] PSG0_STEM,
	output  [7:0] PSG1_STEM,

	input				ROMCL,		// Downloaded ROM image
	input   [24:0]	ROMAD,
	input	  [7:0]	ROMDT,
	input				ROMEN,

	input 			PAUSE_N,
	input  [15:0]	HSAD,
	output [7:0]	HSDO,
	input  [7:0]	HSDI,
	input				HSWE,
	input [128:0] CHEAT_CODE,
	input CHEAT_CLEAR

	,input show_banks
	,input flip_screen
	,input [2:0] test1
	,input [2:0] test2
	,input [2:0] test3
	,input [2:0] test4
	);

`include "quirks.vh"

// Legacy Sega System 1/2 ROM decoders use only ROMAD[18:xx].
 // Ignore extension data above 0x7ffff: reserved for future protected-board
 // MCU and additional sprite ROMs, otherwise upper ROM bytes alias CPU/sound.
wire rom_legacy_enable = ROMEN && (ROMAD[24:19] == 6'b000000);

// CPU
wire [15:0] CPUAD;
wire  [7:0] CPUDO,VIDDO,SNDNO,VIDMD,SNDCTL;
wire			CPUWR,VIDCS,VBLK;
wire			SNDRQ;

assign mux_clock = VIDMD[1];

// HISCORE MUX
wire [7:0]	HSDO_MAIN;
wire [7:0]	HSDO_VIDEO;
wire			HSWE_MAIN;
wire			HSWE_VIDEO;

// Sega System 1 Noboranka bootleg: MAME nobo_map places work RAM at
// F000-FFFF. Its normal Z80 CPU remapper XORs 0x3000 to reach C000 BRAM.
// Route highscore address Fxxx to the same BRAM port when quirk 1 is active.
assign HSWE_MAIN = (HSAD[15:12] == 4'b1100) ||
                   ((quirks == NOBORANKA) && (HSAD[15:12] == 4'b1111));
assign HSWE_VIDEO = ~HSWE_MAIN;
assign HSDO = HSWE_MAIN ? HSDO_MAIN : HSDO_VIDEO;

SEGASYS1_MAIN Main (
	.CLK40M(clk40M),
	.RESET(reset),
	.INP0(INP0),.INP1(INP1),.INP2(INP2),
	.DSW0(DSW0),.DSW1(DSW1),
	.choplift_vram_wait_fix(choplift_vram_wait_fix),
	.system2(system2),
	.quirks(quirks),
	.CPUAD(CPUAD),.CPUDO(CPUDO),.CPUWR(CPUWR),
	.VBLK(VBLK),.PH(PH),.PCLK_EN(PCLK_EN),.VIDCS(VIDCS),.VIDDO(VIDDO),
	.SNDRQ(SNDRQ),.SNDNO(SNDNO),
	.VIDMD(VIDMD),.SNDCTL(SNDCTL),
	
	.ROMCL(ROMCL),.ROMAD(ROMAD),.ROMDT(ROMDT),.ROMEN(rom_legacy_enable),
	
	.PAUSE_N(PAUSE_N),
	.HSAD(HSAD),.HSDO(HSDO_MAIN),.HSDI(HSDI),.HSWE(HSWE_MAIN & HSWE),
	.CHEAT_CODE(CHEAT_CODE),.CHEAT_CLEAR(CHEAT_CLEAR)
);

// Video
wire [11:0] OPIX;
SEGASYS1_VIDEO Video (
	.RESET(reset),.VCLKx8(clk40M),
	.PH(PH),.PV(PV),.VFLP(VIDMD[7]),
	.VBLK(VBLK),.PCLK_EN(PCLK_EN),.RGB(OPIX),
	.vram_bank(system2 ? SNDCTL[2:1] : 2'd0),
	.system2(system2),.rowscroll(rowscroll),.PALDSW(1'b0),

	.cpu_ad(CPUAD),.cpu_wr(CPUWR),.cpu_dw(CPUDO),
	.cpu_rd(VIDCS),.cpu_dr(VIDDO),

	.ROMCL(ROMCL),.ROMAD(ROMAD),.ROMDT(ROMDT),.ROMEN(rom_legacy_enable),

	.PAUSE_N(PAUSE_N),
	.HSAD(HSAD),.HSDO(HSDO_VIDEO),.HSDI(HSDI),.HSWE(HSWE_VIDEO & HSWE)
);
assign POUT = VIDMD[4] ? 12'd0 : OPIX;

// Sound. The board IRQs the sound CPU on scanlines 32,96,160,224.
wire snd_irq_tick = PCLK_EN && (PH == 0) && (PV[5:0] == 6'd32);
wire [15:0] SOUT_RAW;
wire [7:0] PSG0_RAW, PSG1_RAW;
SEGASYS1_SOUND Sound(
	clk40M, reset, SNDNO, SNDRQ, snd_irq_tick, SOUT_RAW, PSG0_RAW, PSG1_RAW,
	ROMCL, ROMAD, ROMDT, rom_legacy_enable
);

// MAME system1.cpp sound_control_w passes PC0 directly to system_mute(data & 1).
// Both System 1 and System 2: 0 = audible, 1 = mute.
// Previously inverting on System 2 silenced every game that left PC0 low.
// MAME system1.cpp sys2() XORs PC0 BEFORE invoking sound_control_w.
// Sys2: raw PPI PC0=1 -> sound ENABLED; System1: raw PC0=0 -> enabled.
wire sound_mute = system2 ? ~SNDCTL[0] : SNDCTL[0];
assign SOUT = (sound_mute && !debug_audio_unmute) ? 16'd0 : SOUT_RAW;
assign PSG0_STEM = (sound_mute && !debug_audio_unmute) ? 8'd0 : PSG0_RAW;
assign PSG1_STEM = (sound_mute && !debug_audio_unmute) ? 8'd0 : PSG1_RAW;

endmodule

