// Copyright (c) 2017,19 MiSTer-X

`define EN_SCPU	(ROMAD[18:15]==4'b000_0) // $0-$7fff

module SEGASYS1_SOUND
(
	input         clk40M,
	input         reset,

	input   [7:0] sndno,
	input         sndstart,
	input         irq_tick,

	output [15:0] sndout,
	output [7:0] psg_stem0,
	output [7:0] psg_stem1,

	input         ROMCL,		// Downloaded ROM image
	input  [24:0] ROMAD,
	input   [7:0] ROMDT,
	input         ROMEN
);


//----------------------------------
//  ClockGen
//----------------------------------
wire clk4M_en,clk2M_en;
SndClkGen clkgen(clk40M,clk4M_en,clk2M_en);


//----------------------------------
//  Z80 (4 MHz, 20 MHz master / 5)
//----------------------------------
wire [15:0] cpu_ad;
wire  [7:0] cpu_di, cpu_do;
wire        cpu_mreq, cpu_iorq, cpu_rd, cpu_wr;
wire            cpu_irq, cpu_nmi;
wire			cpu_irqa, cpu_nmia;

wire cpu_mw, cpu_cs_rom, cpu_cs_ram, cpu_wr_ram, cpu_cs_psg0, cpu_cs_psg1, cpu_cs_com;
// The sound Z80 acknowledges a new 8255 mode-2 command when it READS
// the Port-A command latch at E000-FFFF (MAME sound_data_r -> pc6_w 0,1).
// This is later than its NMI vector fetch at 0066.
wire sndcmd_read_ack = cpu_cs_com && cpu_mreq && cpu_rd;
SndADec adec(
	cpu_mreq, cpu_wr, cpu_mw,
	cpu_ad, cpu_cs_rom, cpu_cs_ram, cpu_wr_ram, cpu_cs_psg0, cpu_cs_psg1, cpu_cs_com
);

Z80IP cpu(
	.clk(clk40M),
	.clk_en(clk4M_en & cpuwait_n),
	.reset(reset),
	.adr(cpu_ad),
	.data_in(cpu_di),
	.data_out(cpu_do),
	.m1(),
	.rfsh(),
	.intreq(cpu_irq),
	.intack(cpu_irqa),
	// 8255 mode2 Port A sound-command OBF handshake pulses NMI.
	// See SndPlayReq: one event per CPU sound command, cleared on E000 read.
	.nmireq(cpu_nmi),
	.nmiack(cpu_nmia),
	.mx(cpu_mreq),
	.ix(cpu_iorq),
	.rd(cpu_rd),
	.wr(cpu_wr),
	.wait_n(1'b1)
);

wire  [7:0]		rom_dt;		// ROM
wire  [7:0]		ram_do;		// RAM
wire  [7:0]		comlatch;	// Sound Command Latch

DLROM #(15,8) subir( clk40M, cpu_ad[14:0], rom_dt, ROMCL,ROMAD,ROMDT,ROMEN & `EN_SCPU );
SRAM_2048 wram( clk40M, cpu_ad[10:0], ram_do, cpu_wr_ram, cpu_do );

dataselector3 scpudisel(
	cpu_di,
	cpu_cs_rom, rom_dt,
	cpu_cs_ram, ram_do,
	cpu_cs_com, comlatch,
	8'hFF
);


SndPlayReq sndreq (
	clk40M, reset,
	sndno, sndstart, irq_tick, sndcmd_read_ack,
	cpu_irq, cpu_irqa, cpu_nmi, cpu_nmia,
	comlatch
);


//----------------------------------
//  PSGs
//----------------------------------
wire [7:0] psg0out, psg1out;
wire       psg0wait, psg1wait;
wire       cpuwait_n = psg0wait & psg1wait;

sn76489_top psg0(
	.clock_i(clk40M),
	.clock_en_i(clk2M_en),
	.res_n_i(~reset),
	.ce_n_i(~(cpu_cs_psg0 & cpu_mreq)),
	.we_n_i(~cpu_wr),
	.d_i(cpu_do),
	.ready_o(psg0wait),
	.aout_o(psg0out)
);

