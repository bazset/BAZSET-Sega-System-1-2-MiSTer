// Copyright (c) 2017,19 MiSTer-X

`define EN_MCPU0_PRG (ROMAD[18:15]==4'b000_1)		// $08000-$0ffff
`define EN_MCPU0_OPS (ROMAD[18:15]==4'b110_0)		// $60000-$67fff
`define EN_MCPU8_PRG (ROMAD[18:16]==3'b001)		// $10000-$1ffff
`define EN_KEY       (ROMAD[18:13]==6'b101_101) 	// $5a000-$5bfff


module SEGASYS1_MAIN
(
	input				CLK40M,

	input				RESET,

	input   [7:0]	INP0,
	input   [7:0]	INP1,
	input   [7:0]	INP2,

	input   [7:0]	DSW0,
	input   [7:0]	DSW1,
	input           system2,
	input   [7:0]   quirks,
	input           choplift_vram_wait_fix,

	input				VBLK,
	input   [8:0]   PH,
	input           PCLK_EN,
	input				VIDCS,
	input   [7:0]	VIDDO,
	output [15:0]	CPUAD,
	output  [7:0]	CPUDO,
	output		  	CPUWR,

	output reg		  SNDRQ,
	output reg [7:0] SNDNO,

	output reg [7:0] VIDMD,
	output reg [7:0] SNDCTL,

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
);

`include "quirks.vh"

// The PCB clocks the Z80 from 20 MHz through an LS161 divider.
// Normal cycles divide by 5 (4 MHz). During /M1 opcode fetches the divider
// reload changes and fetches take 2 extra 20 MHz clocks. MAME models this
// as one extra 4 MHz CPU cycle on 2 of every 5 opcode fetches.
wire cpu_m1;
wire cpu_rfsh;
wire cpu_mreq, cpu_iorq;
wire _cpu_rd, _cpu_wr;
wire [15:0] cpu_ad;

reg [3:0] cpu_div = 0;
reg [2:0] m1_phase = 0;
reg       stretch_m1 = 0;
reg       last_rfsh = 0;
wire CPU4M_EN = (cpu_div == 0);

always @(posedge CLK40M or posedge RESET) begin
	if (RESET) begin
		cpu_div <= 0;
		m1_phase <= 0;
		stretch_m1 <= 0;
		last_rfsh <= 0;
	end else begin
		if (cpu_div == 4'd9)
			cpu_div <= 0;
		else
			cpu_div <= cpu_div + 1'd1;

		last_rfsh <= cpu_rfsh;
		if (cpu_rfsh && !last_rfsh) begin
			// Match MAME adjust_cycles(): phase = (phase + 2) % 5.
			case (m1_phase)
				0: begin m1_phase <= 2; stretch_m1 <= 0; end
				1: begin m1_phase <= 3; stretch_m1 <= 0; end
				2: begin m1_phase <= 4; stretch_m1 <= 0; end
				3: begin m1_phase <= 0; stretch_m1 <= 1; end
				default: begin m1_phase <= 1; stretch_m1 <= 1; end
			endcase
		end else if (CPU4M_EN && stretch_m1)
			stretch_m1 <= 0;
	end
end

wire			AXSCL   = CLK40M;
wire      CPUCL_EN = CPU4M_EN & ~stretch_m1;

// VRAM accesses halt the Z80 until FIXST, once every four 5 MHz pixels.
wire vram_access = cpu_mreq && (CPUAD[15:12] == 4'he);
wire fixst = PCLK_EN && (PH[1:0] == 2'b00);
reg  vram_grant = 0;
always @(posedge CLK40M or posedge RESET) begin
	if (RESET)
		vram_grant <= 0;
	else begin
		if (vram_access && fixst)
			vram_grant <= 1;
		else if (!vram_access || (!choplift_vram_wait_fix && CPU4M_EN && vram_grant))
			vram_grant <= 0;
	end
end
wire cpu_wait_n = PAUSE_N && (!vram_access || vram_grant);

wire  [7:0]	CPUDI;

// Invert address lines for Noboranka aka Zippy Bug
assign CPUAD = (quirks == NOBORANKA) && (cpu_ad[15:14] == 2'b11) && (cpu_ad[13] == cpu_ad[12]) ?
               cpu_ad ^ 16'h3000 :
               cpu_ad;

Z80IP maincpu(
	.reset(RESET),
	.clk(CLK40M),
	.clk_en(CPUCL_EN),
	.adr(cpu_ad),
	.data_in(CPUDI),
	.data_out(CPUDO),
	.m1(cpu_m1),
	.rfsh(cpu_rfsh),
	.mx(cpu_mreq),
	.ix(cpu_iorq),
	.rd(_cpu_rd),
	.wr(_cpu_wr),
	.intreq(VBLK),
	.nmireq(1'b0),
	.wait_n(cpu_wait_n)
);

assign CPUWR = _cpu_wr & cpu_mreq;

// Input Port
wire       cpu_cs_port;
wire [7:0] cpu_rd_port;
SEGASYS1_IPORT port(CPUAD,cpu_iorq, INP0,INP1,INP2, DSW0,DSW1, (quirks == BLOCK_GAL), cpu_cs_port,cpu_rd_port);


// Program ROM
wire cpu_cs_mrom0 = (CPUAD[15]    == 1'b0 ) & cpu_mreq;
wire cpu_cs_mrom8 = (CPUAD[15:14] == 2'b10) & cpu_mreq;

wire  [7:0]  cpu_rd_mrom0_prg;
wire  [7:0]  cpu_rd_mrom0_ops;
wire  [7:0]  cpu_rd_mrom8;
wire  [7:0]  cpu_rd_mc8123;

wire [14:0]  rad;
wire  [7:0]  rdt;

wire [12:0]  key_a;
wire  [7:0]  key_d;

// CPU Region $0000-$7fff ROM
// Separate rom for games with decrypted opcodes
DLROM #(15,8) rom0_prg(CLK40M, has_mc8123_key ? CPUAD : rad, rdt, ROMCL,ROMAD,ROMDT,ROMEN & `EN_MCPU0_PRG);
DLROM #(15,8) rom0_ops(CLK40M, CPUAD, cpu_rd_mrom0_ops, ROMCL,ROMAD,ROMDT,ROMEN & `EN_MCPU0_OPS);

// CPU Region $8000-$bfff, 4 ROM banks
// No BRAM for separate opcode memory banks, they may be not needed though
wire [1:0] cpu_bank = {system2 ? VIDMD[3] : VIDMD[6],VIDMD[2]};
DLROM #(16,8) rom8_prg(CLK40M, {cpu_bank,CPUAD[13:0]}, cpu_rd_mrom8, ROMCL,ROMAD,ROMDT,ROMEN & `EN_MCPU8_PRG);

// 315-5xxx CPU decryption for selected SEGA System 1 titles
SEGASYS1_PRGDEC decr(AXSCL,cpu_m1,CPUAD,cpu_rd_mrom0_prg, rad,rdt, ROMCL,ROMAD,ROMDT,ROMEN);

// MC-8123 CPU decryption for selected SEGA System 2 titles
MC8123_rom_decrypt mc8123_decrypt(CLK40M, cpu_m1, CPUAD, cpu_rd_mc8123,
                                 !CPUAD[15] ? rdt : cpu_rd_mrom8, key_a, key_d);
DLROM #(13,8) rom_keys(CLK40M, key_a, key_d,
                       ROMCL, ROMAD, ROMDT, ROMEN & `EN_KEY);

// ROM loading is game-specific. Clear the key/opcode mode on the first
// byte of a NEW ROM stream; preserve it across ordinary user soft resets.
reg has_opcode_roms = 0;
reg has_mc8123_key = 0;
wire fresh_rom_stream = ROMEN && (ROMAD == 25'd0);
always @(posedge CLK40M) begin
    if (fresh_rom_stream) begin
        has_opcode_roms <= 1'b0;
        has_mc8123_key <= 1'b0;
    end else begin
        if (ROMEN && `EN_MCPU0_OPS && (ROMDT != 8'h00))
            has_opcode_roms <= 1'b1;
        if (ROMEN && `EN_KEY && (ROMDT != 8'h00))
            has_mc8123_key <= 1'b1;
    end
end

// Work RAM
wire [7:0]	cpu_rd_mram;
wire [7:0] cheat_write_mram;
wire			cpu_cs_mram = (CPUAD[15:12] == 4'b1100) & cpu_mreq;

//SRAM_4096 mainram(CLK40M, CPUAD[11:0], cpu_rd_mram, cpu_cs_mram & CPUWR, CPUDO );
/*
	input					clk,
	input	    [11:0]	adrs,
	output reg [7:0]	out,
	input					wr,
	input		  [7:0]	in
*/

dpram #(.aWidth(12),.dWidth(8))
mainram(
	.clk_a(CLK40M),
	.addr_a(CPUAD[11:0]),
	.we_a(cpu_cs_mram & CPUWR),
	.d_a(cheat_write_mram), // freeze enabled cheat values only on C000-CFFF work RAM writes
	.q_a(cpu_rd_mram),

	.clk_b(CLK40M),
	.addr_b(HSAD[11:0]),
	.we_b(HSWE),
	.d_b(HSDI),
	.q_b(HSDO)
);

// Video mode latch & Sound Request
// Block Gal uses the Z80 PIO at 0x18-0x1B, not the older 8255 at
// 0x14-0x17. MAME sys1pio() removes the 8255; do not let Block Gal's
// startup writes to unmapped 0x14-0x16 mutate video/sound latches.
// Other games keep their established legacy decode unchanged.
wire blockgal_pio = (quirks == BLOCK_GAL);
wire cpu_cs_sreq = (((CPUAD[7:0] == 8'h14) && !blockgal_pio) ||
                     (CPUAD[7:0] == 8'h18)) & cpu_iorq;
wire cpu_cs_vidm = (((CPUAD[7:0] == 8'h15) && !blockgal_pio) ||
                     (CPUAD[7:0] == 8'h19)) & cpu_iorq;
wire cpu_cs_sctl = (CPUAD[7:0] == 8'h16) & cpu_iorq & !blockgal_pio;

// Block Gal's Z80 PIO Port A is INPUT on reset. An early OUT (18h),00h
// happens before OUT (1Ah),8Fh switches it to bidirectional output.
// MAME's input-mode data write does not call the sound-command callback.
// Guard only Block Gal's sound strobe; preserve all existing PPI/other games.
reg blockgal_porta_output_enabled = 1'b0;
always @(posedge CLK40M or posedge RESET) begin
    if (RESET)
        blockgal_porta_output_enabled <= 1'b0;
    else if (!blockgal_pio)
        blockgal_porta_output_enabled <= 1'b0;
    else if (cpu_iorq && _cpu_wr &&
             (CPUAD[7:0] == 8'h1a) && (CPUDO[3:0] == 4'hf))
        blockgal_porta_output_enabled <= (CPUDO[7:6] != 2'b01);
end

// noboronka bootleg protection ports
wire cpu_cs_1c = (CPUAD[7:0] == 8'h1c) & cpu_iorq;
wire cpu_cs_22 = (CPUAD[7:0] == 8'h22) & cpu_iorq;
wire cpu_cs_23 = (CPUAD[7:0] == 8'h23) & cpu_iorq;
wire cpu_cs_24 = (CPUAD[7:0] == 8'h24) & cpu_iorq;

wire cpu_wr_sreq = cpu_cs_sreq & _cpu_wr & (!blockgal_pio || blockgal_porta_output_enabled);
wire cpu_wr_vidm = cpu_cs_vidm & _cpu_wr;
wire cpu_wr_sctl = cpu_cs_sctl & _cpu_wr;

reg [7:0] nobb_protection;

always @(posedge CLK40M or posedge RESET) begin
	if (RESET) begin
		VIDMD <= 0;
		SNDRQ <= 0;
		SNDNO <= 0;
		// System 2 PPI PC7 idles high (sound NMI clear); PC0 low is muted after inversion.
		SNDCTL <= system2 ? 8'h80 : 8'h00;
		nobb_protection <= 0;
	end
	else begin
		if (cpu_wr_vidm)
			VIDMD <= CPUDO;
		if (cpu_wr_sctl)
			SNDCTL <= CPUDO;
		SNDRQ <= cpu_wr_sreq;
		if (cpu_wr_sreq)
			SNDNO <= CPUDO;

		if (cpu_cs_24 & _cpu_wr)
			nobb_protection <= CPUDO;
	end
end


// CPU data selector; cheat substitution affects CPU READ values only.
wire [7:0] cpu_data_raw;
bazset_cheat_reader8 #(.MAX_CODES(32)) cheats(
  .clk(CLK40M),.clear(CHEAT_CLEAR),.code(CHEAT_CODE),
  .enable(1'b1),.cpu_memory_read(_cpu_rd && cpu_mreq),
  .cpu_opcode_fetch(cpu_m1),.cpu_address(CPUAD),
  .cpu_data_in(cpu_data_raw),.cpu_data_out(CPUDI),
  .cpu_memory_write(cpu_cs_mram && CPUWR),
  .cpu_write_data_in(CPUDO),.cpu_write_data_out(cheat_write_mram),.available()
);
dataselector10 mcpudisel(
	cpu_data_raw,
	VIDCS & cpu_mreq, VIDDO,
	cpu_cs_1c, 8'h80,
	cpu_cs_22, 8'h00,
	cpu_cs_23, nobb_protection,
	cpu_cs_vidm, VIDMD,
	cpu_cs_sctl, SNDCTL,
	cpu_cs_port, cpu_rd_port,
	cpu_cs_mram, cpu_rd_mram,
	cpu_cs_mrom0, has_mc8123_key ? cpu_rd_mc8123 : (has_opcode_roms & cpu_m1) ? cpu_rd_mrom0_ops : cpu_rd_mrom0_prg,
	cpu_cs_mrom8, has_mc8123_key ? cpu_rd_mc8123 : cpu_rd_mrom8,
	8'hFF
);

endmodule


module SEGASYS1_IPORT
(
	input [15:0]	CPUAD,
	input				CPUIO,

	input  [7:0]	INP0,
	input  [7:0]	INP1,
	input  [7:0]	INP2,

	input  [7:0]	DSW0,
	input  [7:0]	DSW1,
	input            blockgal_io, // exact MAME Block Gal PIO DIP map

	output			DV,
	output [7:0]	OD
);

wire cs_port1 =  (CPUAD[4:2] == 3'b0_00) & CPUIO;
wire cs_port2 =  (CPUAD[4:2] == 3'b0_01) & CPUIO;
wire cs_portS =  (CPUAD[4:2] == 3'b0_10) & CPUIO;
// Most System 1 boards read SWA at 0x0C and SWB at 0x0D/0x10.
// MAME blockgal_io_map explicitly unmaps 0x0C and reads SWA at 0x0D;
// 0x10 remains SWB. Apply ONLY when the Block Gal quirk is selected.
wire cs_portA = (CPUAD[4:2] == 3'b0_11) & (CPUAD[0] == blockgal_io) & CPUIO;
wire cs_portB = ((((CPUAD[4:2] == 3'b0_11) & CPUAD[0] & ~blockgal_io)) |
                  (CPUAD[4:2] == 3'b1_00)) & CPUIO;

wire [7:0] inp;
dataselector5 dsel(
	inp,
	cs_port1,INP0,
	cs_port2,INP1,
	cs_portS,INP2,
	cs_portA,DSW0,
	cs_portB,DSW1,
	8'hFF
);

assign DV = cs_port1|cs_port2|cs_portS|cs_portA|cs_portB;
assign OD = inp;

endmodule

