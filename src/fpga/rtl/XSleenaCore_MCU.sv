//XSleenaCore_MCU.sv
//Author: @RndMnkIII
//Date: 02/09/2026
// Implementation of the MCU interface for the XSleenaCore project. 
// This module handles the communication between the main CPU and the MCU.


`default_nettype none
`timescale 1ns/10ps

module XSleenaCore_MCU (
    input wire clk,
	input wire main_2xb, //M1Hn x1 - _HCLKn x2
	input wire enabled,
  	input wire RSTn,
	input wire W3A0En,
	input wire R3A04n,
	input wire R3A06n,
	
	input wire [7:0] DB_in,

	output logic [7:0] DB_out,
	output logic P5ACCEPTn,
	output logic P5READYn,

	//ROM interface
    input bram_wr,
    input [7:0] bram_data,
    input [10:0] bram_addr,
    input bram_cs,
	input wire pause_rq
);
	logic PB1, PB2;

	logic [7:0] ic102_Q;
	ttl_74374_sync_noHiZout ic102(.clk(clk), .cen(W3A0En), .OCn(pb_out[1]), .D(DB_in), .Q(ic102_Q));

	logic ic112A_Q, ic112A_Qn;
	DFF_pseudoAsyncClrPre #(.W(1)) ic112a (
		.clk(clk),
		.din(1'b0),
		.q(ic112A_Q),
		.qn(ic112A_Qn),
		.set(~W3A0En),    // active high
		.clr(~R3A06n),    // active high
		.cen(pb_out[1]) // signal whose edge will trigger the FF
	);

	assign P5ACCEPTn = ic112A_Qn;

	logic [7:0] ic113_D;//MCU PA7-0 out
	ttl_74374_sync_noHiZout ic101(.clk(clk), .cen(pb_out[2]), .OCn(R3A04n), .D(ic113_D), .Q(DB_out));

	logic ic64B; //AND gate
	assign ic64B = R3A06n & R3A04n;

	logic ic112B_Qn;
	DFF_pseudoAsyncClrPre #(.W(1)) ic112b (
		.clk(clk),
		.din(1'b1),
		.q(),
		.qn(ic112B_Qn),
		.set(1'b0),    // active high, in IC is tied to VCC (PRESETn)
		.clr(~ic64B),    // active high, in the IC is tied to CLRn.
		.cen(pb_out[2]) // signal whose edge will trigger the FF
	);

	assign P5READYn = ic112B_Qn;

	(* preserve, noprune *) logic [7:0] pb_out;

	//MCU ROM interface
	logic [7:0] MCU_ROM_Dout;
	logic [10:0] MCU_ROM_Addr;
	logic MCU_ROM_CS;

	SRAM_dual_sync #(.DATA_WIDTH(8), .ADDR_WIDTH(11)) mcu_rom (
		.clk0(clk),
		.clk1(clk),
		.ADDR0(bram_addr[10:0]),
		.ADDR1(MCU_ROM_Addr[10:0]),
		.DATA0(bram_data),
		.DATA1(8'h00),
		.cen0(bram_cs),
		.cen1(MCU_ROM_CS),
		.we0(bram_wr),
		.we1(1'b0),
		.Q0(),
		.Q1(MCU_ROM_Dout)
	);

	logic main_2xb_d;
	always @(posedge clk) main_2xb_d <= main_2xb;
	logic mcu_cen;
	assign mcu_cen = main_2xb & ~main_2xb_d; //make sure that mcu_cen pulse width is 1 clk cycle

	jtframe_6805mcu  u_mcu (
    .rst        ( ~RSTn                          ), //active high
    .clk        ( clk                            ),
    .cen        ( mcu_cen & ~pause_rq & enabled  ),
    .wr         (                                ),
    .addr       (                                ),
    .dout       (                                ),
    .irq        ( ~ic112A_Qn                     ), // active high
    .timer      ( 1'b0                           ), // active high
    // Ports
    .pa_in      ( ic102_Q                        ),
    .pa_out     ( ic113_D                        ),
    .pb_in      ( {8'hFF}                        ),
    .pb_out     ( pb_out                         ),
    .pc_in      ({2'b11,ic112B_Qn,ic112A_Q}      ),
    .pc_out     (                                ),
    // ROM interface
    .rom_addr   ( MCU_ROM_Addr                   ),
    .rom_data   ( MCU_ROM_Dout                   ),
    .rom_cs     ( MCU_ROM_CS                     )
);
endmodule
