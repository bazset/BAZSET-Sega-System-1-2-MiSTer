// Copyright (c) 2019 MiSTer-X

module HVGEN
(
        output       [8:0] HPOS,
        output       [8:0] VPOS,
        input              CLK,
        input              PCLK_EN,
        input       [11:0] iRGB,

        output reg  [11:0] oRGB,
        output             HBLK,
        output reg         VBLK = 1,
        output reg         HSYN = 1,
        output reg         VSYN = 1,

        input              H240,

        input signed [3:0] HOFFS,
        input signed [3:0] VOFFS
);

localparam [8:0] width = 320;
localparam [8:0] height = 260;

reg [8:0] hcnt = 0;
reg [8:0] vcnt = 0;

assign HPOS = hcnt-16;
assign VPOS = !vcnt[8] ? vcnt : vcnt - height;

wire [8:0] HS_B0 = 296+HOFFS;
// HOFFS is signed -8..+7. HS_B0 stays in 288..303; modulo 320 is unnecessary.
wire [8:0] HS_B = HS_B0;
// HS end is 312..327. At most one 320-dot wrap is ever needed.
wire [8:0] HS_E_raw = HS_B + 9'd24;
wire [8:0] HS_E = (HS_E_raw >= width) ? HS_E_raw - width : HS_E_raw;

wire [8:0] VS_B0 = 234+VOFFS;
// VOFFS is signed -8..+7: VS_B0 226..241, already < 260.
wire [8:0] VS_B = VS_B0;
// VS end is 230..245, no vertical wrap for the full OSD offset range.
wire [8:0] VS_E = VS_B+9'd4;

reg hblk240;
reg hblk256;

wire hblack = H240 ? hblk240 : hblk256;
// Sega has 256- and 240-pixel native active-video modes.  RGB was already
// blanked correctly by hblack, but DE/HBLK incorrectly always advertised
// 256 pixels.  Feed the same mode-selected blanking to video V3/arcade_video.
// Do not change native clocks, raster totals, HS or VS generation.
assign HBLK = hblack;

always @(posedge CLK) begin
	if (PCLK_EN) begin
		if (hcnt < width-1)
			hcnt <= hcnt+1;
		else begin
			hcnt <= 0;
			vcnt <= (vcnt == height-1) ? 9'd0 : (vcnt+9'd1);
		end

		hblk256 <= (hcnt < 29) | (hcnt >= 285);
		hblk240 <= (hcnt < 37) | (hcnt >= 277);
		VBLK <= (vcnt >= 224);
		HSYN <= (hcnt < HS_B) ^ (hcnt < HS_E) ^ (HS_B < HS_E);
		VSYN <= (vcnt < VS_B) ^ (vcnt < VS_E) ^ (VS_B < VS_E);
		oRGB <= (hblack|VBLK) ? 12'h0 : iRGB;
	end
end
endmodule
