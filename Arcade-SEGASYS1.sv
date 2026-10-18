//=========================================================
//  Arcade: SEGA SYSTEM 1  for MiSTer
//
//                        Copyright (c) 2019,20 MiSTer-X
//=========================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

`include "rtl/quirks.vh"

assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;

assign VGA_F1 = 0;
assign VGA_SCALER = 0;
assign HDMI_FREEZE = 0;

assign USER_OUT  = '1;

assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign BUTTONS   = 0;

assign AUDIO_MIX = 0;
assign FB_FORCE_BLANK = '0;

wire screen_H = status[6]|~SYSMODE[0][1]|direct_video;
wire [1:0] ar = status[15:14];

assign VIDEO_ARX = (!ar) ? (screen_H ? 8'd4 : 8'd3) : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? (screen_H ? 8'd3 : 8'd4) : 12'd0;

`include "build_id.v" 
// Diagnostic OSD bits [16],[17] do not overlap Dakkochan House status[12:10] mux.
localparam CONF_STR = {
	"a.segasys1+2;;",
	"-;",
	"H0OEF,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"H0O6,Orientation,Vert,Horz;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"O7,Pause when OSD is open,On,Off;",
	"-;",
	"DIP;",
	"C,Cheats;",
	"OI,Enhanced Stereo,Off,On;",
	"-;",
	"OOR,Analog Video H-Pos,0,1,2,3,4,5,6,7,-8,-7,-6,-5,-4,-3,-2,-1;",
	"OSV,Analog Video V-Pos,0,1,2,3,4,5,6,7,-8,-7,-6,-5,-4,-3,-2,-1;",
	"OWY,HDMI Picture Down,0,+2,+4,+6,+8,+10,+12,+14;",
	"-;",
	"O8,Service,Off,On;",
	"O9,Test,Off,On;",
	"R0,Reset;",
	"J1,Trig1,Trig2,Trig3,Trig4,Trig5,Start 1P,Start 2P,Coin,Pause;",
	"jn,A,B,X,,,Start,Select,R,L;",
	"V,v",`BUILD_DATE
};

wire [3:0] HOFFS = status[27:24];
wire [3:0] VOFFS = status[31:28];


////////////////////   CLOCKS   ///////////////////

// MAME sources mention 20MHz, 8MHz crystals and 5Mhz pixel clock.
// 40MHz sys clock should get them all covered.

wire clk_40M;
wire clk_hdmi = clk_40M;
wire clk_sys  = clk_40M;

pll pll
(
	.rst(0),
	.refclk(CLK_50M),
	.outclk_0(clk_40M)
);

///////////////////////////////////////////////////

wire    [63:0]  status;
wire     [1:0]  buttons;
wire    [10:0]  ps2_key;

wire            forced_scandoubler;
wire            direct_video;

wire            ioctl_download;
wire            ioctl_upload;
wire            ioctl_wr;
wire    [7:0]   ioctl_index;
wire    [24:0]  ioctl_addr;
wire    [7:0]   ioctl_dout;
wire    [7:0]   ioctl_din;

wire    [15:0]  joy1, joy2;
wire    [15:0]  joy = joy1 | joy2;
wire    [8:0]   spinner_0, spinner_1;
wire    [24:0]  ps2_mouse;

wire    [21:0]  gamma_bus;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),

	.status(status),
	.status_menumask(direct_video),

	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),

	.ioctl_download(ioctl_download),
	.ioctl_upload(ioctl_upload),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_din(ioctl_din),
	.ioctl_index(ioctl_index),

	.ps2_key(ps2_key),
	.ps2_mouse(ps2_mouse),
	.joystick_0(joy1),
	.joystick_1(joy2),
	.spinner_0(spinner_0),
	.spinner_1(spinner_1)
);

// SYSMODE[0]: [0]=SYS1/SYS2,[1]=H/V,[2]=H256/H240,[3]=water match control,[4]=CW/CCW,[5]=spinner,[6]=SYS2 rowscroll,[7] button1&2 swap
// SYSMODE[1]: [0]=Noboranka memory layout
reg [7:0] SYSMODE[4];
reg [7:0] DSW[2];
always @(posedge clk_sys) begin
	if (ioctl_wr) begin
		if ((ioctl_index==1  ) && !ioctl_addr[24:2]) SYSMODE[ioctl_addr[1:0]] <= ioctl_dout;
		if ((ioctl_index==254) && !ioctl_addr[24:1]) DSW[ioctl_addr[0]] <= ioctl_dout;
	end
end

reg key_start1 = 1'b0;
reg key_start2 = 1'b0;
reg key_coin1 = 1'b0;
reg key_coin2 = 1'b0;
reg key_test = 1'b0;
reg key_reset = 1'b0;
reg key_service = 1'b0;

wire m_lup    = joy1[3];
wire m_ldown  = joy1[2];
wire m_lleft  = joy1[1];
wire m_lright = joy1[0];
wire m_rup    = joy1[7] | joy2[3];
wire m_rdown  = joy1[6] | joy2[2];
wire m_rleft  = joy1[5] | joy2[1];
wire m_rright = joy1[4] | joy2[0];
wire m_trig   = joy1[8];

wire m_up     = joy[3];
wire m_down   = joy[2];
wire m_left   = joy[1];
wire m_right  = joy[0];
wire m_trig_1 = joy[4];
wire m_trig_2 = joy[5];
wire m_trig_3 = joy[6];

wire m_start1 = joy1[9] | joy2[10] | key_start1;
wire m_start2 = joy1[10] | joy2[9] | key_start2;
wire m_coin1  = joy1[11] | key_coin1;
wire m_coin2  = joy2[11] | key_coin2;
wire m_pause  = joy[12];

wire m_service = key_service || status[8];
wire m_test = key_test || status[9];

// PAUSE SYSTEM
reg pause;					// Pause signal (active-high)
reg pause_toggle = 1'b0;			// User paused (active-high)
reg [31:0] pause_timer;				// Time since pause
reg [31:0] pause_timer_dim = 31'h17d78400;	// Time until screen dim (10 seconds @ 40Mhz)
reg dim_video = 1'b0;				// Dim video output (active-high)

// Pause when highscore module requires access, user has pressed pause, or OSD is open and option is set
assign pause = hs_access | pause_toggle  | (OSD_STATUS && ~status[7]);
assign dim_video = (pause_timer >= pause_timer_dim) ? 1'b1 : 1'b0;

always @(posedge clk_hdmi) begin
	reg old_pause;
	old_pause <= m_pause;
	if(~old_pause & m_pause) pause_toggle <= ~pause_toggle;
	if(pause_toggle)
	begin
		if(pause_timer<pause_timer_dim)
		begin
			pause_timer <= pause_timer + 1'b1;
		end
	end
	else
	begin
		pause_timer <= 1'b0;
	end
end

///////////////////////////////////////////////////

wire hblank, vblank;
wire ce_vid;
wire hs, vs;
wire [3:0] r,g,b;
wire [11:0] rgb_out = dim_video ? {r >> 1,g >> 1, b >> 1} : {r,g,b};

reg ce_pix;
always @(posedge clk_hdmi) begin
	reg old_clk;
	old_clk <= ce_vid;
	ce_pix  <= old_clk & ~ce_vid;
end

// BAZSET VIDEO V3 / SEGA System1/2 native 320x260 retiming.
wire [23:0] v3_rgb;
wire v3_hs, v3_vs, v3_de, v3_ce, v3_vblank;
wire [11:0] v3_rgb12 = {v3_rgb[23:20],v3_rgb[15:12],v3_rgb[7:4]};
baz_video_v3_mirror_geometry #(.H_TOTAL(320)) sega_baz_video_v3 (
  .clk(clk_hdmi),.reset(RESET),.ce_in(PCLK_EN),
  .rgb_in({r,r,g,g,b,b}),
  .hs_in(~hs),.vs_in(~vs),.de_in(~(hblank|vblank)),
  .vb_in(vblank),.mirror_enable(1'b0),
  .geom_enable(1'b0),
  // OSD OKN uses unused status bits [23:20] as signed 4-bit size delta;
  // each increment changes destination active width by 4 source pixels.
  // Preserve standard b16 raster/position behavior when V3 Geometry is OFF.
  .geom_hsize(5'sd0),
  .geom_hoffset(9'sd0),.geom_voffset(6'sd0),
  .rgb_out(v3_rgb),.hs_out(v3_hs),.vs_out(v3_vs),
  .de_out(v3_de),.ce_out(v3_ce),.vb_out(v3_vblank)
);
// Output-only HDMI display positioning. The original 320x260 game timing,
// sprite coordinates, sound, and native V3 stream are unchanged. Status=0
// bypasses the entire buffer exactly as B23 did. In direct_video bypass.
wire [11:0] hdmi_pos_rgb;
wire hdmi_pos_hs,hdmi_pos_vs,hdmi_pos_de,hdmi_pos_ce,hdmi_pos_vb;
bz_hdmi_picture_down #(.H_TOTAL(320),.LINES_BUFFERED(16)) hdmi_pos (
  .clk(clk_hdmi),.reset(RESET),
  .ce_in(v3_ce),.rgb_in(v3_rgb12),
  .hs_in(v3_hs),.vs_in(v3_vs),.de_in(v3_de),.vb_in(v3_vblank),
  .lines_down(direct_video ? 3'd0 : status[34:32]),
  .ce_out(hdmi_pos_ce),.rgb_out(hdmi_pos_rgb),
  .hs_out(hdmi_pos_hs),.vs_out(hdmi_pos_vs),
  .de_out(hdmi_pos_de),.vb_out(hdmi_pos_vb)
);
arcade_video #(288,12) arcade_video
(
	.*,

	.clk_video(clk_hdmi),

	.RGB_in(hdmi_pos_rgb),
	.HBlank(~hdmi_pos_de),
	.VBlank(hdmi_pos_vb),
	.HSync(hdmi_pos_hs),
	.VSync(hdmi_pos_vs),

	.fx(status[5:3])
);


wire no_rotate = screen_H;
wire rotate_ccw = ~SYSMODE[0][4];
screen_rotate screen_rotate (.*);

wire			PCLK_EN;
wire  [8:0] HPOS,VPOS;
wire  [11:0] POUT;
HVGEN hvgen
(
	.HPOS(HPOS),
	.VPOS(VPOS),
	.CLK(clk_sys),
	.PCLK_EN(PCLK_EN),
	.iRGB(POUT),
	.oRGB({b,g,r}),
	.HBLK(hblank),
	.VBLK(vblank),
	.HSYN(hs),
	.VSYN(vs),
	.H240(SYSMODE[0][2]),
	.HOFFS(HOFFS),
	.VOFFS(VOFFS)
);

assign ce_vid = hdmi_pos_ce;

wire [15:0] AOUT;
// Beta-only 440 Hz tone and mute-bypass switches have been retired.
// Preserve signed-PCM normal gameplay audio output without diagnostics.
// Default authentic mono; optional two-PSG complementary stereo, output-only.
wire [7:0] PSG0_STEM, PSG1_STEM;
bz_sega_dual_psg_stereo sega_stereo(
 .clk(clk_sys),.reset(iRST),.enhanced_stereo(status[18]),
 .original_mono_pcm(AOUT),.psg_2mhz(PSG0_STEM),.psg_4mhz(PSG1_STEM),
 .audio_l(AUDIO_L),.audio_r(AUDIO_R)
);
// SN76489 PSG mix is zero-based, with exact silence sample 16'h0000.
// MiSTer signed mode has zero as silence; unsigned mode falsely treats
// 16'h0000 as full negative DC (midpoint would have been 16'h8000).
// The direct 440Hz diagnostic 4000/C000 works as +/- signed amplitude.
assign AUDIO_S = 1; // signed PCM, preserve existing 16bit positive PSG samples


///////////////////////////////////////////////////

wire iRST = RESET | status[0] | buttons[1] | key_reset;
wire [2:0] triggers = {SYSMODE[0][7] ? {m_trig_2, m_trig_1} : {m_trig_1, m_trig_2}, m_trig_3};
wire [7:0] quirks = SYSMODE[1];
wire mux_clock;
reg mux_clock_r = 1'b0;

// Keyboard support for (DakkoChan House) mahjong game
// Keyboard levels are stored in sequential flops (not undriven wires).
// All inactive Mahjong keys default to 0, so inverted P1 values idle high.
reg [7:0] dak_keys[6:0];
initial begin
  dak_keys[0] = 0; dak_keys[1] = 0; dak_keys[2] = 0;
  dak_keys[3] = 0; dak_keys[4] = 0; dak_keys[5] = 0;
  dak_keys[6] = 0;
end
// KEY4 Start is provided by the common joystick/keyboard Start controls.
// Keep separate from the matrix flops so no net has multiple drivers.
wire [7:0] dakko_startrow = {dak_keys[6][7:1], (m_start1 || m_start2)};

reg old_ps2_state = 1'b0;
wire pressed = ps2_key[9];
wire [8:0] code = ps2_key[8:0];
always @(posedge clk_sys) begin
        old_ps2_state <= ps2_key[10];
        if(old_ps2_state != ps2_key[10]) begin
                case(code)
                        'h16: key_start1  <= pressed; // 1
                        'h1E: key_start2  <= pressed; // 2
                        'h2E: key_coin1   <= pressed; // 5
                        'h36: key_coin2   <= pressed; // 6
                        'h06: key_test    <= pressed; // F2
                        'h04: key_reset   <= pressed; // F3
                        'h46: key_service <= pressed; // 9

                        'h01c: dak_keys[2][0] <= pressed; // a
                        'h032: dak_keys[2][1] <= pressed; // b
                        'h021: dak_keys[2][2] <= pressed; // c
                        'h023: dak_keys[2][3] <= pressed; // d
                        'h111: dak_keys[2][4] <= pressed; // ralt = last chance

                        'h024: dak_keys[3][0] <= pressed; // e
                        'h02b: dak_keys[3][1] <= pressed; // f
                        'h034: dak_keys[3][2] <= pressed; // g
                        'h033: dak_keys[3][3] <= pressed; // h

                        'h043: dak_keys[4][0] <= pressed; // i
                        'h03b: dak_keys[4][1] <= pressed; // j
                        'h042: dak_keys[4][2] <= pressed; // k
                        'h04b: dak_keys[4][3] <= pressed; // l

                        'h03a: dak_keys[5][0] <= pressed; // m
                        'h031: dak_keys[5][1] <= pressed; // n
                        'h029: dak_keys[5][2] <= pressed; // chi = space
                        'h011: dak_keys[5][3] <= pressed; // pon = lalt
                        'h035: dak_keys[5][4] <= pressed; // flip-flop = y

                        'h026: dak_keys[6][1] <= pressed; // bet = 3

                        'h014: dak_keys[0][0] <= pressed; // kan = lctrl
                        'h012: dak_keys[0][1] <= pressed; // reach = lshift
                        'h01a: dak_keys[0][2] <= pressed; // ron = z
                endcase
        end
end

reg [7:0] INP0, INP1, INP2;
reg [7:0] mux_shift;
reg [2:0] mux_cnt;
// MAME DakkoChan House mux_data_r() starts at KEY0.
// Existing keyboard rows are stored in physical order KEY5,KEY6,KEY0..KEY4.
// Convert logical KEY0..KEY6 index to the existing keyboard array indices.
wire [2:0] dakko_physical_row = (mux_cnt >= 3'd5) ?
                               (mux_cnt - 3'd5) : (mux_cnt + 3'd2);
always @(posedge clk_sys) begin
	if (RESET && (quirks == DAKKOCHAN)) begin
		mux_shift <= 8'h01; // MAME resets m_mux_count to KEY0
		mux_cnt <= 3'd0;
		mux_clock_r <= 1'b0;
	end
	else if (SYSMODE[0][5]) begin
		INP0 = ~spin;
		INP1 = ~spin;
		INP2 = ~{m_trig_1 || ps2_mouse[2:0], m_trig_1 || ps2_mouse[2:0], m_start2, m_start1, 3'b00, m_coin2, m_coin1};
	end
	else if (SYSMODE[0][3]) begin
		INP0 = ~{m_lleft, m_lright, m_lup, m_ldown, m_rleft, m_rright, m_rup, m_rdown};
		INP1 = ~{m_lleft, m_lright, m_lup, m_ldown, m_rleft, m_rright, m_rup, m_rdown};
		INP2 = ~{m_trig, m_trig, m_start2, m_start1, 2'b00, m_coin2, m_coin1};
	end
	// Dakkochan House mux
	else if (quirks == DAKKOCHAN) begin
		if (mux_clock && !mux_clock_r) begin
			mux_shift <= {1'b0,mux_shift[5:0],mux_shift[6]};
			mux_cnt <= (mux_cnt == 3'd6) ? 3'd0 : (mux_cnt + 3'd1);
		end

		INP0 = ~(dakko_physical_row == 3'd6 ? dakko_startrow : dak_keys[dakko_physical_row]);
		INP1 = mux_shift;
		INP2 = ~{m_trig, m_trig, 2'b00, m_service, m_test, m_coin2, m_coin1};
		mux_clock_r <= mux_clock;
	end
	else begin
		INP0 = ~{m_left, m_right, m_up, m_down,1'd0, triggers};
		INP1 = ~{m_left, m_right, m_up, m_down,1'd0, triggers};
		INP2 = ~{2'b00, m_start2, m_start1, m_service, m_test, m_coin2, m_coin1};
	end
end

wire [7:0] spin;
spinner #(15,25,5) spinner
(
	.clk(clk_sys),
	.reset(iRST),
	.minus(m_left),
	.plus(m_right),
	.fast(m_trig_2),
	.strobe(vs),
	.spin1_in(use_mouse ? {ps2_mouse[24],ps2_mouse[15:8]} : spinner_0),
	.spin2_in(spinner_1),
	.spin_out(spin)
);

reg use_mouse = 0;
always @(posedge clk_sys) begin
	reg old_ms;
	reg old_sp;

	old_ms <= ps2_mouse[24];
	if(old_ms ^ ps2_mouse[24]) use_mouse = 1;

	old_sp <= spinner_0[8];
	if(old_sp ^ spinner_0[8]) use_mouse = 0;
end

// Standard MiSTer arcade 16-byte cheat records from ioctl index 255.
reg [128:0] gg_code = 0;
wire code_download = ioctl_download && (ioctl_index == 8'd255);
wire cheat_clear = ioctl_wr && ioctl_download &&
                   ((ioctl_index == 8'd255 && ioctl_addr == 0) ||
                    (ioctl_index == 8'd0 && ioctl_addr == 0));
always @(posedge clk_sys) begin
  gg_code[128] <= 1'b0;
  if (code_download && ioctl_wr) begin
    gg_code[127:0] <= {gg_code[119:0], ioctl_dout};
    gg_code[128] <= (&ioctl_addr[3:0]);
  end
end

SEGASYSTEM1 GameCore
(
	.clk40M(clk_sys),
	.reset(iRST),

	.INP0(INP0),
	.INP1(INP1),
	.INP2(INP2),
	.DSW0(DSW[0]),
	.DSW1(DSW[1]),

	.system2(SYSMODE[0][0]),
	.debug_audio_unmute(1'b0),
	.choplift_vram_wait_fix(SYSMODE[0]==8'h41 && SYSMODE[2]==8'hC4 && SYSMODE[3]==8'h52),
	.rowscroll(SYSMODE[0][6]),
	.quirks(quirks),

	.mux_clock(mux_clock),

	.PH(HPOS),
	.PV(VPOS),
	.PCLK_EN(PCLK_EN),
	.POUT(POUT),
	.SOUT(AOUT),
	.PSG0_STEM(PSG0_STEM),
	.PSG1_STEM(PSG1_STEM),

	.ROMCL(clk_sys),
	.ROMAD(ioctl_addr),
	.ROMDT(ioctl_dout),
	.ROMEN(ioctl_wr & ioctl_index==0),

	.PAUSE_N(~pause),
	.HSAD(hs_address),
	.HSDO(ioctl_din),
	.HSDI(hs_data_in),
	.HSWE(hs_write),
	.CHEAT_CODE(gg_code),
	.CHEAT_CLEAR(cheat_clear)

);


wire [15:0]hs_address;
wire [7:0]hs_data_in;
wire hs_write;
wire hs_access;

hiscore #(
	.HS_ADDRESSWIDTH(16),
	.HS_SCOREWIDTH(11), // Supports Water Match's 825-byte score dump (2KiB capacity)
	.CFG_ADDRESSWIDTH(5),
	.CFG_LENGTHWIDTH(2)
) hi (
	.clk(clk_sys),
	.reset(iRST),
	.ioctl_upload(ioctl_upload),
	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_din(ioctl_din),
	.ioctl_index(ioctl_index),
	.ram_address(hs_address),
	.data_to_ram(hs_data_in),
	.ram_write(hs_write),
	.ram_access(hs_access)
);

endmodule
