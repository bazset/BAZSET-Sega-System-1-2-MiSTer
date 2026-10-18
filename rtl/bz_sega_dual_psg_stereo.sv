// BAZSET Sega System 1/2: output-only optional enhanced stereo.
// The genuine arcade signal is mono. Stereo is an optional artistic enhancement.
// Match authentic mono exactly at pan_depth==0; 0 is the power-on/default setting.
// Center=sum original psg0*102 + psg1*154; both channels symmetrically
// offset the ORIGINAL unmodified mono PCM by +/- depth*(psg0-psg1).
// This preserves the average PCM and never changes PSG, Z80 or game clocks.
module bz_sega_dual_psg_stereo #(
 parameter integer STEP_CYCLES = 8192
)(
 input wire clk,
 input wire reset,
 input wire enhanced_stereo,
 input wire [15:0] original_mono_pcm,
 input wire [7:0] psg_2mhz,
 input wire [7:0] psg_4mhz,
 output wire [15:0] audio_l,
 output wire [15:0] audio_r
);
 reg [5:0] pan_depth=6'd0;
 reg [15:0] ramp_counter=16'd0;
 always @(posedge clk or posedge reset) begin
  if (reset) begin
   pan_depth <= 6'd0;
   ramp_counter <= 16'd0;
  end else if (ramp_counter == STEP_CYCLES-1) begin
   ramp_counter <= 0;
   if (enhanced_stereo && pan_depth<6'd32)
    pan_depth <= pan_depth+1'b1;
   else if (!enhanced_stereo && pan_depth!=0)
    pan_depth <= pan_depth-1'b1;
  end else
   ramp_counter <= ramp_counter+1'b1;
 end

 wire signed [9:0] psg_difference =
   $signed({2'b00,psg_2mhz})-$signed({2'b00,psg_4mhz});
 wire signed [16:0] pan_delta =
   psg_difference * $signed({1'b0,pan_depth});
 wire signed [18:0] left_sum =
   $signed({3'b000,original_mono_pcm}) + pan_delta;
 wire signed [18:0] right_sum =
   $signed({3'b000,original_mono_pcm}) - pan_delta;
 function [15:0] saturate_unsigned_16;
  input signed [18:0] sample;
  begin
   if (sample<0) saturate_unsigned_16=16'h0000;
   else if (sample>19'sd65535) saturate_unsigned_16=16'hffff;
   else saturate_unsigned_16=sample[15:0];
  end
 endfunction
 assign audio_l = (pan_depth==0) ?
  original_mono_pcm : saturate_unsigned_16(left_sum);
 assign audio_r = (pan_depth==0) ?
  original_mono_pcm : saturate_unsigned_16(right_sum);
endmodule
