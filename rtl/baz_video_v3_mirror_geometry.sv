`default_nettype none
// Operation Thunderbolt: single-clock, one-line horizontal presentation flip.
// Receives the already-stable 424-dot stream. Both capture and replay use the
// SAME clock and the SAME CE; no dual-clock mirror reads or porch reversal.
// Stores raw sync/DE/RGB for the previous complete line; reverses only RGB
// samples inside that line's observed DE span. HS/VS/DE are never reversed.
`timescale 1ns / 1ps
module baz_video_v3_mirror_geometry #(
    parameter integer H_TOTAL=424
)(
    input wire clk,
    input wire reset,
    input wire ce_in,
    input wire [23:0] rgb_in,
    input wire hs_in, vs_in, de_in, vb_in,
    input wire mirror_enable,
    input wire geom_enable,
    input wire signed [4:0] geom_hsize,
    input wire signed [8:0] geom_hoffset,
    input wire signed [5:0] geom_voffset,
    output reg [23:0] rgb_out,
    output reg hs_out, vs_out, de_out, ce_out, vb_out
);
localparam integer AW=$clog2(H_TOTAL);
localparam [AW-1:0] LAST=AW'(H_TOTAL-1);
// Distinct physical BRAMs for sequential native and mirrored pixel reads.
(* ramstyle="M10K" *) reg [26:0] line0 [0:H_TOTAL-1];
(* ramstyle="M10K" *) reg [26:0] line1 [0:H_TOTAL-1];
(* ramstyle="M10K" *) reg [23:0] color0 [0:H_TOTAL-1];
(* ramstyle="M10K" *) reg [23:0] color1 [0:H_TOTAL-1];
reg [AW-1:0] x=0;
reg wr_bank=0, have_line=0, de_seen=0;
reg [AW-1:0] first_live=0, last_live=0;
reg [AW-1:0] first0=0, first1=0, last0=0, last1=0;
reg de_valid0=0, de_valid1=0;
reg mirror_line=0;
// Mirror OFF tolerates a line starting at any phase because it simply
// forwards captured packet order. Mirror ON needs all 320 active pixels
// in ONE 424-word bank. If DE rises too late, the active picture would
// wrap across two banks and the old first/last span would invert blanking
// and unrelated picture fragments. Re-anchor capture at that DE edge.
reg de_prev=0, started_with_de=0;
wire de_rise = de_in && !de_prev;
// If captured x=0 was already inside DE, and a second DE onset happens
// before x wraps, visible pixels span TWO native scanlines. Align capture
// at the genuine DE rise; plain Mirror OFF hid this phase defect.
wire reanchor = ce_in && de_rise && started_with_de && (x != 0);
wire [AW-1:0] write_x = reanchor ? {AW{1'b0}} : x;
wire [AW-1:0] first_read=wr_bank ? first0 : first1;
wire [AW-1:0] last_read =wr_bank ? last0  : last1;
wire span_valid=wr_bank ? de_valid0 : de_valid1;
wire within_span=span_valid && x>=first_read && x<=last_read;
wire [AW-1:0] flipped_x=within_span ? (first_read+last_read-x) : x;
reg [26:0] raw0, raw1;
reg [23:0] reversed0,reversed1;
// Single-clock V3 CRT geometry. All control changes are latched at an
// outgoing line boundary; no game clocks, HS timing or fractional pixel CE
// are changed. The same previous-line color BRAM supports resampling.
localparam integer V_TOTAL=260; // Sega System1/2 HVGEN exact native frame
reg geom_mode_line=0;
reg signed [10:0] geom_start_line=0;
reg [9:0] geom_width_line=10'd256;
reg [AW-1:0] geom_cursor=0;
reg [9:0] geom_phase=0;
reg geom_mode_d=0,geom_active_d=0,geom_vs_d=0;
reg [V_TOTAL-1:0] vs_line_hist=0;
reg geom_vs_line=0;
// The V3 donor assumed 320 active pixels inside a 424-dot raster. Sega
// has 240/256 LIVE pixels inside its 320-dot raster. Always derive source
// width from the observed DE span, not the 320-dot TOTAL line length.
// H-size zero must be a 1:1 geometry pass-through in either Sega mode.
wire [9:0] native_live_width = span_valid && last_read>=first_read ?
    ({1'b0,last_read} - {1'b0,first_read} + 10'd1) : 10'd256;
wire [9:0] width_req=native_live_width+
                       {{3{geom_hsize[4]}},geom_hsize,2'b00};
// Keep the centre of the original active Sega picture in the same place
// when growing/shrinking the picture. H-size units are FOUR pixels;
// subtract HALF of that size delta from the destination start.
// The source cursor and HS/VS timing stay unchanged.
wire signed [10:0] half_hsize_delta =
    $signed({{5{geom_hsize[4]}},geom_hsize,1'b0});
wire signed [10:0] start_req =
    $signed({2'b00,first_read}) +
    $signed({{2{geom_hoffset[8]}},geom_hoffset}) -
    half_hsize_delta;
wire geom_mode_x=(x==0)?geom_enable:geom_mode_line;
wire [9:0] geom_width_x=(x==0)?width_req:geom_width_line;
wire signed [10:0] geom_start_x=(x==0)?start_req:geom_start_line;
wire signed [10:0] signed_x=$signed({2'b00,x});
wire geom_dest_x=geom_mode_x && span_valid &&
    signed_x>=geom_start_x &&
    signed_x<(geom_start_x+$signed({1'b0,geom_width_x}));
wire [AW-1:0] clipped_offset=geom_hoffset[8] ? AW'(-geom_hoffset) : '0;
wire [AW-1:0] initial_cursor=mirror_enable ?
    (last_read-clipped_offset) : (first_read+clipped_offset);
wire [AW-1:0] active_cursor=(x==0)?initial_cursor:geom_cursor;
wire mirror_at_geom_x=(x==0)?mirror_enable:mirror_line;
wire [10:0] geom_sum={1'b0,(x==0 ? 10'd0 : geom_phase)}+
                         {1'b0,native_live_width};
wire [10:0] geom_w1={1'b0,geom_width_x};
wire [10:0] geom_w2={geom_width_x,1'b0};
wire [1:0] geom_step=(geom_sum >= geom_w2)?2'd2:
                     ((geom_sum >= geom_w1)?2'd1:2'd0);
wire [9:0] geom_phase_next=(geom_sum>=geom_w2)?10'(geom_sum-geom_w2):
                            ((geom_sum>=geom_w1)?10'(geom_sum-geom_w1):10'(geom_sum));
wire [AW-1:0] geom_cursor_next=mirror_at_geom_x ?
     (active_cursor-AW'(geom_step)):(active_cursor+AW'(geom_step));
wire geom_cursor_valid=mirror_at_geom_x ?
      (active_cursor>=first_read && active_cursor<=last_read):
      (active_cursor>=first_read && active_cursor<=last_read);
wire geom_active_x=geom_dest_x && geom_cursor_valid;
wire [AW-1:0] color_addr=geom_mode_x ? active_cursor : flipped_x;
// Phase-shift CRT VSync relative to the RGB raster only. This mirrors the
// previous V2 positioning method without changing line or frame totals.
wire signed [8:0] vs_off={{3{geom_voffset[5]}},geom_voffset};
wire [8:0] vs_tap=geom_voffset[5] ?
    (9'(V_TOTAL)+vs_off):9'(vs_off);
wire geom_vs_at_x0=vs_line_hist[vs_tap];

// Sega native vertical blank is retained across the V3 one-line buffer.
reg vb_captured=1, vb_line_delayed=1;
reg read_bank_d=0, mirror_d=0, pulse_d=0;
wire [26:0] raw_read=read_bank_d ? raw1 : raw0;
wire [23:0] mirror_read=read_bank_d ? reversed1 : reversed0;
wire mirror_at_x0=(x==0) ? mirror_enable : mirror_line;

always @(posedge clk) begin
    // BRAM reads. Reading the OPPOSITE bank from the currently written line
    // eliminates same-address read/write ambiguity in the mirror path.
    if(ce_in && have_line) begin
        // Access only the completed, opposite bank. The previous code read
        // both banks, including the very RAM being written at this address.
        // Cyclone V M10K read-during-write is not a portable RTL promise.
        if(wr_bank) begin
            raw0 <= line0[x];
            reversed0 <= color0[color_addr];
        end else begin
            raw1 <= line1[x];
            reversed1 <= color1[color_addr];
        end
    end
    if(reset) begin
        x<=0; wr_bank<=0; have_line<=0; de_seen<=0;
        first_live<=0; last_live<=0; first0<=0;first1<=0;
        last0<=0;last1<=0;de_valid0<=0;de_valid1<=0;
        mirror_line<=0; de_prev<=0; started_with_de<=0;
        read_bank_d<=0;mirror_d<=0;pulse_d<=0;
        geom_mode_line<=0;geom_start_line<=0;geom_width_line<=10'd256;
        geom_cursor<=0;geom_phase<=0;geom_mode_d<=0;geom_active_d<=0;
        geom_vs_d<=0;geom_vs_line<=0;vs_line_hist<=0;
        rgb_out<=0;hs_out<=0;vs_out<=0;de_out<=0;ce_out<=0;vb_out<=1;vb_captured<=1;vb_line_delayed<=1;
    end else begin
        ce_out <= pulse_d;
        vb_out <= vb_line_delayed;
        if(pulse_d) begin
            // A one-clock pipeline delay is common to RGB AND sync/DE.
            // Only active RGB is mirrored. No changes to native cadence.
            rgb_out <= geom_mode_d ? (geom_active_d ? mirror_read : 24'd0) :
                        ((mirror_d && raw_read[0]) ? mirror_read : raw_read[26:3]);
            hs_out <= raw_read[2];
            vs_out <= geom_mode_d ? geom_vs_d : raw_read[1];
            de_out <= geom_mode_d ? geom_active_d : raw_read[0];
        end
        pulse_d<=ce_in && have_line;
        if(ce_in) begin
            if(wr_bank) begin
                line1[write_x]<={rgb_in,hs_in,vs_in,de_in};
                color1[write_x]<=rgb_in;
            end else begin
                line0[write_x]<={rgb_in,hs_in,vs_in,de_in};
                color0[write_x]<=rgb_in;
            end
            read_bank_d<=~wr_bank;
            mirror_d<=mirror_at_x0;
            geom_mode_d<=geom_mode_x;
            geom_active_d<=geom_active_x;
            geom_vs_d<= (x==0) ? geom_vs_at_x0 : geom_vs_line;
            if(x==0) begin
                geom_mode_line<=geom_enable;
                geom_start_line<=start_req;
                geom_width_line<=width_req;
                geom_vs_line<=geom_vs_at_x0;
            end
            if(x==LAST) vs_line_hist<={vs_line_hist[V_TOTAL-2:0],vs_in};
            if(x==0 || (geom_dest_x && geom_cursor_valid)) begin
                if(geom_dest_x && geom_cursor_valid) begin
                    geom_cursor<=geom_cursor_next;
                    geom_phase<=geom_phase_next;
                end else if(x==0) begin
                    geom_cursor<=initial_cursor;
                    geom_phase<=0;
                end
            end
            de_prev<=de_in;
            if(x==0) begin
                mirror_line<=mirror_enable;
                started_with_de<=de_in;
            end
            if(reanchor) begin
                // Drop the incomplete wrapped packet. The current DE onset
                // becomes the exact first word of the next coherent line.
                x<=AW'(1);
                first_live<=0;
                last_live<=0;
                de_seen<=1'b1;
                started_with_de<=1'b1;
                have_line<=0;
                mirror_line<=mirror_enable;
            end else begin
                if(de_in) begin
                    if(!de_seen) begin first_live<=x; de_seen<=1; end
                    last_live<=x;
                end
                if(x==0) vb_captured<=vb_in;
                if(x==LAST) begin
                    vb_line_delayed<=vb_captured;
                    if(wr_bank) begin
                        first1<=de_seen ? first_live : 0;
                        last1<=de_seen ? last_live : 0;
                        de_valid1<=de_seen;
                    end else begin
                        first0<=de_seen ? first_live : 0;
                        last0<=de_seen ? last_live : 0;
                        de_valid0<=de_seen;
                    end
                    x<=0;
                    wr_bank<=~wr_bank;
                    have_line<=1;
                    de_seen<=0;
                end else x<=x+1'b1;
            end
        end
    end
end
endmodule
`default_nettype wire
