
//
// Xain'd Sleena core interface for the Analogue Pocket top-level
//
// Instantiated by the real top-level: apf_top
//

`default_nettype none
module xain_top(

)

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

wire sdr_rom_write = ioctl_download && (ioctl_index == 0);
// wire [24:0] sdr_ch3_addr = sdr_rom_write ? sdr_rom_addr : sdr_bg2_addr;
wire [24:0] sdr_ch3_addr = sdr_rom_write ? sdr_rom_addr : sdr_bg2_addr;
// wire [15:0] sdr_ch3_din = sdr_rom_write ? sdr_rom_data : sdr_cpu_din;
wire [15:0] sdr_ch3_din = sdr_rom_data;
// wire [1:0] sdr_ch3_be = sdr_rom_write ? sdr_rom_be : sdr_cpu_wr_sel;
wire [1:0] sdr_ch3_be = sdr_rom_be;
// wire sdr_ch3_rnw = sdr_rom_write ? 1'b0 : ~{|sdr_cpu_wr_sel};
wire sdr_ch3_rnw = sdr_rom_write ? 1'b0 : 1'b1; //or ROM downloading or SDRAM ROM read
wire sdr_ch3_req = sdr_rom_write ? sdr_rom_req : sdr_bg2_req & ~DBG_SDR_REQ[1];
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
    .SDRAM_DQ     (SDRAM_DQ),     // 16-bit bidirectional data bus
    .SDRAM_A      (SDRAM_A),      // 13-bit address bus
    .SDRAM_DQML   (SDRAM_DQML),   // Data mask lower byte
    .SDRAM_DQMH   (SDRAM_DQMH),   // Data mask higher byte
    .SDRAM_BA     (SDRAM_BA),     // Bank address
    .SDRAM_nCS    (SDRAM_nCS),    // Chip select
    .SDRAM_nWE    (SDRAM_nWE),    // Write enable
    .SDRAM_nRAS   (SDRAM_nRAS),   // Row address select
    .SDRAM_nCAS   (SDRAM_nCAS),   // Column address select
    .SDRAM_CKE    (SDRAM_CKE),    // Clock enable
    .SDRAM_CLK    (SDRAM_CLK)     // SDRAM clock
    .doRefresh(1),
    .init(~pll_init_locked),
    .clk(SDR_CLK),
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
    .ch1_req(sdr_obj_req & ~DBG_SDR_REQ[2]),
    .ch1_ready(sdr_obj_rdy),

    .ch2_addr(sdr_bg1_addr[24:1]), //16bit address
    .ch2_dout(sdr_bg1_dout),
    .ch2_req(sdr_bg1_req & ~DBG_SDR_REQ[0]),
    .ch2_ready(sdr_bg1_rdy),

    .ch3_addr(sdr_ch3_addr[24:1]), //16bit address
    .ch3_din(sdr_ch3_din),
    .ch3_dout(sdr_bg2_dout),
    .ch3_be(sdr_ch3_be),
    .ch3_rnw(sdr_ch3_rnw),
    .ch3_req(sdr_ch3_req),
    .ch3_ready(sdr_ch3_rdy)
);

rom_loader rom_loader(
    .sys_clk(MS_CLK),
    .ram_clk(SDR_CLK),

    .ioctl_wr(ioctl_wr && !ioctl_index), //ioctl_index == 0
    .ioctl_data(ioctl_dout[7:0]),

    .ioctl_wait(ioctl_wait),

    .sdr_addr(sdr_rom_addr),
    .sdr_data(sdr_rom_data),
    .sdr_be(sdr_rom_be),
    .sdr_req(sdr_rom_req),
    .sdr_rdy(sdr_rom_rdy),

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
logic  HBlank, VBlank, HSync, VSync;
logic  HSync2, VSync2;
logic HSYNC, VSYNC;
logic CSYNC;
logic ce_pix;

XSleenaCore xlc (
	.CLK(MS_CLK),
	.SDR_CLK(SDR_CLK),
	.RSTn(~reset),
	.NATIVE_VFREQ(NATIVE_VFREQ),

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
	.CE_PIXEL(ce_pix),
	.HBLANK(HBLANK_CORE), //NEGATIVE HBLANK
	.VBLANK(VBLANK_CORE), //NEGATIVE VBLANK
	.VSYNC(VSYNC_CORE), //NEGATIVE VSYNC
	.HSYNC(HSYNC_CORE), //NEGATIVE HSYNC
	.CSYNC(CSYNC),
	
	//Memory interface
	//SDRAM
    .sdr_mcpu_addr(sdr_mcpu_addr),
    .sdr_mcpu_dout(sdr_mcpu_dout),
    .sdr_mcpu_req(sdr_mcpu_req),
    .sdr_mcpu_rdy(sdr_mcpu_rdy),

    .sdr_scpu_addr(sdr_scpu_addr),
    .sdr_scpu_dout(sdr_scpu_dout),
    .sdr_scpu_req(sdr_scpu_req),
    .sdr_scpu_rdy(sdr_scpu_rdy),

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
	  .sample(sample),

	//coin counters
	//.CUNT1(CUNT1),
	//.CUNT2(CUNT2),
	 .pause_rq(system_pause),
	//HACKS
	.CPU_turbo_mode(turbo_mode)
);

//Audio
logic [15:0] snd1, snd2;
logic sample;
assign AUDIO_S = 1'b1; //Signed audio samples
assign AUDIO_MIX = 2'b11; //0 No Mix, 1 25%, 2 50%, 3 100% mono

//synchronize audio
reg [15:0] snd1_r, snd2_r;
always @(posedge CLK_AUDIO) begin
	snd1_r <= snd1;
	snd2_r <= snd2;
	AUDIO_L <= snd1_r;
	AUDIO_R <= snd2_r;
end

//Reverse polarity of blank/sync signals for MiSTer
assign HBlank=  ~HBLANK_CORE;
assign VBlank=  ~VBLANK_CORE;
assign HSync =   HSYNC_CORE;
assign VSync =  ~VSYNC_CORE;


assign CLK_VIDEO = MS_CLK;

logic [7:0] R, G, B;
XSleenaCore_RGB4bitLUT R_LUT( .COL_4BIT(VIDEO_4R), .COL_8BIT(R));
XSleenaCore_RGB4bitLUT G_LUT( .COL_4BIT(VIDEO_4G), .COL_8BIT(G));
XSleenaCore_RGB4bitLUT B_LUT( .COL_4BIT(VIDEO_4B), .COL_8BIT(B));

// H/V offset
// wire [3:0]	hoffset = status[14:11];
// wire [3:0]	voffset = status[18:15];

assign VIDEO_ARX = (!ar) ? ( no_rotate ? 12'd4 : 12'd3 ) : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? ( no_rotate ? 12'd3 : 12'd4 ) : 12'd0;
/////////////////////// ARCADE VIDEO /////////////////////////////
wire [21:0] gamma_bus;
wire        direct_video;

// Video rotation 
wire no_rotate = ~status[10];
wire rotate_ccw = status[7];
wire video_rotated;
wire flip = status[6];

arcade_video #(256,24) arcade_video
(
        .*,
		.fx(scandoubler_fx),
		.gamma_bus(gamma_bus),
		.forced_scandoubler(forced_scandoubler),
        .clk_video(MS_CLK),
        .ce_pix(ce_pix),
	    .CE_PIXEL(CE_PIXEL),
	    .RGB_in({R,G,B}),
        .HBlank(HBlank),
        .VBlank(VBlank),
        .HSync(HSync),
        .VSync(VSync)
);

screen_rotate screen_rotate(.*);//xain_top.sv

endmodule
