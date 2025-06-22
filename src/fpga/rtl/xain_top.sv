
//
// Xain'd Sleena core interface for the Analogue Pocket top-level
//
// Instantiated by the real top-level: apf_top
//
import xain_pkg::*;
`define CPU_OVERCLOCK_HACK

`default_nettype none
module xain_top (
	input  wire        clk,     //System clock
    input  wire        reset,               //! Reset
	input  wire        init,
	input  wire        pause,
	input  wire        credits,

	//modifiers
	input wire [7:0] MODSW,

	//inputs
	input wire [7:0] DSW1,
	input wire [7:0] DSW2,
	input wire [7:0] PLAYER1,
	input wire [7:0] PLAYER2,
	input wire SERVICE,
	input wire JAMMA_24,
	input wire JAMMA_b,

	//Video output
	output logic CSYNC,
	output logic [7:0] VIDEO_R,
	output logic [7:0] VIDEO_G,
	output logic [7:0] VIDEO_B,
	output logic CE_PIXEL,
	output logic HBLANK,
	output logic VBLANK,
	output logic HSYNC,
	output logic VSYNC,

	//sound output
    output logic signed [15:0] snd1,
	output logic signed [15:0] snd2,

    input  wire        ioctl_download,
    input  wire [15:0] ioctl_index,
    input  wire        ioctl_wr,
    input  wire [24:0] ioctl_addr,
    input  wire [7:0]  ioctl_data,
	//SDRAM interface
	input  wire        doRefresh,
	input  wire 	   sdr_clk,   //SDRAM clock
    inout  wire [15:0] dram_dq,   // 16 bit bidirectional data bus
    output reg [12:0]  dram_a,    // 13 bit multiplexed address bus
    output wire [1:0]  dram_dqm,  // two byte masks
    output reg  [1:0]  dram_ba,   // two banks
    output wire        dram_we_n, // write enable
    output wire        dram_ras_n,// row address select
    output wire        dram_cas_n,// columns address select
    output wire        dram_cke,  // clock enable
    output wire        dram_clk   // clock for chip
);
	parameter DBG_VIDEO = 0; //1 to enable video debug output
	parameter ROM_INDEX = 16'h1; //0 MiSTer FPGA, 1 Analogue Pocket
	//assign dram_clk = sdr_clk;
	
	///////////////////////////////////////////////////////////////////////
	// SDRAM
	///////////////////////////////////////////////////////////////////////
	//CH0 -> MAINCPU
	//CH1 -> SPRITES
	//CH2 -> BG1
	//CH3 -> BG2/ROM LOADING INTERFACE
	wire [15:0] sdr_mcpu_dout;
	wire [24:0] sdr_mcpu_addr;
	wire sdr_mcpu_req, sdr_mcpu_rdy;

	wire [15:0] sdr_scpu_dout;
	wire [24:0] sdr_scpu_addr;
	wire sdr_scpu_req, sdr_scpu_rdy;

	wire [15:0] sdr_obj_dout;
	wire [24:0] sdr_obj_addr;
	wire sdr_obj_req, sdr_obj_rdy;

	wire [15:0] sdr_bg1_dout;
	wire [24:0] sdr_bg1_addr;
	wire sdr_bg1_req, sdr_bg1_rdy;

	wire [15:0] sdr_bg2_dout;
	wire [24:0] sdr_bg2_addr;
	wire sdr_bg2_req;

	// wire [15:0] sdr_map_dout;
	// wire [24:0] sdr_map_addr;
	// wire sdr_map_req,  sdr_map_rdy;

	reg [24:0] sdr_rom_addr;
	reg [15:0] sdr_rom_data;
	reg [1:0] sdr_rom_be;
	reg sdr_rom_req;

	wire sdr_rom_write = ioctl_download && (ioctl_index == ROM_INDEX); //0 MiSTer FPGA, 1 Analogue Pocket
	// wire [24:0] sdr_ch3_addr = sdr_rom_write ? sdr_rom_addr : sdr_bg2_addr;
	wire [24:0] sdr_ch3_addr = sdr_rom_write ? sdr_rom_addr : sdr_bg2_addr;
	// wire [15:0] sdr_ch3_din = sdr_rom_write ? sdr_rom_data : sdr_cpu_din;
	wire [15:0] sdr_ch3_din = sdr_rom_data;
	// wire [1:0] sdr_ch3_be = sdr_rom_write ? sdr_rom_be : sdr_cpu_wr_sel;
	wire [1:0] sdr_ch3_be = sdr_rom_be;
	// wire sdr_ch3_rnw = sdr_rom_write ? 1'b0 : ~{|sdr_cpu_wr_sel};
	wire sdr_ch3_rnw = sdr_rom_write ? 1'b0 : 1'b1; //or ROM downloading or SDRAM ROM read
	wire sdr_ch3_req = sdr_rom_write ? sdr_rom_req : sdr_bg2_req;
	wire sdr_ch3_rdy;
	wire sdr_bg2_rdy = sdr_ch3_rdy;
	wire sdr_rom_rdy = sdr_ch3_rdy;

	wire [19:0] bram_addr;
	wire [7:0] bram_data;
	wire [5:0] bram_cs;
	wire bram_wr;

	//board_cfg_t board_cfg;

	sdram sdram
	(
		.SDRAM_DQ     (dram_dq),     // 16-bit bidirectional data bus
		.SDRAM_A      (dram_a),      // 13-bit address bus
		.SDRAM_DQML   (dram_dqm[0]),   // Data mask lower byte
		.SDRAM_DQMH   (dram_dqm[1]),   // Data mask higher byte
		.SDRAM_BA     (dram_ba),     // Bank address
		.SDRAM_nCS    (       ),    // Chip select
		.SDRAM_nWE    (dram_we_n),    // Write enable
		.SDRAM_nRAS   (dram_ras_n),   // Row address select
		.SDRAM_nCAS   (dram_cas_n),   // Column address select
		.SDRAM_CKE    (dram_cke),    // Clock enable
		.SDRAM_CLK    (dram_clk),    // Clock for chip
		.doRefresh(doRefresh),
		.init(init),
		.clk(sdr_clk),
	`ifdef CPU_OVERCLOCK_HACK
		.ch0a_addr(24'h0),//cpu_addr[16:0] 64Kb Main CPU + 64Kb Sub CPU
		.ch0a_dout(),
		.ch0a_req(1'b0),
		.ch0a_ready(),

		.ch0b_addr(24'h0),//cpu_addr[16:0] 64Kb Main CPU + 64Kb Sub CPU
		.ch0b_dout(),
		.ch0b_req(1'b0),
		.ch0b_ready(),
	`else    
		.ch0a_addr(sdr_mcpu_addr[24:1]),//cpu_addr[16:0] 64Kb Main CPU + 64Kb Sub CPU
		.ch0a_dout(sdr_mcpu_dout),
		.ch0a_req(sdr_mcpu_req),
		.ch0a_ready(sdr_mcpu_rdy),

		.ch0b_addr(sdr_scpu_addr[24:1]),//cpu_addr[16:0] 64Kb Main CPU + 64Kb Sub CPU
		.ch0b_dout(sdr_scpu_dout),
		.ch0b_req(sdr_scpu_req),
		.ch0b_ready(sdr_scpu_rdy),
	`endif
		.ch1_addr(sdr_obj_addr[24:1]), //16bit address
		.ch1_dout(sdr_obj_dout),
		.ch1_req(sdr_obj_req),
		.ch1_ready(sdr_obj_rdy),

		.ch2_addr(sdr_bg1_addr[24:1]), //16bit address
		.ch2_dout(sdr_bg1_dout),
		.ch2_req(sdr_bg1_req),
		.ch2_ready(sdr_bg1_rdy),

		.ch3_addr(sdr_ch3_addr[24:1]), //16bit address
		.ch3_din(sdr_ch3_din),
		.ch3_dout(sdr_bg2_dout),
		.ch3_be(sdr_ch3_be),
		.ch3_rnw(sdr_ch3_rnw),
		.ch3_req(sdr_ch3_req),
		.ch3_ready(sdr_ch3_rdy)
	);

	wire rom_download = ioctl_download && (ioctl_index == ROM_INDEX);
	rom_loader rom_loader(
		.sys_clk(clk),
		.ram_clk(sdr_clk),

		.ioctl_downl ( rom_download ),
		.ioctl_wr(ioctl_wr && (ioctl_index == ROM_INDEX)),
		.ioctl_data(ioctl_data[7:0]),

		.ioctl_wait(),

		.sdr_addr(sdr_rom_addr),
		.sdr_data(sdr_rom_data),
		.sdr_be(sdr_rom_be),
		.sdr_req(sdr_rom_req),
		.sdr_ack(sdr_rom_rdy),

		.bram_addr(bram_addr),
		.bram_data(bram_data),
		.bram_cs(bram_cs),
		.bram_wr(bram_wr),

		.board_cfg()
	);

	//////////////////////////     CORE     //////////////////////////
	logic [3:0] VIDEO_4R;
	logic [3:0] VIDEO_4G;
	logic [3:0] VIDEO_4B;
	logic HBLANK_CORE, VBLANK_CORE;
	logic HSYNC_CORE, VSYNC_CORE;
	logic CE_PIX;

	XSleenaCore xlc (
		.CLK(clk),
		.SDR_CLK(sdr_clk),
		.RSTn(~reset),
		//Inputs
		.DSW1(DSW1), // 80 Flip Screen On, 40 Cabinet Cocktail, 20 Allow continue Yes, 10 Demo Sounds On, 0C CoinB 1C/1C, 03 CoinA 1C/1C
		.DSW2(DSW2), //
		.PLAYER1(PLAYER1),
		.PLAYER2(PLAYER2),
		.SERVICE(SERVICE),
		.JAMMA_24(1'b1),
		.JAMMA_b(1'b1),
		//Video output
		.VIDEO_R(VIDEO_4R),
		.VIDEO_G(VIDEO_4G),
		.VIDEO_B(VIDEO_4B),
		.PIX_CLK(), //not used
		.CE_PIXEL(CE_PIX),
		.HBLANK(HBLANK_CORE), //NEGATIVE HBLANK
		.VBLANK(VBLANK_CORE), //NEGATIVE VBLANK
		.VSYNC(VSYNC_CORE), //NEGATIVE VSYNC
		.HSYNC(HSYNC_CORE), //NEGATIVE HSYNC
		.CSYNC(CSYNC),
		
		//Memory interface
		//SDRAM
		// .sdr_mcpu_addr(sdr_mcpu_addr),
		// .sdr_mcpu_dout(sdr_mcpu_dout),
		// .sdr_mcpu_req(sdr_mcpu_req),
		// .sdr_mcpu_rdy(sdr_mcpu_rdy),

		// .sdr_scpu_addr(sdr_scpu_addr),
		// .sdr_scpu_dout(sdr_scpu_dout),
		// .sdr_scpu_req(sdr_scpu_req),
		// .sdr_scpu_rdy(sdr_scpu_rdy),

		.sdr_obj_addr(sdr_obj_addr),
		.sdr_obj_dout(sdr_obj_dout),
		.sdr_obj_req(sdr_obj_req),
		.sdr_obj_rdy(sdr_obj_rdy),

		.sdr_bg1_addr(sdr_bg1_addr),
		.sdr_bg1_dout(sdr_bg1_dout),
		.sdr_bg1_req(sdr_bg1_req),
		.sdr_bg1_rdy(sdr_bg1_rdy),

		.sdr_bg2_addr(sdr_bg2_addr),
		.sdr_bg2_dout(sdr_bg2_dout),
		.sdr_bg2_req(sdr_bg2_req),
		.sdr_bg2_rdy(sdr_bg2_rdy),

		// .sdr_map_addr(sdr_map_addr),
		// .sdr_map_dout(sdr_map_dout),
		// .sdr_map_req(sdr_map_req),
		// .sdr_map_rdy(sdr_map_rdy),

		//BRAM
		.bram_addr(bram_addr),
		.bram_data(bram_data),
		.bram_cs(bram_cs),
		.bram_wr(bram_wr),

		//sound output
		.snd1(snd1),
		.snd2(snd2),
		.sample(),

		//coin counters
		//.CUNT1(CUNT1),
		//.CUNT2(CUNT2),
		.pause_rq(pause),
		.credits(credits),
		//HACKS
		.CPU_turbo_mode(MODSW[1])
	);


	//Reverse polarity of blank/sync signals for MiSTer
//	assign HBLANK =  ~HBLANK_CORE;
//	assign VBLANK =  ~VBLANK_CORE;
//	assign HSYNC =   HSYNC_CORE;
//	assign VSYNC =  ~VSYNC_CORE;


	logic [7:0] VIDEO_R2, VIDEO_G2, VIDEO_B2;
	logic DE /* synthesis keep */;
	assign DE = HBLANK_CORE & VBLANK_CORE; //Data Enable, active when not in HBLANK or VBLANK
generate
    if (DBG_VIDEO) begin
		assign VIDEO_G2  = 8'hAA; //10101010 bit pattern for debug
    end
	else begin
		XSleenaCore_RGB4bitLUT G_LUT( .COL_4BIT(VIDEO_4G), .COL_8BIT(VIDEO_G2));
	end
endgenerate

	XSleenaCore_RGB4bitLUT R_LUT( .COL_4BIT(VIDEO_4R), .COL_8BIT(VIDEO_R2));
	XSleenaCore_RGB4bitLUT B_LUT( .COL_4BIT(VIDEO_4B), .COL_8BIT(VIDEO_B2));


	always @(posedge clk) begin
		CE_PIXEL <= CE_PIX;
		VIDEO_R  <= VIDEO_R2 & {8{DE}};
		VIDEO_G  <= VIDEO_G2 & {8{DE}};
		VIDEO_B  <= VIDEO_B2 & {8{DE}};
		HBLANK   <=  ~HBLANK_CORE;
		VBLANK   <=  ~VBLANK_CORE;
		HSYNC    <=   HSYNC_CORE;
		VSYNC    <=  ~VSYNC_CORE;
	end

endmodule