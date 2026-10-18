// BAZSET Sega System 1/2 — source-only experimental 8-bit cheat reader.
// MiSTer arcade 16-byte code: flags[31:0], address[31:0], compare[31:0], data[31:0].
// Supports single-byte compare/replacement/OR/AND only. Wider codes are rejected,
// NOT silently truncated. Does not change RAM contents or game clocks.
// Connected to Z80 CPU read mux in b22 source only. No RBF has been built.
module bazset_cheat_reader8 #(
  parameter integer MAX_CODES = 32
)(
  input wire clk,
  input wire clear,                   // begin a new host cheat-code download or game
  input wire [128:0] code,            // {valid, flags, address, compare, data}
  input wire enable,
  input wire cpu_memory_read,
  input wire cpu_opcode_fetch,
  input wire [15:0] cpu_address,
  input wire [7:0] cpu_data_in,
  output reg [7:0] cpu_data_out,
  input wire cpu_memory_write,
  input wire [7:0] cpu_write_data_in,
  output reg [7:0] cpu_write_data_out,
  output wire available
);
  localparam integer CW = $clog2(MAX_CODES+1);
  reg [CW-1:0] count = 0;
  reg [15:0] code_addr [0:MAX_CODES-1];
  reg [7:0] code_cmp [0:MAX_CODES-1];
  reg [7:0] code_value [0:MAX_CODES-1];
  reg code_compare [0:MAX_CODES-1];
  reg [1:0] code_method [0:MAX_CODES-1];
  reg valid [0:MAX_CODES-1];
  integer i;
  initial begin
    for (i=0; i<MAX_CODES; i=i+1) valid[i]=1'b0;
  end
  assign available = |count;
  wire [31:0] incoming_flags = code[127:96];
  wire [31:0] incoming_addr  = code[95:64];
  wire [31:0] incoming_cmp   = code[63:32];
  wire [31:0] incoming_value = code[31:0];
  always @(posedge clk) begin
    if (clear) begin
      count <= 0;
      for (i=0; i<MAX_CODES; i=i+1) valid[i] <= 1'b0;
    end else if (code[128] && count < MAX_CODES &&
                 incoming_addr[31:16] == 0 &&
                 incoming_flags[6:4] == 3'd1 &&
                 incoming_flags[9:8] != 2'd3) begin
      // Width 1 only: wider MRA cheat commands require a word-aware adapter.
      code_addr[count]    <= incoming_addr[15:0];
      code_cmp[count]     <= incoming_cmp[7:0];
      code_value[count]   <= incoming_value[7:0];
      code_compare[count] <= incoming_flags[0];
      code_method[count]  <= incoming_flags[9:8];
      valid[count] <= 1'b1;
      count <= count + 1'b1;
    end
  end

  // Balanced per-bit composition of transformations; no 32-stage priority MUX.
  // For each matching code, f(x) = (x & AND_MASK) | OR_MASK.
  // Adjacent transforms compose as: A = Aleft & Aright;
  // O = (Oleft & Aright) | Oright.  This is associative and exactly
  // preserves the original MRA ordered replacement, OR, AND semantics.
  localparam integer TREE_LEAVES = (1 << $clog2(MAX_CODES));
  wire [7:0] ra [1:2*TREE_LEAVES-1];
  wire [7:0] ro [1:2*TREE_LEAVES-1];
  wire [7:0] wa [1:2*TREE_LEAVES-1];
  wire [7:0] wo [1:2*TREE_LEAVES-1];
  genvar g;
  generate
    for (g=0; g<TREE_LEAVES; g=g+1) begin: cheat_leaf
      if (g < MAX_CODES) begin: valid_slot
        wire active_read = valid[g] && code_addr[g] == cpu_address &&
              (!code_compare[g] || code_cmp[g] == cpu_data_in);
        wire active_write = valid[g] && code_addr[g] == cpu_address &&
              (!code_compare[g] || code_cmp[g] == cpu_write_data_in);
        wire [7:0] transform_and = (code_method[g] == 2'd1) ? 8'hff :
                                   (code_method[g] == 2'd2) ? code_value[g] : 8'h00;
        wire [7:0] transform_or  = (code_method[g] == 2'd2) ? 8'h00 : code_value[g];
        assign ra[TREE_LEAVES+g] = active_read  ? transform_and : 8'hff;
        assign ro[TREE_LEAVES+g] = active_read  ? transform_or  : 8'h00;
        assign wa[TREE_LEAVES+g] = active_write ? transform_and : 8'hff;
        assign wo[TREE_LEAVES+g] = active_write ? transform_or  : 8'h00;
      end else begin: empty_slot
        assign ra[TREE_LEAVES+g] = 8'hff;
        assign ro[TREE_LEAVES+g] = 8'h00;
        assign wa[TREE_LEAVES+g] = 8'hff;
        assign wo[TREE_LEAVES+g] = 8'h00;
      end
    end
    for (g=1; g<TREE_LEAVES; g=g+1) begin: cheat_branch
      assign ra[g] = ra[2*g] & ra[2*g+1];
      assign ro[g] = (ro[2*g] & ra[2*g+1]) | ro[2*g+1];
      assign wa[g] = wa[2*g] & wa[2*g+1];
      assign wo[g] = (wo[2*g] & wa[2*g+1]) | wo[2*g+1];
    end
  endgenerate
  always @* begin
    cpu_data_out = cpu_data_in;
    if (enable && cpu_memory_read && !cpu_opcode_fetch)
      cpu_data_out = (cpu_data_in & ra[1]) | ro[1];
    cpu_write_data_out = cpu_write_data_in;
    if (enable && cpu_memory_write && cpu_address[15:12] == 4'hc)
      cpu_write_data_out = (cpu_write_data_in & wa[1]) | wo[1];
  end
endmodule
