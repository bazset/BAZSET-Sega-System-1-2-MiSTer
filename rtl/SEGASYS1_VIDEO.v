// Copyright (c) 2017,19 MiSTer-X

`define EN_SPRITE (ROMAD[18:17]==2'b01)		// $20000-$3FFFF

`define EN_TILE00 (ROMAD[18:14]==6'b100_00)	// $40000-$43FFF
`define EN_TILE10 (ROMAD[18:14]==6'b100_01)	// $44000-$47FFF
`define EN_TILE01 (ROMAD[18:14]==6'b100_10)	// $48000-$4bFFF
`define EN_TILE11 (ROMAD[18:14]==6'b100_11)	// $4c000-$4fFFF
`define EN_TILE02 (ROMAD[18:14]==6'b101_00)	// $50000-$53FFF
`define EN_TILE12 (ROMAD[18:14]==6'b101_01)	// $54000-$57FFF

`define EN_CLUT	(ROMAD[18:8]==11'b101_1000_0000)// $58000-$580FF


module SEGASYS1_VIDEO
(
	input				RESET,

	input				VCLKx8,

	input		[8:0]	PH,
	input		[8:0]	PV,
	input				VFLP,

	output			VBLK,
	output			PCLK_EN,
	output   [11:0]	RGB,

	input     [1:0] vram_bank,
	input           system2,
	input           rowscroll,
	input				PALDSW,
	input	 [15:0]	cpu_ad,
	input				cpu_wr,
	input		[7:0]	cpu_dw,
	output			cpu_rd,
	output	[7:0]	cpu_dr,

	input				ROMCL,		// Downloaded ROM image
	input	 [24:0]	ROMAD,
	input	 [7:0]	ROMDT,
	input				ROMEN,

	input 			PAUSE_N,
	input  [15:0]	HSAD,
	output [7:0]	HSDO,
	input  [7:0]	HSDI,
	input				HSWE
);

reg [2:0] clkdiv;
always @(posedge VCLKx8) clkdiv <= clkdiv+1'd1;

wire VCLKx4    = clkdiv[0];
wire VCLK_EN   = !clkdiv;
wire VCLKx4_EN = !clkdiv[0];

assign PCLK_EN = VCLK_EN;

// CPU Interface
wire [10:0] palno;
wire  [7:0] palout;

wire  [9:0] sprad;
wire [15:0] sprdt;

wire [12:0] vram0ad;
wire [15:0] vram0dt;
wire [12:0] vram1ad;
wire [15:0] vram1dt;

wire  [5:0] mixcoll_ad;
wire        mixcoll;
wire  [9:0] sprcoll_ad;
wire 	    sprcoll;

wire [15:0] scrx;
wire  [7:0] scry;
wire  [7:0] scry_flip_src;
// MAME screen_update_system2(_rowscroll): flipped Y source is E784,
// transformed as 1024 - value (equivalent to 8-bit subtraction).
wire  [8:0] scry_display = (system2 && VFLP) ?
                (9'd0 - {1'b0, scry_flip_src}) : {1'b0, scry};
wire [11:0] bg_pages;

VIDCPUINTF intf(
	RESET,
	VCLKx8,
	PH, PV, VFLP,
	cpu_ad, cpu_wr, cpu_dw,
	cpu_rd, cpu_dr,
	palno, palout,
	sprad, sprdt,
	vram0ad, vram0dt,
	vram1ad, vram1dt,
	vram_bank,
	mixcoll_ad, mixcoll,
	sprcoll_ad, sprcoll,
	scrx, scry, scry_flip_src,
	system2, rowscroll,
	bg_pages,
	PAUSE_N,HSAD,HSDO,HSDI,HSWE
);


// HV Coordinate Generator
wire [8:0] HPOS,  VPOS;
wire [8:0] BG0HP, BG0VP;
wire [8:0] BG1HP, BG1VP;
VIDHVGEN hv(
	system2, VFLP,
	PH,    PV,
	scrx,  scry_display,
	HPOS,  VPOS,
	BG0HP, BG0VP,
	BG1HP, BG1VP,
	VBLK
);


// Sprite Engine
wire [10:0] SPRPX;
wire [17:0] sprchad;
wire  [7:0] sprchdt;
DLROM #(17,8) sprchr(VCLKx8,sprchad,sprchdt, ROMCL,ROMAD,ROMDT,ROMEN & `EN_SPRITE );
SEGASYS1_SPRITE sprite(
	.VCLKx8(VCLKx8),
	.VCLKx4(VCLKx4),
	.VCLKx4_EN(VCLKx4_EN), .VCLK_EN(VCLK_EN),
	.system2(system2),
	.VFLP(VFLP), // game-controlled cocktail flip, source-only B22
	.PH(HPOS),.PV(VPOS),
	.sprad(sprad),.sprdt(sprdt),
	.sprchad(sprchad),.sprchdt(sprchdt),
	.sprcoll(sprcoll),.sprcoll_ad(sprcoll_ad),
	.sprpx(SPRPX)
);


// BG Scanline Generator
wire [10:0] BG0PX, BG1PX;
wire [14:0] tile0ad, tile1ad;
wire [14:0] tilead_fg = system2 ? tile0ad : tile1ad;
wire [14:0] tilead_bg = system2 ? tile1ad : tile0ad;
reg  [14:0] tilead;
wire [23:0] tiledt;
reg  [23:0] tiledt_fg, tiledt_bg, tiledt_r;
wire [23:0] tile0dt = system2 ? tiledt_fg : tiledt_bg;
wire [23:0] tile1dt = system2 ? tiledt_bg : tiledt_fg;
always @(posedge VCLKx8) begin
	if (VCLK_EN) begin
		if (HPOS[2:0] == 3'b000) begin
			tilead <= tilead_bg;
			tiledt_fg <= tiledt;
			tiledt_bg <= tiledt_r;
		end
		if (HPOS[2:0] == 3'b100) begin
			tilead <= tilead_fg;
			tiledt_r <= tiledt;
		end
	end
end

wire [11:0] pages;
assign pages = !system2 ? 12'b001001001001 : bg_pages;

TileChrROM tilechr(VCLKx8, tilead, tiledt, ROMCL,ROMAD,ROMDT,ROMEN );
BGGEN bg0(VCLKx8,VCLK_EN,BG0HP,BG0VP,12'd0,vram0ad,vram0dt,tile0ad,tile0dt,BG0PX);
BGGEN bg1(VCLKx8,VCLK_EN,BG1HP,BG1VP,pages,vram1ad,vram1dt,tile1ad,tile1dt,BG1PX);

// Color Mixer & RGB Output
wire [7:0] cltidx,cltval;
wire [7:0] color;

DLROM #(8,8) clut(VCLKx8, cltidx, cltval, ROMCL,ROMAD,ROMDT,ROMEN & `EN_CLUT );
COLMIX cmix(
	VCLKx8, VCLK_EN,
	system2 ? BG1PX : BG0PX,
	system2 ? BG0PX : BG1PX,
	SPRPX,
	PALDSW, HPOS, VPOS,
	cltidx, cltval,
	mixcoll, mixcoll_ad,
	palno, palout,
	color
);

// Palette
`define EN_PALR		(ROMAD[18:8]==11'b101_1000_0001)	// $58100
`define EN_PALG		(ROMAD[18:8]==11'b101_1000_0010)	// $58200
`define EN_PALB		(ROMAD[18:8]==11'b101_1000_0011)	// $58300

wire [3:0] r,g,b;

DLROM #(8,8) pal_r(VCLKx8, color, r, ROMCL,ROMAD,ROMDT,ROMEN & `EN_PALR );
DLROM #(8,8) pal_g(VCLKx8, color, g, ROMCL,ROMAD,ROMDT,ROMEN & `EN_PALG );
DLROM #(8,8) pal_b(VCLKx8, color, b, ROMCL,ROMAD,ROMDT,ROMEN & `EN_PALB );

// detect color proms while transfering them
reg has_color_prom = 0;
always @(posedge ROMCL)
	if (ROMEN)
		if(`EN_PALR | `EN_PALG | `EN_PALB)
			has_color_prom <= has_color_prom | ~(!ROMDT);

assign RGB = has_color_prom ? {b,g,r} :
                              {color[7:6], color[7:6],
			       color[5:3], color[5],
			       color[2:0], color[2]};

endmodule


//----------------------------------
//  CPU Interface
//----------------------------------
module VIDCPUINTF
(
	input				RESET,

	input         clk,

	input		[8:0]	PH,
	input		[8:0]	PV,
	input           VFLP, // MAME screen flip bit, scroll register mirror only

	input	  [15:0]	cpu_ad,
	input				cpu_wr,
	input		[7:0]	cpu_dw,
	output			cpu_rd,
	output	[7:0]	cpu_dr,

	input	  [10:0] palno,
	output   [7:0] palout,

	input		[9:0] sprad,
	output  [15:0] sprdt,

	input	   [12:0] vram0ad,
	output  [15:0] vram0dt,

	input    [12:0] vram1ad,
	output  [15:0]	vram1dt,
	input    [1:0] vram_bank,

	input    [5:0]	mixcoll_ad,
	input				mixcoll,

	input    [9:0]	sprcoll_ad,
	input				sprcoll,

	output reg [15:0] scrx,
	output reg  [7:0] scry,
	output reg  [7:0] scry_flip_src,

	input           system2,
	input           rowscroll,
	output [11:0] bg_pages,

	input 			PAUSE_N,
	input  [15:0]	HSAD,
	output [7:0]	HSDO,
	input  [7:0]	HSDI,
	input				HSWE
);

// CPU Address Decoders
wire cpu_cs_palram;
wire cpu_cs_spram;
wire cpu_cs_mixcoll;
wire cpu_cs_sprcoll;
wire cpu_cs_vram;

wire cpu_wr_palram;
wire cpu_wr_spram;
wire cpu_wr_mixcoll;
wire cpu_wr_mixcollclr;
wire cpu_wr_sprcoll;
wire cpu_wr_sprcollclr;
wire cpu_wr_vram;
wire cpu_wr_scrreg1;
wire cpu_wr_scrreg0;
wire cpu_wr_bgpage;

VIDADEC adecs(
	cpu_ad,
	cpu_wr,

	cpu_cs_palram,
	cpu_cs_spram,
	cpu_cs_mixcoll,
	cpu_cs_sprcoll,
	cpu_cs_vram,

	cpu_wr_palram,
	cpu_wr_spram,
	cpu_wr_mixcoll,
	cpu_wr_mixcollclr,
	cpu_wr_sprcoll,
	cpu_wr_sprcollclr,
	cpu_wr_vram,
	cpu_wr_scrreg0,
	cpu_wr_scrreg1,
	cpu_wr_bgpage,

	cpu_rd
);

reg [7:0] scrx_row[64];
// Preserve upright video exactly; only VFLP selects the alternate MAME
// scroll-register bank/order (the framebuffer/sprite flip is a separate path).
wire [4:0] scroll_row_idx = rowscroll
        ? (VFLP ? ~PV[7:3] : PV[7:3])
        : (VFLP ? 5'd27 : 5'd0);
reg [2:0] bg_page[4];
assign bg_pages = {bg_page[3],bg_page[2],bg_page[1],bg_page[0]};

// Scroll and background plane registers
always @ (posedge clk or posedge RESET) begin
	if (RESET) begin
		scrx <= 0;
		scry <= 0;
		scry_flip_src <= 0;
	end else begin
		if (system2) begin
			if (cpu_wr_bgpage & !vram_bank)
				bg_page[cpu_ad[2:1]] <= cpu_dw[2:0];
			else if (cpu_wr_scrreg0 & !vram_bank)
				if (cpu_ad[6])
					scrx_row[cpu_ad[5:0]] <= cpu_dw;
				else if (cpu_ad[7:0] == 8'hba)
					scry <= cpu_dw;
				else if (cpu_ad[7:0] == 8'h84)
					scry_flip_src <= cpu_dw;
			// In MAME's flipped System 2 renderer rows 0..31 are read
			// E7FE/E7FF, E7FC/E7FD, ... E7C0/E7C1 instead of forward.
			// Non-row-scroll flipped System 2 uses E7F6/E7F7 (row 27).
			scrx <= {scrx_row[{scroll_row_idx,1'b1}],
			         scrx_row[{scroll_row_idx,1'b0}]};
		end else begin
			if (cpu_wr_scrreg1) begin
				case(cpu_ad[7:0])
				8'hBD: scry <= cpu_dw;
				8'hFC: scrx[ 7:0] <= cpu_dw;
				8'hFD: scrx[15:8] <= cpu_dw;
				default:;
				endcase
			end
		end
	end
end

// Hiscore address decoder
wire HS_CS_SPRAM = (HSAD[15:11] == 5'b1101_0) & ~PAUSE_N;
wire HS_CS_VRAM  = (HSAD[15:12] == 4'b1110  ) & ~PAUSE_N;

assign HSDO = HS_CS_SPRAM ? cpu_rd_spram :
              HS_CS_VRAM ? cpu_rd_vram :
              8'b00000000;

// Palette RAM
wire  [7:0] cpu_rd_palram;
DPRAM2048 palram(
	clk, cpu_ad[10:0], cpu_dw, cpu_wr_palram,
	clk, palno, palout, cpu_rd_palram
);


// Sprite Attribute RAM
wire [7:0]	cpu_rd_spram;

// Sprite RAM hiscore mux
wire [10:0]	sprad0;
wire [7:0]	sprdw0;
wire 			sprwr0;
assign sprad0 = HS_CS_SPRAM ? HSAD[10:0] : cpu_ad[10:0];
assign sprdw0 = HS_CS_SPRAM ? HSDI : cpu_dw;
assign sprwr0 = HS_CS_SPRAM ? HSWE : cpu_wr_spram;

DPRAM2048_8_16 sprram(
	clk, sprad0, sprdw0, sprwr0,
	clk, sprad, sprdt, cpu_rd_spram
);

// Collision RAM (Mixer & Sprite)
wire [7:0]	cpu_rd_mixcoll;
wire [7:0]	cpu_rd_sprcoll;
COLLRAM_M mixc(
	clk,cpu_ad[5:0],cpu_wr_mixcoll,cpu_wr_mixcollclr,cpu_rd_mixcoll,mixcoll_ad,mixcoll
);
COLLRAM_S sprc(
	clk,cpu_ad[9:0],cpu_wr_sprcoll,cpu_wr_sprcollclr,cpu_rd_sprcoll,sprcoll_ad,sprcoll
);


// VRAM
wire  [7:0] cpu_rd_vram;
// VRAM0 hiscore mux
wire [13:0]	vram_ad;
wire [7:0]	vram_dw;
wire 		vram_wr;
assign vram_ad = {vram_bank, HS_CS_VRAM ? HSAD[11:0] : cpu_ad[11:0]};
assign vram_dw = HS_CS_VRAM ? HSDI : cpu_dw;
assign vram_wr = HS_CS_VRAM ? HSWE : cpu_wr_vram;

VRAM vram(
	clk, vram_ad, cpu_rd_vram, vram_dw, vram_wr,
	clk, vram0ad, vram0dt, vram1ad, vram1dt
);


// CPU Read Data Selector
dataselector5 videodsel(
	cpu_dr,
	cpu_cs_palram,  cpu_rd_palram,
	cpu_cs_vram,    cpu_rd_vram,
	cpu_cs_spram,   cpu_rd_spram,
	cpu_cs_sprcoll, cpu_rd_sprcoll,
	cpu_cs_mixcoll, cpu_rd_mixcoll,
	8'hFF
);

endmodule


//----------------------------------
//  Tile ROM
//----------------------------------
module TileChrROM
(
	input				clk,
	input  [14:0]	adr,
	output [23:0]	dat,

	input				ROMCL,		// Downloaded ROM image
	input  [24:0]	ROMAD,
	input	  [7:0]	ROMDT,
	input				ROMEN
);

wire [23:0]	t0dt,t1dt;
assign dat = adr[14] ? t1dt : t0dt;

DLROM #(14,8) t00( clk, adr[13:0], t0dt[7:0]  ,ROMCL,ROMAD,ROMDT,ROMEN & `EN_TILE00 );
DLROM #(14,8) t01( clk, adr[13:0], t0dt[15:8] ,ROMCL,ROMAD,ROMDT,ROMEN & `EN_TILE01 );
DLROM #(14,8) t02( clk, adr[13:0], t0dt[23:16],ROMCL,ROMAD,ROMDT,ROMEN & `EN_TILE02 );

DLROM #(14,8) t10( clk, adr[13:0], t1dt[7:0]  ,ROMCL,ROMAD,ROMDT,ROMEN & `EN_TILE10 );
DLROM #(14,8) t11( clk, adr[13:0], t1dt[15:8] ,ROMCL,ROMAD,ROMDT,ROMEN & `EN_TILE11 );
DLROM #(14,8) t12( clk, adr[13:0], t1dt[23:16],ROMCL,ROMAD,ROMDT,ROMEN & `EN_TILE12 );

endmodule


//----------------------------------
//  HV Coordinate Generator
//----------------------------------
module VIDHVGEN
(
	input    	system2,
	input           VFLP,
	input	 [8:0]	PH,
	input	 [8:0]	PV,

	input [15:0]	scrx,
	input  [8:0]	scry,

	output [8:0]	HPOS,
	output [8:0]	VPOS,

	output [8:0]	BG0HP,
	output [8:0]	BG0VP,

	output [8:0]	BG1HP,
	output [8:0]	BG1VP,

	output			VBLK
);

assign VBLK = (PV == 9'd224) & (PH <= 9'd64);

assign HPOS = PH+1'd1;
assign VPOS = PV;

wire [8:0] BGHSCR = scrx[8:1]+4'd14;
wire [8:0] BGVSCR = scry;

assign BG0HP = system2 ? HPOS+8'd3 : (HPOS-BGHSCR)+3;
assign BG0VP = system2 ? VPOS : (VPOS+BGVSCR);

// MAME screen_update_system2(_rowscroll) chooses
// upright xscroll = raw - 502 and flipped xscroll = 1536 - raw.
// Hence at the same screen X the effective tile-index change on flip is
// (raw + 5) modulo 512 relative to the upright fetch.
// The upright path below is byte-for-byte unchanged.
// For odd raw values: floor(raw/2)+ceil(raw/2) == raw.
wire [8:0] flipped_bg_x = HPOS + {1'b0,scrx[8:1]} +
                           {8'd0,scrx[0]} + 9'd3;
assign BG1HP = system2 ? (VFLP ? flipped_bg_x : (HPOS-BGHSCR)+12) : HPOS+3;
assign BG1VP = system2 ? (VPOS+BGVSCR) : VPOS;

endmodule


//----------------------------------
//  CPU Address Decoders
//----------------------------------
module VIDADEC
(
	input	[15:0] cpu_ad,
	input			 cpu_wr,

	output		 cpu_cs_palram,
	output		 cpu_cs_spram,
	output		 cpu_cs_mixcoll,
	output		 cpu_cs_sprcoll,
	output		 cpu_cs_vram,

	output		 cpu_wr_palram,
	output		 cpu_wr_spram,
	output		 cpu_wr_mixcoll,
	output		 cpu_wr_mixcollclr,
	output		 cpu_wr_sprcoll,
	output		 cpu_wr_sprcollclr,
	output		 cpu_wr_vram,
	output		 cpu_wr_scrreg0,
	output		 cpu_wr_scrreg1,
	output		 cpu_wr_bgpage,

	output		 cpu_rd
);

assign cpu_cs_palram     = (cpu_ad[15:11] == 5'b1101_1);
assign cpu_cs_spram      = (cpu_ad[15:11] == 5'b1101_0);
assign cpu_cs_mixcoll    = (cpu_ad[15:10] == 6'b1111_00);
wire   cpu_cs_mixcollclr = (cpu_ad[15:10] == 6'b1111_01);
assign cpu_cs_sprcoll    = (cpu_ad[15:10] == 6'b1111_10);
wire   cpu_cs_sprcollclr = (cpu_ad[15:10] == 6'b1111_11);
assign cpu_cs_vram       = (cpu_ad[15:12] == 4'b1110);
wire   cpu_cs_scrreg0    = (cpu_ad[15: 7] == 9'b1110_0111_1);
wire   cpu_cs_scrreg1    = (cpu_ad[15: 8] == 8'b1110_1111);
wire   cpu_cs_bgpage     = (cpu_ad[15: 3] == 13'b1110_0111_0100_0) & !cpu_ad[0];


assign cpu_wr_palram     = cpu_cs_palram     & cpu_wr;
assign cpu_wr_spram      = cpu_cs_spram      & cpu_wr;
assign cpu_wr_mixcoll    = cpu_cs_mixcoll    & cpu_wr;
assign cpu_wr_mixcollclr = cpu_cs_mixcollclr & cpu_wr;
assign cpu_wr_sprcoll    = cpu_cs_sprcoll    & cpu_wr;
assign cpu_wr_sprcollclr = cpu_cs_sprcollclr & cpu_wr;
assign cpu_wr_scrreg0    = cpu_cs_scrreg0    & cpu_wr;
assign cpu_wr_scrreg1    = cpu_cs_scrreg1    & cpu_wr;
assign cpu_wr_bgpage     = cpu_cs_bgpage     & cpu_wr;
assign cpu_wr_vram       = cpu_cs_vram       & cpu_wr;


assign cpu_rd = cpu_cs_palram  |
					 cpu_cs_vram    |
					 cpu_cs_spram   |
					 cpu_cs_sprcoll |
					 cpu_cs_mixcoll ;

endmodule


//----------------------------------
//  BG Scanline Generator
//----------------------------------
module BGGEN
(
	input         CLK,
	input         VCLK_EN,

	input   [8:0]	HP,
	input   [8:0]	VP,
	input	[11:0]  bg_pages,

	output  [12:0]	VRAMAD,
	input	[15:0]	VRAMDT,

	output  [14:0]	TILEAD,
	input	[23:0]	TILEDT,

	output [10:0]	OPIX
);

assign VRAMAD = {VP[8] ? (HP[8] ? bg_pages[8:6] : bg_pages[11:9])
                       : (HP[8] ? bg_pages[2:0] : bg_pages[5:3]),
		 VP[7:3], HP[7:3]};
assign TILEAD = { VRAMDT[15], VRAMDT[10:0], VP[2:0] };

reg  [31:0] BGREG;
reg   [7:0] BG_COL, BG_COL1;
wire [23:0] BGCD = BGREG[23:0];
wire  [7:0] BGPN = BGREG[31:24];

wire [31:0] BGPIX;
always @( posedge CLK ) begin
	if (VCLK_EN) begin
		BGREG <= BGPIX;
		if (HP[2:0] == 0) begin
			BG_COL1 <= VRAMDT[12:5];
			BG_COL <= BG_COL1;
		end
	end
end

dataselector1_32 pixsft(
	BGPIX,
	( HP[2:0] != 0 ),{ BGPN, BGCD[22:0], 1'b0 },
						  { BG_COL/*VRAMDT[12:5]*/,   TILEDT }
);

assign OPIX = { BGPN, BGCD[7], BGCD[15], BGCD[23] };

endmodule


//----------------------------------
//  Color Mixer & RGB Output
//----------------------------------
module COLMIX
(
	input         CLK,
	input         VCLK_EN,

	input	 [10:0]	BG0PX,
	input  [10:0]	BG1PX,
	input	 [10:0]	SPRPX,

	input				PALDSW,
	input   [8:0]	HPOS,
	input	  [8:0]	VPOS,

	output  [7:0]	cltidx,
	input   [7:0]	cltval,

	output			mixcoll,
	output  [5:0]	mixcoll_ad,

	output [10:0]	palno,
	input   [7:0]  palout,

	output reg [7:0] color
);

assign cltidx = { 1'b0,
	 BG0PX[10:9],(BG0PX[2:0]==0),
	 BG1PX[10:9],(BG1PX[2:0]==0),
	(SPRPX[3:0]==0)
};

assign mixcoll    = ~(cltval[2]);
assign mixcoll_ad = { cltval[3], SPRPX[8:4] };

wire [10:0] palno_i;
dataselector2_11 colsel(
	palno_i,
	cltval[1], ( 11'h400 | BG0PX[8:0] ),
	cltval[0], ( 11'h200 | BG1PX[8:0] ),
	           ( 11'h000 | SPRPX[8:0] )
);

wire [10:0] palno_d = {HPOS[7],VPOS[7:2],HPOS[6:3]};

assign palno = PALDSW ? palno_d : palno_i;

always @(posedge CLK )
	if (VCLK_EN)
		color <= palout;

endmodule


//----------------------------------
//  Collision RAM
//----------------------------------
module COLLRAM_M
(
	input				clk,
	input  [5:0] 	cpu_ad,
	input				cpu_wr_coll,
	input				cpu_wr_collclr,
	output [7:0]	cpu_rd_coll,

	input  [5:0] 	coll_ad,
	input				coll
);

reg [63:0] core;
reg coll_rd, coll_sm;

always @(posedge clk) begin
	if (cpu_wr_coll)    core[cpu_ad] <= 1'b0; else if (coll) core[coll_ad] <= 1'b1;
	if (cpu_wr_collclr) coll_sm <= 1'b0; else if (coll) coll_sm <= 1'b1;
end

always @(posedge clk) coll_rd <= core[cpu_ad];
assign cpu_rd_coll = { coll_sm, 6'b111111, coll_rd };

endmodule

module COLLRAM_S
(
	input				clk,
	input  [9:0] 	cpu_ad,
	input				cpu_wr_coll,
	input				cpu_wr_collclr,
	output [7:0]	cpu_rd_coll,

	input  [9:0] 	coll_ad,
	input				coll
);

reg [1023:0] core;
reg coll_rd, coll_sm;

always @(posedge clk) begin
	if (cpu_wr_coll   ) core[cpu_ad] <= 1'b0; else if (coll) core[coll_ad] <= 1'b1;
	if (cpu_wr_collclr) coll_sm <= 1'b0; else if (coll)       coll_sm <= 1'b1;
end

always @(posedge clk) coll_rd <= core[cpu_ad];
assign cpu_rd_coll = { coll_sm, 6'b111111, coll_rd };

endmodule

