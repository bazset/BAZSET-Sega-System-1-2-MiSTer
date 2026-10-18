`default_nettype none
// BAZSET HDMI-only output presentation. Keep the game native H/V cadence and
// HS/VS timing unchanged. Delay RGB, active DE and vertical blank together
// by N complete 320-dot scanlines, adding black margin above the image.
// 0 = literal B23 signal bypass. HPS OSD range: 0,2,4,...,14 lines.
// Do not enable on native direct video; top-level gates lines_down=0.
module bz_hdmi_picture_down #(
  parameter integer H_TOTAL = 320,
  parameter integer LINES_BUFFERED = 16
)(
  input wire clk,reset,
  input wire ce_in,
  input wire [11:0] rgb_in,
  input wire hs_in,vs_in,de_in,vb_in,
  input wire [2:0] lines_down,
  output wire ce_out,
  output wire [11:0] rgb_out,
  output wire hs_out,vs_out,de_out,vb_out
);
localparam integer RING_PIXELS=H_TOTAL*LINES_BUFFERED;
localparam integer AW=$clog2(RING_PIXELS);
localparam [AW-1:0] RING_LAST=AW'(RING_PIXELS-1);
// Each word: RGB[11:0], DE, VB. One read + one write per native CE.
// 16x320x14 bits of M10K RAM. Never buffer or perturb the game clocks.
(* ramstyle="M10K" *) reg [13:0] line_ring[0:RING_PIXELS-1];
reg [AW-1:0] wptr=0;
reg [AW-1:0] filled=0;
reg [2:0] active_setting=0;
reg vs_prev=0;
// Max shift=14 scanlines; at least 2 lines of the circular buffer remain.
wire [AW-1:0] delay_pixels=AW'({active_setting,9'd0})+
                             AW'({active_setting,7'd0}); // setting*640
wire [AW-1:0] readptr=(wptr>=delay_pixels)?
     (wptr-delay_pixels):
     (wptr+AW'(RING_PIXELS)-delay_pixels);
reg [13:0] sample=0;
reg sample_valid=0;
reg hs_pipe=0,vs_pipe=0,ce_pipe=0;
// Dedicated synchronous RAM ports without reset on the read-data register.
// Quartus 17 otherwise maps the whole 16-line buffer into flip-flops.
always @(posedge clk) begin
  if(ce_in) begin
    line_ring[wptr]<={rgb_in,de_in,vb_in};
    sample<=line_ring[readptr];
  end
end
// VS/HS remain at original line positions. Delaying RGB/DE/VB relative
// to VS physically shifts the active image inside the HDMI scaler's frame.
always @(posedge clk) begin
  ce_pipe<=ce_in;
  if(reset) begin
    wptr<=0;
    filled<=0;
    active_setting<=0;
    vs_prev<=0;
    sample_valid<=0;
    hs_pipe<=0;
    vs_pipe<=0;
    ce_pipe<=0;
  end else if(ce_in) begin
    sample_valid<=filled>=delay_pixels;
    hs_pipe<=hs_in;
    vs_pipe<=vs_in;
    if(wptr==RING_LAST) wptr<=0;
    else wptr<=wptr+1'b1;
    if(filled<RING_LAST) filled<=filled+1'b1;
    vs_prev<=vs_in;
    // OSD setting changes take effect on frame sync, avoiding torn frames.
    if(vs_in && !vs_prev) active_setting<=lines_down;
  end
end

// Exact no-change/default bypass: existing V3 signals remain untouched.
wire enabled=(active_setting!=0);
assign ce_out=enabled ? ce_pipe : ce_in;
assign hs_out=enabled ? hs_pipe : hs_in;
assign vs_out=enabled ? vs_pipe : vs_in;
assign rgb_out=enabled ? (sample_valid ? sample[13:2] : 12'd0):rgb_in;
assign de_out=enabled ? (sample_valid ? sample[1] : 1'b0):de_in;
assign vb_out=enabled ? (sample_valid ? sample[0] : 1'b1):vb_in;
endmodule
`default_nettype wire
