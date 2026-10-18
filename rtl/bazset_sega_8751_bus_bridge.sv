// BAZSET Sega System 1/2 protected board MCU-to-Z80 bus selection.
// Independent source-only donor interface, not connected to the active core.
// Reference: MAME 0.289 system1.cpp mcu_control_w/mcu_data_r/mcu_data_w.
// Note this bridge does NOT execute an 8751 MCU ROM. A real 8051 core and
// Z80 RAM/IO arbitration are required before protected Choplifter can boot.
module bazset_sega_8751_bus_bridge (
 input wire [7:0] mcu_port1,
 input wire [15:0] mcu_movx_address,
 input wire [7:0] mcu_write_data,
 input wire mcu_movx_read,
 input wire mcu_movx_write,
 input wire [7:0] z80_program_read,
 input wire [7:0] banked_program_read,
 input wire [7:0] z80_io_read,
 output wire z80_busreq,
 output wire z80_interrupt_n,
 output wire program_write,
 output wire io_write,
 output wire [15:0] write_address,
 output wire [7:0] write_data,
 output reg [7:0] mcu_read_data,
 output wire unhandled_access
);
 wire [1:0] mode = mcu_port1[4:3];
 assign z80_busreq = mcu_port1[6];
 assign z80_interrupt_n = mcu_port1[0];
 assign program_write = mcu_movx_write && mode == 2'd0;
 assign io_write = mcu_movx_write && mode == 2'd2;
 assign write_address = mcu_movx_address;
 assign write_data = mcu_write_data;
 assign unhandled_access = (mcu_movx_read && mode == 2'd3) ||
                           (mcu_movx_write && (mode == 2'd1 || mode == 2'd3));
 always @* begin
   case (mode)
     2'd0: mcu_read_data = z80_program_read;
     2'd1: mcu_read_data = banked_program_read;
     2'd2: mcu_read_data = z80_io_read;
     default: mcu_read_data = 8'hff;
   endcase
 end
endmodule
