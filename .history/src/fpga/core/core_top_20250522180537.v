//
// User core top-level
//
// Instantiated by the real top-level: apf_top
//

`default_nettype none

module core_top (

    //
    // physical connections
    //

    ///////////////////////////////////////////////////
    // clock inputs 74.25mhz. not phase aligned, so treat these domains as asynchronous

    input wire clk_74a,  // mainclk1
    input wire clk_74b,  // mainclk1 

    ///////////////////////////////////////////////////
    // cartridge interface
    // switches between 3.3v and 5v mechanically
    // output enable for multibit translators controlled by pic32

    // GBA AD[15:8]
    inout  wire [7:0] cart_tran_bank2,
    output wire       cart_tran_bank2_dir,

    // GBA AD[7:0]
    inout  wire [7:0] cart_tran_bank3,
    output wire       cart_tran_bank3_dir,

    // GBA A[23:16]
    inout  wire [7:0] cart_tran_bank1,
    output wire       cart_tran_bank1_dir,

    // GBA [7] PHI#
    // GBA [6] WR#
    // GBA [5] RD#
    // GBA [4] CS1#/CS#
    //     [3:0] unwired
    inout  wire [7:4] cart_tran_bank0,
    output wire       cart_tran_bank0_dir,

    // GBA CS2#/RES#
    inout  wire cart_tran_pin30,
    output wire cart_tran_pin30_dir,
    // when GBC cart is inserted, this signal when low or weak will pull GBC /RES low with a special circuit
    // the goal is that when unconfigured, the FPGA weak pullups won't interfere.
    // thus, if GBC cart is inserted, FPGA must drive this high in order to let the level translators
    // and general IO drive this pin.
    output wire cart_pin30_pwroff_reset,

    // GBA IRQ/DRQ
    inout  wire cart_tran_pin31,
    output wire cart_tran_pin31_dir,

    // infrared
    input  wire port_ir_rx,
    output wire port_ir_tx,
    output wire port_ir_rx_disable,

    // GBA link port
    inout  wire port_tran_si,
    output wire port_tran_si_dir,
    inout  wire port_tran_so,
    output wire port_tran_so_dir,
    inout  wire port_tran_sck,
    output wire port_tran_sck_dir,
    inout  wire port_tran_sd,
    output wire port_tran_sd_dir,

    ///////////////////////////////////////////////////
    // cellular psram 0 and 1, two chips (64mbit x2 dual die per chip)

    output wire [21:16] cram0_a,
    inout  wire [ 15:0] cram0_dq,
    input  wire         cram0_wait,
    output wire         cram0_clk,
    output wire         cram0_adv_n,
    output wire         cram0_cre,
    output wire         cram0_ce0_n,
    output wire         cram0_ce1_n,
    output wire         cram0_oe_n,
    output wire         cram0_we_n,
    output wire         cram0_ub_n,
    output wire         cram0_lb_n,

    output wire [21:16] cram1_a,
    inout  wire [ 15:0] cram1_dq,
    input  wire         cram1_wait,
    output wire         cram1_clk,
    output wire         cram1_adv_n,
    output wire         cram1_cre,
    output wire         cram1_ce0_n,
    output wire         cram1_ce1_n,
    output wire         cram1_oe_n,
    output wire         cram1_we_n,
    output wire         cram1_ub_n,
    output wire         cram1_lb_n,

    ///////////////////////////////////////////////////
    // sdram, 512mbit 16bit

    output wire [12:0] dram_a,
    output wire [ 1:0] dram_ba,
    inout  wire [15:0] dram_dq,
    output wire [ 1:0] dram_dqm,
    output wire        dram_clk,
    output wire        dram_cke,
    output wire        dram_ras_n,
    output wire        dram_cas_n,
    output wire        dram_we_n,

    ///////////////////////////////////////////////////
    // sram, 1mbit 16bit

    output wire [16:0] sram_a,
    inout  wire [15:0] sram_dq,
    output wire        sram_oe_n,
    output wire        sram_we_n,
    output wire        sram_ub_n,
    output wire        sram_lb_n,

    ///////////////////////////////////////////////////
    // vblank driven by dock for sync in a certain mode

    input wire vblank,

    ///////////////////////////////////////////////////
    // i/o to 6515D breakout usb uart

    output wire dbg_tx,
    input  wire dbg_rx,

    ///////////////////////////////////////////////////
    // i/o pads near jtag connector user can solder to

    output wire user1,
    input  wire user2,

    ///////////////////////////////////////////////////
    // RFU internal i2c bus 

    inout  wire aux_sda,
    output wire aux_scl,

    ///////////////////////////////////////////////////
    // RFU, do not use
    output wire vpll_feed,


    //
    // logical connections
    //

    ///////////////////////////////////////////////////
    // video, audio output to scaler
    output wire [23:0] video_rgb,
    output wire        video_rgb_clock,
    output wire        video_rgb_clock_90,
    output wire        video_de,
    output wire        video_skip,
    output wire        video_vs,
    output wire        video_hs,

    output wire audio_mclk,
    input  wire audio_adc,
    output wire audio_dac,
    output wire audio_lrck,

    ///////////////////////////////////////////////////
    // bridge bus connection
    // synchronous to clk_74a
    output wire        bridge_endian_little,
    input  wire [31:0] bridge_addr,
    input  wire        bridge_rd,
    output reg  [31:0] bridge_rd_data,
    input  wire        bridge_wr,
    input  wire [31:0] bridge_wr_data,

    ///////////////////////////////////////////////////
    // controller data
    // 
    // key bitmap:
    //   [0]    dpad_up
    //   [1]    dpad_down
    //   [2]    dpad_left
    //   [3]    dpad_right
    //   [4]    face_a
    //   [5]    face_b
    //   [6]    face_x
    //   [7]    face_y
    //   [8]    trig_l1
    //   [9]    trig_r1
    //   [10]   trig_l2
    //   [11]   trig_r2
    //   [12]   trig_l3
    //   [13]   trig_r3
    //   [14]   face_select
    //   [15]   face_start
    // joy values - unsigned
    //   [ 7: 0] lstick_x
    //   [15: 8] lstick_y
    //   [23:16] rstick_x
    //   [31:24] rstick_y
    // trigger values - unsigned
    //   [ 7: 0] ltrig
    //   [15: 8] rtrig
    //
    input wire [15:0] cont1_key,
    input wire [15:0] cont2_key,
    input wire [15:0] cont3_key,
    input wire [15:0] cont4_key,
    input wire [31:0] cont1_joy,
    input wire [31:0] cont2_joy,
    input wire [31:0] cont3_joy,
    input wire [31:0] cont4_joy,
    input wire [15:0] cont1_trig,
    input wire [15:0] cont2_trig,
    input wire [15:0] cont3_trig,
    input wire [15:0] cont4_trig

);

  // not using the IR port, so turn off both the LED, and
  // disable the receive circuit to save power
  assign port_ir_tx              = 0;
  assign port_ir_rx_disable      = 1;

  // bridge endianness
  assign bridge_endian_little    = 0;

  // cart is unused, so set all level translators accordingly
  // directions are 0:IN, 1:OUT
  // assign cart_tran_bank3         = 8'hzz;
  // assign cart_tran_bank3_dir     = 1'b0;
  // assign cart_tran_bank2         = 8'hzz;
  // assign cart_tran_bank2_dir     = 1'b0;
  // assign cart_tran_bank1         = 8'hzz;
  // assign cart_tran_bank1_dir     = 1'b0;
  // assign cart_tran_bank0         = 4'hf;
  // assign cart_tran_bank0_dir     = 1'b1;
  // assign cart_tran_pin30         = 1'b0;  // reset or cs2, we let the hw control it by itself
  // assign cart_tran_pin30_dir     = 1'bz;
  // assign cart_pin30_pwroff_reset = 1'b0;  // hardware can control this
  // assign cart_tran_pin31         = 1'bz;  // input
  // assign cart_tran_pin31_dir     = 1'b0;  // input

  // link port is input only
  assign port_tran_so            = 1'bz;
  assign port_tran_so_dir        = 1'b0;  // SO is output only
  assign port_tran_si            = 1'bz;
  assign port_tran_si_dir        = 1'b0;  // SI is input only
  assign port_tran_sck           = 1'bz;
  assign port_tran_sck_dir       = 1'b0;  // clock direction can change
  assign port_tran_sd            = 1'bz;
  assign port_tran_sd_dir        = 1'b0;  // SD is input and not used

  // tie off the rest of the pins we are not using
  assign cram0_a                 = 'h0;
  assign cram0_dq                = {16{1'bZ}};
  assign cram0_clk               = 0;
  assign cram0_adv_n             = 1;
  assign cram0_cre               = 0;
  assign cram0_ce0_n             = 1;
  assign cram0_ce1_n             = 1;
  assign cram0_oe_n              = 1;
  assign cram0_we_n              = 1;
  assign cram0_ub_n              = 1;
  assign cram0_lb_n              = 1;

  assign cram1_a                 = 'h0;
  assign cram1_dq                = {16{1'bZ}};
  assign cram1_clk               = 0;
  assign cram1_adv_n             = 1;
  assign cram1_cre               = 0;
  assign cram1_ce0_n             = 1;
  assign cram1_ce1_n             = 1;
  assign cram1_oe_n              = 1;
  assign cram1_we_n              = 1;
  assign cram1_ub_n              = 1;
  assign cram1_lb_n              = 1;

  assign dram_a                  = 'h0;
  assign dram_ba                 = 'h0;
  assign dram_dq                 = {16{1'bZ}};
  assign dram_dqm                = 'h0;
  assign dram_clk                = 'h0;
  assign dram_cke                = 'h0;
  assign dram_ras_n              = 'h1;
  assign dram_cas_n              = 'h1;
  assign dram_we_n               = 'h1;

  assign sram_a                  = 'h0;
  assign sram_dq                 = {16{1'bZ}};
  assign sram_oe_n               = 1;
  assign sram_we_n               = 1;
  assign sram_ub_n               = 1;
  assign sram_lb_n               = 1;

  assign dbg_tx                  = 1'bZ;
  assign user1                   = 1'bZ;
  assign aux_scl                 = 1'bZ;
  assign vpll_feed               = 1'bZ;


  // for bridge write data, we just broadcast it to all bus devices
  // for bridge read data, we have to mux it
  // add your own devices here
  always @(*) begin
    casex (bridge_addr)
      default: begin
        bridge_rd_data <= 0;
      end
      32'h10xxxxxx: begin
        // example
        // bridge_rd_data <= example_device_data;
        bridge_rd_data <= 0;
      end
      32'hF8xxxxxx: begin
        bridge_rd_data <= cmd_bridge_rd_data;
      end
    endcase
  end


  //
  // host/target command handler
  //
  wire reset_n;  // driven by host commands, can be used as core-wide reset
  wire [31:0] cmd_bridge_rd_data;

  wire pll_core_locked_s;
  synch_3 s01(pll_core_locked, pll_core_locked_s, clk_74a);

  // bridge host commands
  // synchronous to clk_74a
  wire status_boot_done = pll_core_locked_s;
  wire status_setup_done = pll_core_locked_s;  // rising edge triggers a target command
  wire status_running = reset_n;  // we are running as soon as reset_n goes high

  wire dataslot_requestread;
  wire [15:0] dataslot_requestread_id;
  wire dataslot_requestread_ack = 1;
  wire dataslot_requestread_ok = 1;

  wire dataslot_requestwrite;
  wire [15:0] dataslot_requestwrite_id;
  wire dataslot_requestwrite_ack = 1;
  wire dataslot_requestwrite_ok = 1;

  wire dataslot_allcomplete;

  wire savestate_supported;
  wire [31:0] savestate_addr;
  wire [31:0] savestate_size;
  wire [31:0] savestate_maxloadsize;

  wire savestate_start;
  wire savestate_start_ack;
  wire savestate_start_busy;
  wire savestate_start_ok;
  wire savestate_start_err;

  wire savestate_load;
  wire savestate_load_ack;
  wire savestate_load_busy;
  wire savestate_load_ok;
  wire savestate_load_err;

  wire osnotify_inmenu;

  // bridge target commands
  // synchronous to clk_74a


  // bridge data slot access

  wire [9:0] datatable_addr;
  wire datatable_wren;
  wire [31:0] datatable_data;
  wire [31:0] datatable_q;

  core_bridge_cmd icb (

      .clk    (clk_74a),
      .reset_n(reset_n),

      .bridge_endian_little(bridge_endian_little),
      .bridge_addr         (bridge_addr),
      .bridge_rd           (bridge_rd),
      .bridge_rd_data      (cmd_bridge_rd_data),
      .bridge_wr           (bridge_wr),
      .bridge_wr_data      (bridge_wr_data),

      .status_boot_done (status_boot_done),
      .status_setup_done(status_setup_done),
      .status_running   (status_running),

      .dataslot_requestread    (dataslot_requestread),
      .dataslot_requestread_id (dataslot_requestread_id),
      .dataslot_requestread_ack(dataslot_requestread_ack),
      .dataslot_requestread_ok (dataslot_requestread_ok),

      .dataslot_requestwrite    (dataslot_requestwrite),
      .dataslot_requestwrite_id (dataslot_requestwrite_id),
      .dataslot_requestwrite_ack(dataslot_requestwrite_ack),
      .dataslot_requestwrite_ok (dataslot_requestwrite_ok),

      .dataslot_allcomplete(dataslot_allcomplete),

      .savestate_supported  (savestate_supported),
      .savestate_addr       (savestate_addr),
      .savestate_size       (savestate_size),
      .savestate_maxloadsize(savestate_maxloadsize),

      .savestate_start     (savestate_start),
      .savestate_start_ack (savestate_start_ack),
      .savestate_start_busy(savestate_start_busy),
      .savestate_start_ok  (savestate_start_ok),
      .savestate_start_err (savestate_start_err),

      .savestate_load     (savestate_load),
      .savestate_load_ack (savestate_load_ack),
      .savestate_load_busy(savestate_load_busy),
      .savestate_load_ok  (savestate_load_ok),
      .savestate_load_err (savestate_load_err),

      .osnotify_inmenu(osnotify_inmenu),

      .datatable_addr(datatable_addr),
      .datatable_wren(datatable_wren),
      .datatable_data(datatable_data),
      .datatable_q   (datatable_q)
  );

    //!-------------------------------------------------------------------------
    //! APF Bridge Read Data
    //!-------------------------------------------------------------------------
    wire [31:0] int_bridge_rd_data;
    localparam [7:0] ADDRESS_ANALOGIZER_CONFIG = 8'hF7;

    // Synchronize nvm_bridge_rd_data into clk_74a domain before usage
    synch_3 #(32) u_sync_nvm(nvm_bridge_rd_data, nvm_bridge_rd_data_s, clk_74a);

    always_comb begin
        casex(bridge_addr)
            32'hF8xxxxxx:                                begin bridge_rd_data <= cmd_bridge_rd_data;        end // APF Bridge (Reserved)
            32'hF0000000:                                begin bridge_rd_data <= int_bridge_rd_data;        end // Reset
            32'hF0000010:                                begin bridge_rd_data <= int_bridge_rd_data;        end // Service Mode Switch
            32'hF1000000:                                begin bridge_rd_data <= int_bridge_rd_data;        end // DIP Switches
            32'hF2000000:                                begin bridge_rd_data <= int_bridge_rd_data;        end // Modifiers
            32'hF3000000:                                begin bridge_rd_data <= int_bridge_rd_data;        end // A/V Filters
            32'hF4000000:                                begin bridge_rd_data <= int_bridge_rd_data;        end // Extra DIP Switches
            32'hF5000000:                                begin bridge_rd_data <= int_bridge_rd_data;        end // NVRAM Size
            {ADDRESS_ANALOGIZER_CONFIG,24'h0}:           begin bridge_rd_data <= analogizer_bridge_rd_data; end // Analogizer
            32'hFA000000:                                begin bridge_rd_data <= int_bridge_rd_data;        end // Status Low  [31:0]
            32'hFB000000:                                begin bridge_rd_data <= int_bridge_rd_data;        end // Status High [63:32]
            32'hFC000000:                                begin bridge_rd_data <= int_bridge_rd_data;        end // Inputs
            32'hA0000000:                                begin bridge_rd_data <= int_bridge_rd_data;        end // Analogizer Settings
            default:                                     begin bridge_rd_data <= 32'h0;                     end
        endcase
    end

    //!-------------------------------------------------------------------------
    //! Pause Core (Analogue OS Menu/Module Request)
    //!-------------------------------------------------------------------------
    wire pause_core, pause_req;

    pause_crtl u_core_pause
    (
        .clk_sys    ( clk_sys         ),
        .os_inmenu  ( osnotify_inmenu ),
        .pause_req  ( pause_req       ),
        .pause_core ( pause_core      )
    );
  //!-------------------------------------------------------------------------
  //! Data I/O
  //!-------------------------------------------------------------------------
  wire              ioctl_download;
  wire       [15:0] ioctl_index;
  wire              ioctl_wr;
  wire [DIO_AW-1:0] ioctl_addr;
  wire [DIO_DW-1:0] ioctl_data;

  data_io #(.MASK(DIO_MASK),.AW(DIO_AW),.DW(DIO_DW),.DELAY(DIO_DELAY),.HOLD(DIO_HOLD)) u_pocket_data_io
  (
      // Clocks and Reset
      .clk_74a                  ( clk_74a                  ), // [i]
      .clk_memory               ( clk_sys                  ), // [i]
      // Pocket Bridge Slots
      .dataslot_requestwrite    ( dataslot_requestwrite    ), // [i]
      .dataslot_requestwrite_id ( dataslot_requestwrite_id ), // [i]
      .dataslot_allcomplete     ( dataslot_allcomplete     ), // [i]
      // MPU -> FPGA (MPU Write to FPGA)
      // Pocket Bridge
      .bridge_endian_little     ( bridge_endian_little     ), // [i]
      .bridge_addr              ( bridge_addr              ), // [i]
      .bridge_wr                ( bridge_wr                ), // [i]
      .bridge_wr_data           ( bridge_wr_data           ), // [i]
      // Controller Interface
      .ioctl_download           ( ioctl_download           ), // [o]
      .ioctl_index              ( ioctl_index              ), // [o]
      .ioctl_wr                 ( ioctl_wr                 ), // [o]
      .ioctl_addr               ( ioctl_addr               ), // [o]
      .ioctl_data               ( ioctl_data               )  // [o]
  );

//! ------------------------------------------------------------------------
    //! Clocks
    //! ------------------------------------------------------------------------
    wire pll_core_locked, pll_core_locked_s;
    reg pll_init_locked = 0;
    wire clk_sys;       //! Core :  32.000Mhz
    wire clk_vid;       //! Video:   8.000Mhz
    wire clk_vid_90deg; //! Video:   8.000Mhz @ 90deg Phase Shift
    wire clk_ram;       //! SDRAM: 96.000Mhz

    core_pll core_pll
    (
        .refclk   ( clk_74a         ),
        .rst      ( 0               ),

        .outclk_0 ( clk_ram         ),
        .outclk_1 ( clk_sys         ),
        .outclk_2 ( clk_vid         ),
        .outclk_3 ( clk_vid_90deg   ),
        .reconfig_to_pll(reconfig_to_pll),
        .reconfig_from_pll(reconfig_from_pll),
        .locked   ( pll_core_locked )
    );

    wire [63:0] reconfig_to_pll;
    wire [63:0] reconfig_from_pll;
    wire        cfg_waitrequest;
    reg         cfg_write;
    reg   [5:0] cfg_address;
    reg  [31:0] cfg_data;

    pll_cfg pll_cfg
    (
        .mgmt_clk(clk_74a),
        .mgmt_reset(0),
        .mgmt_waitrequest(cfg_waitrequest),
        .mgmt_read(0),
        .mgmt_readdata(),
        .mgmt_write(cfg_write),
        .mgmt_address(cfg_address),
        .mgmt_writedata(cfg_data),
        .reconfig_to_pll(reconfig_to_pll),
        .reconfig_from_pll(reconfig_from_pll)
    );


    // PLL Configuration (Integral)
    localparam PLL_PARAM_COUNT = 9;
    wire [31:0] PLL_55HZ[PLL_PARAM_COUNT * 2] = '{
        'h0, 'h0, // set waitrequest mode
        'h4, 'h4040, // M COUNTER
        'h3, 'h20605, // N COUNTER
        'h5, 'h20504, // C COUNTER
        'h5, 'h60E0D, // C COUNTER
        'h5, 'h83636, // C COUNTER
        'h5, 'hC3636, // C COUNTER
        'h8, 'h3, // BANDWIDTH
        'h2, 'h0 // start reconfigure
    };

    wire [31:0] PLL_57HZ[PLL_PARAM_COUNT * 2] = '{
        'h0, 'h0, // set waitrequest mode
        'h4, 'h26F6E, // M COUNTER
        'h3, 'h20605, // N COUNTER
        'h5, 'h20807, // C COUNTER
        'h5, 'h61716, // C COUNTER
        'h5, 'h85A5A, // C COUNTER
        'h5, 'hC5A5A, // C COUNTER
        'h8, 'h2, // BANDWIDTH
        'h2, 'h0 // start reconfigure
    };

    wire [31:0] PLL_60HZ[PLL_PARAM_COUNT * 2] = '{
        'h0, 'h0, // set waitrequest mode
        'h4, 'h24746, // M COUNTER
        'h3, 'h505, // N COUNTER
        'h5, 'h505, // C COUNTER
        'h5, 'h40F0F, // C COUNTER
        'h5, 'h83C3C, // C COUNTER
        'h5, 'hC3C3C, // C COUNTER
        'h8, 'h3, // BANDWIDTH
        'h2, 'h0 // start reconfigure
    };

    video_timing_t video_timing_lat = VIDEO_55HZ;
    video_timing_t video_timing;
    assign video_timing = video_timing_t'(vid_mode_s);
    reg reconfig_pause = 0;
    logic [1:0] vid_mode;
    wire [1:0] vid_mode_s;

    always @(posedge clk_74a) begin
        reg [4:0] param_idx = 0;
        reg [7:0] reconfig = 0;

        cfg_write <= 0;

        if (pll_core_locked  & ~cfg_waitrequest) begin
            pll_init_locked <= 1;
            if (&reconfig) begin // do reconfig
                case(video_timing_lat)
                VIDEO_50HZ: begin
                    cfg_address <= PLL_55HZ[param_idx * 2 + 0][5:0];
                    cfg_data    <= PLL_55HZ[param_idx * 2 + 1];
                end
                VIDEO_55HZ: begin
                    cfg_address <= PLL_55HZ[param_idx * 2 + 0][5:0];
                    cfg_data    <= PLL_55HZ[param_idx * 2 + 1];
                end
                VIDEO_57HZ: begin
                    cfg_address <= PLL_57HZ[param_idx * 2 + 0][5:0];
                    cfg_data    <= PLL_57HZ[param_idx * 2 + 1];
                end
                VIDEO_60HZ: begin
                    cfg_address <= PLL_60HZ[param_idx * 2 + 0][5:0];
                    cfg_data    <= PLL_60HZ[param_idx * 2 + 1];
                end
                endcase

                cfg_write <= 1;
                param_idx <= param_idx + 5'd1;
                if (param_idx == PLL_PARAM_COUNT - 1) reconfig <= 8'd0;

            end else if (video_timing != video_timing_lat) begin // new timing requested
                video_timing_lat <= video_timing;
                reconfig <= 8'd1;
                reconfig_pause <= 1;
                param_idx <= 0;
            end else if (|reconfig) begin // pausing before reconfigure
                reconfig <= reconfig + 8'd1;
            end else begin
                reconfig_pause <= 0; // unpause once pll is locked again
            end
        end
    end

    wire reset = reset_sw | ~pll_init_locked_s;
    wire pll_init_locked_s;
    // Synchronize pll_core_locked into clk_74a domain before usage
    synch_3 sync_lck(pll_init_locked, pll_init_locked_s, clk_sys);

    // Synchronize pll_core_locked into clk_74a domain before usage
    synch_3 sync_lck2(pll_core_locked, pll_core_locked_s, clk_74a);

    //Synchronize vid_mode into clk_74a domain before usage
    synch_3 #(.WIDTH(2)) sync_vid_mode(vid_mode, vid_mode_s, clk_74a);
    
    // Synchronize reconfig_paus into clk_sys domain before usage
    wire reconfig_pause_s;
    synch_3 sync_reconfpause(reconfig_pause, reconfig_pause_s, clk_sys);

  ////////////////////////////////////////////////////////////////////////////////////////


  // video generation
  // ~12,288,000 hz pixel clock
  //
  // we want our video mode of 320x240 @ 60hz, this results in 204800 clocks per frame
  // we need to add hblank and vblank times to this, so there will be a nondisplay area. 
  // it can be thought of as a border around the visible area.
  // to make numbers simple, we can have 400 total clocks per line, and 320 visible.
  // dividing 204800 by 400 results in 512 total lines per frame, and 240 visible.
  // this pixel clock is fairly high for the relatively low resolution, but that's fine.
  // PLL output has a minimum output frequency anyway.


  assign video_rgb_clock = clk_core_12288;
  assign video_rgb_clock_90 = clk_core_12288_90deg;
  assign video_rgb = vidout_rgb;
  assign video_de = vidout_de;
  assign video_skip = vidout_skip;
  assign video_vs = vidout_vs;
  assign video_hs = vidout_hs;

  localparam VID_V_BPORCH = 'd10;
  localparam VID_V_ACTIVE = 'd240;
  localparam VID_V_TOTAL = 'd512;
  localparam VID_H_BPORCH = 'd10;
  localparam VID_H_ACTIVE = 'd320;
  localparam VID_H_TOTAL = 'd400;

  reg [15:0] frame_count;

  reg [9:0] x_count;
  reg [9:0] y_count;

  wire [9:0] visible_x = x_count - VID_H_BPORCH;
  wire [9:0] visible_y = y_count - VID_V_BPORCH;

  reg [23:0] vidout_rgb;
  reg vidout_de, vidout_de_1;
  reg vidout_skip;
  reg vidout_vs;
  reg vidout_hs, vidout_hs_1;

  reg [9:0] square_x = 'd135;
  reg [9:0] square_y = 'd95;

  always @(posedge clk_core_12288 or negedge reset_n) begin

    if (~reset_n) begin

      x_count <= 0;
      y_count <= 0;

    end else begin
      vidout_de <= 0;
      vidout_skip <= 0;
      vidout_vs <= 0;
      vidout_hs <= 0;

      vidout_hs_1 <= vidout_hs;
      vidout_de_1 <= vidout_de;

      // x and y counters
      x_count <= x_count + 1'b1;
      if (x_count == VID_H_TOTAL - 1) begin
        x_count <= 0;

        y_count <= y_count + 1'b1;
        if (y_count == VID_V_TOTAL - 1) begin
          y_count <= 0;
        end
      end

      // generate sync 
      if (x_count == 0 && y_count == 0) begin
        // sync signal in back porch
        // new frame
        vidout_vs   <= 1;
        frame_count <= frame_count + 1'b1;
      end

      // we want HS to occur a bit after VS, not on the same cycle
      if (x_count == 3) begin
        // sync signal in back porch
        // new line
        vidout_hs <= 1;
      end

      // inactive screen areas are black
      vidout_rgb <= 24'h0;
      // generate active video
      if (x_count >= VID_H_BPORCH && x_count < VID_H_ACTIVE + VID_H_BPORCH) begin

        if (y_count >= VID_V_BPORCH && y_count < VID_V_ACTIVE + VID_V_BPORCH) begin
          // data enable. this is the active region of the line
          vidout_de <= 1;

          vidout_rgb[23:16] <= 8'd60;
          vidout_rgb[15:8] <= 8'd60;
          vidout_rgb[7:0] <= 8'd60;

        end
      end
    end
  end


  ///////////////////////////////////////////////

  wire [15:0] audio_l = 0;

  sound_i2s #(
      .CHANNEL_WIDTH(15)
  ) sound_i2s (
      .clk_74a  (clk_74a),
      .clk_audio(clk_core_12288),

      .audio_l(audio_l[15:1]),
      .audio_r(audio_l[15:1]),

      .audio_mclk(audio_mclk),
      .audio_lrck(audio_lrck),
      .audio_dac (audio_dac)
  );

  ///////////////////////////////////////////////


  wire clk_core_12288;
  wire clk_core_12288_90deg;

  wire pll_core_locked;

  mf_pllbase mp1 (
      .refclk(clk_74a),
      .rst   (0),

      .outclk_0(clk_core_12288),
      .outclk_1(clk_core_12288_90deg),

      .locked(pll_core_locked)
  );



endmodule