sn76489_top psg1(
	.clock_i(clk40M),
	.clock_en_i(clk4M_en),
	.res_n_i(~reset),
	.ce_n_i(~(cpu_cs_psg1 & cpu_mreq)),
	.we_n_i(~cpu_wr),
	.d_i(cpu_do),
	.ready_o(psg1wait),
	.aout_o(psg1out)
);

assign psg_stem0 = psg0out;
assign psg_stem1 = psg1out;

// Original board does not mix the two PSGs equally: the 2 MHz PSG is attenuated
// before feeding the 4 MHz PSG path. MAME models the analogue balance as 40% / 60%.
// 102/256 and 154/256 closely reproduce that ratio without a divider.
wire [15:0] psg0_scaled = psg0out * 8'd102;
wire [15:0] psg1_scaled = psg1out * 8'd154;
wire [16:0] psg_mix = psg0_scaled + psg1_scaled;
wire [7:0] psgout = psg_mix[15:8];
// 16-bit MiSTer unsigned PCM: scale 8-bit PSG sum into all 16 bits.
// A 7-bit concatenation had halved the output amplitude.
assign sndout = { psgout, 8'h00 };

endmodule


module SndClkGen
(
	input     clk40M,
	output    clk4M_en,
	output    clk2M_en
);

reg [4:0] count = 0;
always @( posedge clk40M ) begin
	count <= count + 1'd1;
	if (count == 19) count <= 0;
end

assign clk2M_en = count == 0;
assign clk4M_en = count == 0 || count == 10;

endmodule


module SndADec
(
	input				cpu_mx,
	input				cpu_wr,

	output			cpu_mw,

	input	 [15:0]	cpu_ad,
	output 			cpu_cs_rom,
	output			cpu_cs_ram,
	output			cpu_wr_ram,
	output			cpu_cs_psg0,
	output			cpu_cs_psg1,
	output			cpu_cs_com
);

assign cpu_mw = cpu_mx & cpu_wr;

assign cpu_cs_rom  = ( cpu_ad[15]    == 1'b0 );
assign cpu_cs_psg0 = ( cpu_ad[15:13] == 3'b101 ); // A000-BFFF SN76489 0
assign cpu_cs_psg1 = ( cpu_ad[15:13] == 3'b110 ); // C000-DFFF SN76489 1
assign cpu_cs_com  = ( cpu_ad[15:13] == 3'b111 ); // E000-FFFF command read

assign cpu_cs_ram  = ( cpu_ad[15:13] == 3'b100 ); // 8000-9FFF, 2K RAM mirrored
assign cpu_wr_ram  = cpu_cs_ram & cpu_mw;

endmodule


//----------------------------------
//  Sound command latch & raster IRQ
//----------------------------------
module SndPlayReq
(
    input          clk,
    input          reset,
    input    [7:0] sndno,
    input          sndstart,
    input          irq_tick,
    input          sndcmd_read_ack,
    output reg     cpu_irq,
    input          cpu_irqa,
    output reg     cpu_nmi,
    input          cpu_nmia,
    output reg [7:0] comlatch
);

// MAME PPI is programmed in 8255 mode2 (control word 0xC0).
// Port A writes assert the /OBF handshake (NMI to sound Z80); a read/ack
// deasserts it. Merely wiring raw Port C bit7 low holds NMI forever and
// prevents a new falling edge for subsequent music/sound commands.
// This is a minimal edge/command-read approximation of mode2 handshake.
// Production SNDRQ is an I/O write strobe, potentially multiple clk40M
// cycles wide, so its RISING edge is the only new-command event.
reg prev_sndstart;
always @(posedge clk or posedge reset) begin
    if (reset) begin
        cpu_irq       <= 1'b0;
        cpu_nmi       <= 1'b0;
        prev_sndstart <= 1'b0;
        comlatch      <= 8'h00;
    end else begin
        prev_sndstart <= sndstart;
        if (cpu_irqa) cpu_irq <= 1'b0;
        if (irq_tick) cpu_irq <= 1'b1;
        // NMI vector acknowledge at 0066 must NOT clear 8255 mode2 /OBF.
        // Clear on the actual E000 sound command read (pc6 strobe in MAME).
        if (sndcmd_read_ack) cpu_nmi <= 1'b0;
        if (sndstart && !prev_sndstart) begin
            comlatch <= sndno;
            cpu_nmi <= 1'b1;
        end
    end
end
endmodule
