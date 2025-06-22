//
// User core top-level
//
// Instantiated by the real top-level: apf_top
//
`timescale 1ns/1ps
`default_nettype none
import xain_pkg::*;
module core_top 
#(
    // Video
    parameter BPP_R          = 8,     //! Bits Per Pixel Red
    parameter BPP_G          = 8,     //! Bits Per Pixel Green
    parameter BPP_B          = 8,     //! Bits Per Pixel Blue
    // Audio
    parameter AUDIO_DW       = 16,    //! Audio Bits
    parameter AUDIO_S        = 1,     //! Signed Audio
    parameter STEREO         = 1,     //! Stereo Output
    parameter AUDIO_MIX      = 0,     //! [0] No Mix | [1] 25% | [2] 50% | [3] 100% (mono)
    parameter MUTE_PAUSE     = 1,     //! Mute Audio on Pause
    // Data I/O - [MPU -> FPGA]
    parameter DIO_MASK       = 4'h0,  //! Upper 4 bits of address
    parameter DIO_AW         = 25,    //! Address Width
    parameter DIO_DW         = 8,     //! Data Width (8 or 16 bits)
    parameter DIO_DELAY      = 20,     //! Number of clock cycles to delay each write output
    parameter DIO_HOLD       = 1     //! Number of clock cycles to hold the ioctl_wr signal high

)
(

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

  //Analogizer settings
  localparam [7:0] ADDRESS_ANALOGIZER_CONFIG = 8'hF7;

  // not using the IR port, so turn off both the LED, and
  // disable the receive circuit to save power
  assign port_ir_tx              = 0;
  assign port_ir_rx_disable      = 1;

  // bridge endianness
  assign bridge_endian_little    = 0;

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

    //!-------------------------------------------------------------------------
    //! Host/Target Command Handler
    //!-------------------------------------------------------------------------
    wire        reset_n /* synthesis keep */;  // driven by host commands, can be used as core-wide reset
    wire [31:0] cmd_bridge_rd_data;

    // bridge host commands
    // synchronous to clk_74a
    wire        status_boot_done  = pll_init_locked; //pll_core_locked_s;
    wire        status_setup_done = pll_init_locked; //pll_core_locked_s; // rising edge triggers a target command
    wire        status_running    = reset_n /* synthesis_keep */;           // we are running as soon as reset_n goes high

    wire        dataslot_requestread;
    wire [15:0] dataslot_requestread_id;
    wire        dataslot_requestread_ack = 1;
    wire        dataslot_requestread_ok  = 1;

    wire        dataslot_requestwrite;
    wire [15:0] dataslot_requestwrite_id;
    wire [31:0] dataslot_requestwrite_size;
    wire        dataslot_requestwrite_ack = 1;
    wire        dataslot_requestwrite_ok  = 1;

    wire        dataslot_update;
    wire [15:0] dataslot_update_id;
    wire [31:0] dataslot_update_size;

    wire        dataslot_allcomplete;

    wire [31:0] rtc_epoch_seconds;
    wire [31:0] rtc_date_bcd;
    wire [31:0] rtc_time_bcd;
    wire        rtc_valid;

    wire        savestate_supported;
    wire [31:0] savestate_addr;
    wire [31:0] savestate_size;
    wire [31:0] savestate_maxloadsize;

    wire        savestate_start;
    wire        savestate_start_ack;
    wire        savestate_start_busy;
    wire        savestate_start_ok;
    wire        savestate_start_err;

    wire        savestate_load;
    wire        savestate_load_ack;
    wire        savestate_load_busy;
    wire        savestate_load_ok;
    wire        savestate_load_err;

    wire        osnotify_inmenu;
    wire        osnotify_docked;
    wire        osnotify_grayscale;

    // bridge target commands
    // synchronous to clk_74a
    reg         target_dataslot_read;
    reg         target_dataslot_write;
    reg         target_dataslot_getfile;    // require additional param/resp structs to be mapped
    reg         target_dataslot_openfile;   // require additional param/resp structs to be mapped

    wire        target_dataslot_ack;
    wire        target_dataslot_done;
    wire  [2:0] target_dataslot_err;

    reg  [15:0] target_dataslot_id;
    reg  [31:0] target_dataslot_slotoffset;
    reg  [31:0] target_dataslot_bridgeaddr;
    reg  [31:0] target_dataslot_length;

    wire [31:0] target_buffer_param_struct; // to be mapped/implemented when using some Target commands
    wire [31:0] target_buffer_resp_struct;  // to be mapped/implemented when using some Target commands

    // bridge data slot access
    // synchronous to clk_74a
    wire  [9:0] datatable_addr;
    wire        datatable_wren;
    wire [31:0] datatable_data;
    wire [31:0] datatable_q;

    core_bridge_cmd u_pocket_apf_bridge
    (
        .clk                        ( clk_74a                    ),
        .reset_n                    ( reset_n                    ),

        .bridge_endian_little       ( bridge_endian_little       ),
        .bridge_addr                ( bridge_addr                ),
        .bridge_rd                  ( bridge_rd                  ),
        .bridge_rd_data             ( cmd_bridge_rd_data         ),
        .bridge_wr                  ( bridge_wr                  ),
        .bridge_wr_data             ( bridge_wr_data             ),

        .status_boot_done           ( status_boot_done           ),
        .status_setup_done          ( status_setup_done          ),
        .status_running             ( status_running             ),

        .dataslot_requestread       ( dataslot_requestread       ),
        .dataslot_requestread_id    ( dataslot_requestread_id    ),
        .dataslot_requestread_ack   ( dataslot_requestread_ack   ),
        .dataslot_requestread_ok    ( dataslot_requestread_ok    ),

        .dataslot_requestwrite      ( dataslot_requestwrite      ),
        .dataslot_requestwrite_id   ( dataslot_requestwrite_id   ),
        .dataslot_requestwrite_size ( dataslot_requestwrite_size ),
        .dataslot_requestwrite_ack  ( dataslot_requestwrite_ack  ),
        .dataslot_requestwrite_ok   ( dataslot_requestwrite_ok   ),

        .dataslot_update            ( dataslot_update            ),
        .dataslot_update_id         ( dataslot_update_id         ),
        .dataslot_update_size       ( dataslot_update_size       ),

        .dataslot_allcomplete       ( dataslot_allcomplete       ),

        .rtc_epoch_seconds          ( rtc_epoch_seconds          ),
        .rtc_date_bcd               ( rtc_date_bcd               ),
        .rtc_time_bcd               ( rtc_time_bcd               ),
        .rtc_valid                  ( rtc_valid                  ),

        .savestate_supported        ( savestate_supported        ),
        .savestate_addr             ( savestate_addr             ),
        .savestate_size             ( savestate_size             ),
        .savestate_maxloadsize      ( savestate_maxloadsize      ),

        .savestate_start            ( savestate_start            ),
        .savestate_start_ack        ( savestate_start_ack        ),
        .savestate_start_busy       ( savestate_start_busy       ),
        .savestate_start_ok         ( savestate_start_ok         ),
        .savestate_start_err        ( savestate_start_err        ),

        .savestate_load             ( savestate_load             ),
        .savestate_load_ack         ( savestate_load_ack         ),
        .savestate_load_busy        ( savestate_load_busy        ),
        .savestate_load_ok          ( savestate_load_ok          ),
        .savestate_load_err         ( savestate_load_err         ),

        .osnotify_inmenu            ( osnotify_inmenu            ),
        .osnotify_docked            ( osnotify_docked            ),
        .osnotify_grayscale         ( osnotify_grayscale         ),

        .target_dataslot_read       ( target_dataslot_read       ),
        .target_dataslot_write      ( target_dataslot_write      ),
        .target_dataslot_getfile    ( target_dataslot_getfile    ),
        .target_dataslot_openfile   ( target_dataslot_openfile   ),

        .target_dataslot_ack        ( target_dataslot_ack        ),
        .target_dataslot_done       ( target_dataslot_done       ),
        .target_dataslot_err        ( target_dataslot_err        ),

        .target_dataslot_id         ( target_dataslot_id         ),
        .target_dataslot_slotoffset ( target_dataslot_slotoffset ),
        .target_dataslot_bridgeaddr ( target_dataslot_bridgeaddr ),
        .target_dataslot_length     ( target_dataslot_length     ),

        .target_buffer_param_struct ( target_buffer_param_struct ),
        .target_buffer_resp_struct  ( target_buffer_resp_struct  ),

        .datatable_addr             ( datatable_addr             ),
        .datatable_wren             ( datatable_wren             ),
        .datatable_data             ( datatable_data             ),
        .datatable_q                ( datatable_q                )
    );

    //! END OF APF /////////////////////////////////////////////////////////////

    //! ////////////////////////////////////////////////////////////////////////
    //! @ System Modules
    //! ////////////////////////////////////////////////////////////////////////

    //!-------------------------------------------------------------------------
    //! APF Bridge Read Data
    //!-------------------------------------------------------------------------
    wire [31:0] int_bridge_rd_data;
    wire [31:0] nvm_bridge_rd_data, nvm_bridge_rd_data_s;

    // Synchronize nvm_bridge_rd_data into clk_74a domain before usage
    synch_3 #(32) u_sync_nvm(nvm_bridge_rd_data, nvm_bridge_rd_data_s, clk_74a);

    always_comb begin
        casex(bridge_addr)
            32'hF8xxxxxx:                                begin bridge_rd_data <= cmd_bridge_rd_data;        end // APF Bridge (Reserved)
            32'h10000000:                                begin bridge_rd_data <= nvm_bridge_rd_data_s;      end // HiScore/NVRAM/SRAM Save
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
    //! Interact: Dip Switches, Modifiers, Filters and Reset
    //!-------------------------------------------------------------------------
    wire        reset_sw, svc_sw /*synthesis keep*/;
    wire  [7:0] dip_sw0, dip_sw1, dip_sw2, dip_sw3;
    wire  [7:0] ext_sw0, ext_sw1, ext_sw2, ext_sw3;
    wire  [7:0] mod_sw0, mod_sw1, mod_sw2, mod_sw3;
    wire  [7:0] inp_sw0, inp_sw1, inp_sw2, inp_sw3;
    wire  [3:0] scnl_sw, smask_sw, afilter_sw, vol_att;
    wire [63:0] status;
    wire [15:0] nvram_size;
    wire [31:0] analogizer_sw;

    interact u_pocket_interact
    (
        // Clocks and Reset
        .clk_74a        ( clk_74a            ), // [i]
        .clk_sync       ( clk_sys            ), // [i]
        .reset_n        ( reset_n            ), // [i]
        // Reset Switch
        .reset_sw       ( reset_sw           ), // [o]
        // Service Mode Switch
        .svc_sw         ( svc_sw             ), // [o]
        // DIP Switches
        .dip_sw0        ( dip_sw0            ), // [o]
        .dip_sw1        ( dip_sw1            ), // [o]
        .dip_sw2        ( dip_sw2            ), // [o]
        .dip_sw3        ( dip_sw3            ), // [o]
        // Extra DIP Switches
        .ext_sw0        ( ext_sw0            ), // [o]
        .ext_sw1        ( ext_sw1            ), // [o]
        .ext_sw2        ( ext_sw2            ), // [o]
        .ext_sw3        ( ext_sw3            ), // [o]
        // Modifiers
        .mod_sw0        ( mod_sw0            ), // [o]
        .mod_sw1        ( mod_sw1            ), // [o]
        .mod_sw2        ( mod_sw2            ), // [o]
        .mod_sw3        ( mod_sw3            ), // [o]
        // Inputs Switches
        .inp_sw0        ( inp_sw0            ), // [o]
        .inp_sw1        ( inp_sw1            ), // [o]
        .inp_sw2        ( inp_sw2            ), // [o]
        .inp_sw3        ( inp_sw3            ), // [o]
        // Status (Legacy Support)
        .status         ( status             ), // [o]
        // Filters Switches
        .scnl_sw        ( scnl_sw            ), // [o]
        .smask_sw       ( smask_sw           ), // [o]
        .afilter_sw     ( afilter_sw         ), // [o]
        .vol_att        ( vol_att            ), // [o]
        // NVRAM/High Score
        .nvram_size     ( nvram_size         ), // [o]
        // Analogizer
        .analogizer_sw  ( analogizer_sw      ), // [o]
        // Pocket Bridge
        .bridge_addr    ( bridge_addr        ), // [i]
        .bridge_wr      ( bridge_wr          ), // [i]
        .bridge_wr_data ( bridge_wr_data     ), // [i]
        .bridge_rd      ( bridge_rd          ), // [i]
        .bridge_rd_data ( int_bridge_rd_data )  // [o]
    );

    //!-------------------------------------------------------------------------
    //! Audio
    //!-------------------------------------------------------------------------
    wire [AUDIO_DW-1:0] core_snd_l, core_snd_r; // Audio Mono/Left/Right

    audio_mixer #(.DW(AUDIO_DW),.MUTE_PAUSE(MUTE_PAUSE),.STEREO(STEREO)) u_pocket_audio_mixer
    (
        // Clocks and Reset
        .clk_74b    ( clk_74b    ),
        .clk_sys    ( clk_sys    ),
        .reset      ( reset   ),
        // Controls
        .afilter_sw ( afilter_sw ),
        .vol_att    ( vol_att    ),
        .mix        ( AUDIO_MIX  ),
        .pause_core ( pause_core ),
        // Audio From Core
        .is_signed  ( AUDIO_S    ),
        .core_l     ( core_snd_l ),
        .core_r     ( core_snd_r ),
        // I2S
        .audio_mclk ( audio_mclk ),
        .audio_lrck ( audio_lrck ),
        .audio_dac  ( audio_dac  )
    );

    //!-------------------------------------------------------------------------
    //! Video (for Pocket Display)
    //!-------------------------------------------------------------------------
    wire             grayscale_en;           // Enable Grayscale Output
    wire       [2:0] video_preset;           // Video Preset Configuration
    wire [BPP_R-1:0] core_r;                 // Video Red
    wire [BPP_G-1:0] core_g;                 // Video Green
    wire [BPP_B-1:0] core_b;                 // Video Blue
    wire             core_hs, core_hb;       // Horizontal Sync/Blank
    wire             core_vs, core_vb;       // Vertical Sync/Blank
    wire             core_ce;                // Pixel Clock Enable (8 MHz)
    wire             interlaced, field;      // Interlaced Video | Even/Odd Field

    synch_3 sync_bwmode(osnotify_grayscale, grayscale_en, clk_vid);

    video_mixer #(
        .RW                       ( BPP_R                    ), // [p]
        .GW                       ( BPP_G                    ), // [p]
        .BW                       ( BPP_B                    )  // [p]
    ) u_pocket_video_mixer (
        // Clocks
        .clk_74a                  ( clk_74a                  ), // [i]
        .clk_sys                  ( clk_sys                  ), // [i]
        .clk_vid                  ( clk_vid                  ), // [i]
        .clk_vid_90deg            ( clk_vid_90deg            ), // [i]
        // Input Controls
        .grayscale_en             ( grayscale_en             ), // [i]
        .video_preset             ( video_preset             ), // [i]
        .scnl_sw                  ( scnl_sw                  ), // [i]
        .smask_sw                 ( smask_sw                 ), // [i]
         // Interlaced Video Controls
        .field                    ( field                    ), // [i]
        .interlaced               ( interlaced               ), // [i]
        // Input Video from Core
        .core_r                   ( video_rgb_xain[23:16]    ), // [i]
        .core_g                   ( video_rgb_xain[15:8]     ), // [i]
        .core_b                   ( video_rgb_xain[7:0]      ), // [i]
        .core_hs                  ( hsync_core               ), // [i]
        .core_vs                  ( vsync_core               ), // [i]
        .core_hb                  ( hblank_core              ), // [i]
        .core_vb                  ( vblank_core              ), // [i]
        // Output to Display
        .video_rgb                ( video_rgb                ), // [o]
        .video_hs                 ( video_hs                 ), // [o]
        .video_vs                 ( video_vs                 ), // [o]
        .video_de                 ( video_de                 ), // [o]
        .video_skip               ( video_skip               ), // [o]
        .video_rgb_clock          ( video_rgb_clock          ), // [o]
        .video_rgb_clock_90       ( video_rgb_clock_90       ), // [o]
        // Input Video from Core
        .vga_r                    ( ), // [o]
        .vga_g                    ( ), // [o]
        .vga_b                    ( ), // [o]
        .vga_vs                   ( ), // [o]
        .vga_hs                   ( ), // [o]
        .vga_de                   ( )  // [o]
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
    wire clk_sys;       //! Core :  48.000Mhz
    wire clk_vid;       //! Video:   6.000Mhz
    wire clk_vid_90deg; //! Video:   6.000Mhz @ 90deg Phase Shift
    wire clk_ram;       //! SDRAM: 96.000Mhz

    mf_pllbase core_pll
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

    wire [31:0] PLL_57HZ[PLL_PARAM_COUNT * 2] = '{
        'h0, 'h0, // set waitrequest mode
        'h4, 'h4040, // M COUNTER
        'h3, 'h20605, // N COUNTER
        'h5, 'h20504, // C COUNTER
        'h5, 'h40909, // C COUNTER
        'h5, 'h84848, // C COUNTER
        'h5, 'hC4848, // C COUNTER
        'h8, 'h2, // BANDWIDTH
        'h2, 'h0 // start reconfigure
    };

    wire [31:0] PLL_60HZ[PLL_PARAM_COUNT * 2] = '{
        'h0, 'h0, // set waitrequest mode
        'h4, 'h4F4F, // M COUNTER
        'h3, 'h20706, // N COUNTER
        'h5, 'h20504, // C COUNTER
        'h5, 'h40909, // C COUNTER
        'h5, 'h84848, // C COUNTER
        'h5, 'hC4848, // C COUNTER
        'h8, 'h3, // BANDWIDTH
        'h2, 'h0 // start reconfigure
    };

    video_timing_t video_timing_lat = VIDEO_57HZ;
    video_timing_t video_timing;
    assign video_timing = video_timing_t'(vid_mode_s);

    reg reconfig_pause = 0;
    logic vid_mode;
    wire  vid_mode_s;

    always @(posedge clk_74a) begin
        vid_mode <= mod_sw0[2];
    end

    always @(posedge clk_74a) begin
        reg [4:0] param_idx = 0;
        reg [7:0] reconfig = 0;

        cfg_write <= 0;

        if (pll_core_locked  & ~cfg_waitrequest) begin
            pll_init_locked <= 1;
            if (&reconfig) begin // do reconfig
                case(video_timing_lat)
                    VIDEO_57HZ: begin
                        cfg_address <= PLL_57HZ[param_idx * 2 + 0][5:0];
                        cfg_data    <= PLL_57HZ[param_idx * 2 + 1];
                    end
                    VIDEO_60HZ: begin
                        cfg_address <= PLL_60HZ[param_idx * 2 + 0][5:0];
                        cfg_data    <= PLL_60HZ[param_idx * 2 + 1];
                    end
                    default: begin
                        cfg_address <= PLL_57HZ[param_idx * 2 + 0][5:0];
                        cfg_data    <= PLL_57HZ[param_idx * 2 + 1];
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
    wire pll_init_locked_s /*synthesis keep*/;

    // Synchronize pll_core_locked into clk_sys domain before usage
    synch_3 sync_lck(pll_init_locked, pll_init_locked_s, clk_sys);

    // Synchronize pll_core_locked into clk_74a domain before usage
    synch_3 sync_lck2(pll_core_locked, pll_core_locked_s, clk_ram);

    // Synchronize reconfig_paus into clk_sys domain before usage
    wire reconfig_pause_s;
    synch_3 sync_reconfpause(reconfig_pause, reconfig_pause_s, clk_sys);

    //Synchronize vid_mode into clk_74a domain before usage
    synch_3 #(.WIDTH(1)) sync_vid_mode(vid_mode, vid_mode_s, clk_74a);

//Xain'd Sleena uses only one set of game controls and 2 start buttons that are needed for play a continue
logic [7:0] PLAYER1, PLAYER2;
logic SERVICE;
//All inputs are active low except SERVICE
//               {2P,1P,1PSW2,1PSW1,1PD,1PU,1PL,1PR}              
assign PLAYER1 = {~p2_controls[15],~p1_controls[15],~p1_controls[5],~p1_controls[4],~p1_controls[1],~p1_controls[0],~p1_controls[2],~p1_controls[3]};
//               {COIN2,COIN1,2PSW2,2PSW1,2PD,2PU,2PL,2PR}             
assign PLAYER2 = {~p2_controls[14],~p1_controls[14],~p2_controls[5],~p2_controls[4],~p2_controls[1],~p2_controls[0],~p2_controls[2],~p2_controls[3]};
assign SERVICE = 1'b1; //Not used in game

//Xain_top interface
logic [7:0] video_r_core;
logic [7:0] video_g_core;
logic [7:0] video_b_core;
logic hblank_core, vblank_core;
logic hsync_core, vsync_core;
logic csync_core;
logic ce_pixel_core;

xain_top u_xain_top (
    // Clocks & Reset
    .clk            (clk_sys),             // System clock
    .reset          (reset | ioctl_download),           // Reset
    .init(~pll_core_locked_s),            // SDRAM Initialization
	.pause((pause_core & !reset) | reconfig_pause_s),

    // Modifiers
    .MODSW          (mod_sw0), //mod_sw0[1] X2 CPU turbo mode
    // Inputs
    .DSW1           (~dip_sw0),
    .DSW2           (~dip_sw1),
    .PLAYER1        (PLAYER1),
    .PLAYER2        (PLAYER2),
    .SERVICE        (SERVICE),
    .JAMMA_24       (1'b1),
    .JAMMA_b        (1'b1),

    // Video Output
    .CSYNC          (csync_core),
    .VIDEO_R        (video_r_core),
    .VIDEO_G        (video_g_core),
    .VIDEO_B        (video_b_core),
    .CE_PIXEL       (ce_pixel_core),
    .HBLANK         (hblank_core),
    .VBLANK         (vblank_core),
    .HSYNC          (hsync_core),
    .VSYNC          (vsync_core),

    // Sound Output
    .snd1           (core_snd_l),
    .snd2           (core_snd_r),

    // IOCTL
    .ioctl_download (ioctl_download),
    .ioctl_index    (ioctl_index),
    .ioctl_wr       (ioctl_wr),
    .ioctl_addr     (ioctl_addr),
    .ioctl_data     (ioctl_data),

    // SDRAM Interface
    .sdr_clk        (clk_ram),
    .dram_dq        (dram_dq),
    .dram_a         (dram_a),
    .dram_dqm       (dram_dqm),
    .dram_ba        (dram_ba),
    .dram_we_n      (dram_we_n),
    .dram_ras_n     (dram_ras_n),
    .dram_cas_n     (dram_cas_n),
    .dram_cke       (dram_cke),
    .dram_clk       (dram_clk)
);
/*[ANALOGIZER_HOOK_BEGIN]*/
    //reg analogizer_ena;
    wire [3:0] analogizer_video_type;
    wire [4:0] snac_game_cont_type;
    wire [3:0] snac_cont_assignment;
    wire       pocket_blank_screen;

    wire analogizer_ena = mod_sw0[0]; //setting from Pocket Menu

    //create aditional switch to blank Pocket screen.
    wire [23:0] video_rgb_xain;
    assign video_rgb_xain = (pocket_blank_screen && !analogizer_ena) ? 24'h000000: {video_r_core,video_g_core,video_b_core};
    //assign video_rgb_xain = {video_r_core,video_g_core,video_b_core};

    //switch between Analogizer SNAC and Pocket Controls for P1-P4 (P3,P4 when uses PCEngine Multitap)
    wire [15:0] p1_btn, p2_btn, p3_btn, p4_btn;
    wire [31:0] p1_joy, p2_joy;
    reg [31:0] p1_joystick, p2_joystick;
    reg  [15:0] p1_controls, p2_controls;

    wire snac_is_analog = (snac_game_cont_type == 5'h12) || (snac_game_cont_type == 5'h13);

    //! Player 1 ---------------------------------------------------------------------------
    reg p1_up, p1_down, p1_left, p1_right;
    wire p1_up_analog, p1_down_analog, p1_left_analog, p1_right_analog;
    //using left analog joypad
    assign p1_up_analog    = (p1_joy[15:8] < 8'h40) ? 1'b1 : 1'b0; //analog range UP 0x00 Idle 0x7F DOWN 0xFF, DEADZONE +- 0x15
    assign p1_down_analog  = (p1_joy[15:8] > 8'hC0) ? 1'b1 : 1'b0; 
    assign p1_left_analog  = (p1_joy[7:0]  < 8'h40) ? 1'b1 : 1'b0; //analog range LEFT 0x00 Idle 0x7F RIGHT 0xFF, DEADZONE +- 0x15
    assign p1_right_analog = (p1_joy[7:0]  > 8'hC0) ? 1'b1 : 1'b0;

    always @(posedge clk_74a) begin
        p1_up    <= (snac_is_analog) ? p1_up_analog    : p1_btn[0];
        p1_down  <= (snac_is_analog) ? p1_down_analog  : p1_btn[1];
        p1_left  <= (snac_is_analog) ? p1_left_analog  : p1_btn[2];
        p1_right <= (snac_is_analog) ? p1_right_analog : p1_btn[3];
    end
    //! Player 2 ---------------------------------------------------------------------------
    reg p2_up, p2_down, p2_left, p2_right;
    wire p2_up_analog, p2_down_analog, p2_left_analog, p2_right_analog;
    //using left analog joypad
    assign p2_up_analog    = (p2_joy[15:8] < 8'h40) ? 1'b1 : 1'b0; //analog range UP 0x00 Idle 0x7F DOWN 0xFF, DEADZONE +- 0x15
    assign p2_down_analog  = (p2_joy[15:8] > 8'hC0) ? 1'b1 : 1'b0; 
    assign p2_left_analog  = (p2_joy[7:0]  < 8'h40) ? 1'b1 : 1'b0; //analog range LEFT 0x00 Idle 0x7F RIGHT 0xFF, DEADZONE +- 0x15
    assign p2_right_analog = (p2_joy[7:0]  > 8'hC0) ? 1'b1 : 1'b0;

    always @(posedge clk_74a) begin
        p2_up    <= (snac_is_analog) ? p2_up_analog    : p2_btn[0];
        p2_down  <= (snac_is_analog) ? p2_down_analog  : p2_btn[1];
        p2_left  <= (snac_is_analog) ? p2_left_analog  : p2_btn[2];
        p2_right <= (snac_is_analog) ? p2_right_analog : p2_btn[3];
    end
    always @(posedge clk_74a) begin
        reg [31:0] p1_pocket_btn, p1_pocket_joy;
        reg [31:0] p2_pocket_btn, p2_pocket_joy;

        if((snac_game_cont_type == 5'h0) || !analogizer_ena) begin //SNAC is disabled
        //if((snac_game_cont_type == 5'h0)) begin //SNAC is disabled
            p1_controls <= cont1_key;
            p2_controls <= cont2_key;
        end
        else begin
        case(snac_cont_assignment[1:0])
        2'h0:    begin  //SNAC P1 -> Pocket P1
            p1_controls <= {p1_btn[15:4],p1_right,p1_left,p1_down,p1_up};
            p2_controls <= cont2_key;
            end
        2'h1: begin  //SNAC P1 -> Pocket P2
            p1_controls <= cont1_key;
            p2_controls <= p1_btn;
            end
        2'h2: begin //SNAC P1 -> Pocket P1, SNAC P2 -> Pocket P2
            p1_controls <= {p1_btn[15:4],p1_right,p1_left,p1_down,p1_up};
            p2_controls <= {p2_btn[15:4],p2_right,p2_left,p2_down,p2_up};
            end
        2'h3: begin //SNAC P1 -> Pocket P2, SNAC P2 -> Pocket P1
            p1_controls <= {p2_btn[15:4],p2_right,p2_left,p2_down,p2_up};
            p2_controls <= {p1_btn[15:4],p1_right,p1_left,p1_down,p1_up};
            end
        default: begin 
            p1_controls <= cont1_key;
            p2_controls <= cont2_key;
            end
        endcase
        end
    end

    wire [15:0] p1_btn_CK, p2_btn_CK;
    wire [31:0] p1_joy_CK, p2_joy_CK;
    synch_3 #(
    .WIDTH(16)
    ) p1b_s (
        p1_btn_CK,
        p1_btn,
        clk_74a
    );

    synch_3 #(
        .WIDTH(16)
    ) p2b_s (
        p2_btn_CK,
        p2_btn,
        clk_74a
    );

    synch_3 #(
    .WIDTH(32)
    ) p3b_s (
        p1_joy_CK,
        p1_joy,
        clk_74a
    );
        
    synch_3 #(
        .WIDTH(32)
    ) p4b_s (
        p2_joy_CK,
        p2_joy,
        clk_74a
    );


    // Video Y/C Encoder settings
    // Follows the Mike Simone Y/C encoder settings:
    // https://github.com/MikeS11/MiSTerFPGA_YC_Encoder
    // SET PAL and NTSC TIMING and pass through status bits. ** YC must be enabled in the qsf file **
    wire [39:0] CHROMA_PHASE_INC;
    wire PALFLAG;

    parameter NTSC_REF = 3.579545;   
    parameter PAL_REF = 4.43361875;

    // Parameters to be modifed
    parameter CLK_VIDEO_NTSC = 48.0; // Must be filled E.g XX.X Hz - CLK_VIDEO
    parameter CLK_VIDEO_PAL  = 48.0; // Must be filled E.g XX.X Hz - CLK_VIDEO
    parameter CLK_VIDEO_NTSC2 = 50.13504; // Must be filled E.g XX.X Hz - CLK_VIDEO
    parameter CLK_VIDEO_PAL2  = 50.13504; // Must be filled E.g XX.X Hz - CLK_VIDEO

    //PAL CLOCK FREQUENCY SHOULD BE 42.56274
    localparam [39:0] NTSC_PHASE_INC1 = 40'd81994819784; // ((NTSC_REF * 2^40) / CLK_VIDEO_NTSC)
    localparam [39:0] PAL_PHASE_INC1  = 40'd101558653515; // ((PAL_REF * 2^40) / CLK_VIDEO_PAL)
    localparam [39:0] NTSC_PHASE_INC2 = 40'd78503006074; // ((NTSC_REF * 2^40) / CLK_VIDEO_NTSC2)
    localparam [39:0] PAL_PHASE_INC2  = 40'd97233698602; // ((PAL_REF * 2^40) / CLK_VIDEO_PAL2)



    assign PALFLAG = (analogizer_video_type == 4'h4); 

    always @(posedge clk_sys) begin
        case(video_timing_lat)
        VIDEO_57HZ: begin
            CHROMA_PHASE_INC <= PALFLAG ? PAL_PHASE_INC1 : NTSC_PHASE_INC1; 
        end
        VIDEO_60HZ: begin
            CHROMA_PHASE_INC <= PALFLAG ? PAL_PHASE_INC2 : NTSC_PHASE_INC2; 
        end
        endcase
    end

    // H/V offset
    // Assigned to START + UP/DOWN/LEFT/RIGHT buttons
    logic [5:0]	hoffset = 5'h0;
    logic [4:0]	voffset = 4'h0;

    logic start_r, up_r, down_r, left_r, right_r, btnA_r;

    always_ff @(posedge clk_sys) begin 
       start_r <= p1_controls[15];
       up_r    <= p1_controls[0];
       down_r  <= p1_controls[1];
       left_r  <= p1_controls[2];
       right_r <= p1_controls[3]; 
       btnA_r  <= p1_controls[4];
    end
   wire HSync,VSync;
   jtframe_resync jtframe_resync
   (
       .clk(clk_sys),
       .pxl_cen(ce_pixel_core),
       .hs_in(hsync_core),
       .vs_in(vsync_core),
       .LVBL(~vblank_core),
       .LHBL(~hblank_core),
       .hoffset(hoffset), //5bits signed
       .voffset(voffset), //5bits signed
       .hs_out(HSync),
       .vs_out(VSync)
   );

    //Debug OSD: shows Xoffset and Yoffset values and the detected video resolution for Analogizer
    wire [7:0] RGB_out_R, RGB_out_G, RGB_out_B;
    wire HS_out, VS_out, HB_out, VB_out;

   osd_top #(
   .CLK_HZ(48_000_000),
   .DURATION_SEC(4)
   ) osd_debug_inst (
       .clk(clk_sys),
       .reset(reset),
       .pixel_ce(ce_pixel_core),
       .R_in(video_r_core),
       .G_in(video_g_core),
       .B_in(video_b_core),
       .hsync_in(HSync),
       .vsync_in(VSync),
       .hblank(hblank_core),
       .vblank(vblank_core),
       .key_right(p1_controls[15] && !left_r && p1_controls[2]), //Detects if Start+Left was pressed
       .key_left(p1_controls[15] && !right_r && p1_controls[3] ),//Detects if Start+Right was pressed
       .key_down(p1_controls[15] && !up_r && p1_controls[0]),    //Detects if Start+Up was pressed
       .key_up(p1_controls[15] && !down_r && p1_controls[1]),    //Detects if Start+Down was pressed
       .key_A(p1_controls[15] && !btnA_r && p1_controls[4]),    //Detects if Start+A was pressed
       .R_out(RGB_out_R),
       .G_out(RGB_out_G),
       .B_out(RGB_out_B),
       .hsync_out(HS_out),
       .vsync_out(VS_out),
       .hblank_out(HB_out),
       .vblank_out(VB_out),
       .h_offset_out(hoffset),
       .v_offset_out(voffset),
       .analogizer_ready(!busy),
       .analogizer_video_type(analogizer_video_type),
       .snac_game_cont_type(snac_game_cont_type),
       .snac_cont_assignment(snac_cont_assignment),
       .vid_mode_in(vid_mode),
       .osd_pause_out (pause_req)
   );

    //32_000_000
    wire [31:0] analogizer_bridge_rd_data;
    wire busy;
    openFPGA_Pocket_Analogizer #(.MASTER_CLK_FREQ(48_000_000), .LINE_LENGTH(256), .ADDRESS_ANALOGIZER_CONFIG(ADDRESS_ANALOGIZER_CONFIG)) analogizer (
        .clk_74a(clk_74a),
        .i_clk(clk_sys),
        .i_rst_apf(reset), //i_rst_apf is active high
        .i_rst_core(reset), //i_rst_core is active high
        //.i_ena(analogizer_ena),
        .i_ena(1'b1),

        //Video interface
        .video_clk(clk_sys),
        .R(RGB_out_R),
        .G(RGB_out_G),
        .B(RGB_out_B),
        .Hblank(HB_out),
        .Vblank(VB_out),
        .Hsync(HS_out), //composite SYNC on HSync.
        .Vsync(VS_out),
        // .video_clk(clk_sys),
        // .R(video_r_core),
        // .G(video_g_core),
        // .B(video_b_core),
        // .Hblank(hblank_core),
        // .Vblank(vblank_core),
        // .Hsync(hsync_core), //composite SYNC on HSync.
        // .Vsync(vsync_core),
        //openFPGA Bridge interface
        .bridge_endian_little(bridge_endian_little),
        .bridge_addr(bridge_addr),
        .bridge_rd(bridge_rd),
        .analogizer_bridge_rd_data(analogizer_bridge_rd_data),
        .bridge_wr(bridge_wr),
        .bridge_wr_data(bridge_wr_data),

        //Analogizer settings
        .snac_game_cont_type_out(snac_game_cont_type),
        .snac_cont_assignment_out(snac_cont_assignment),
        .analogizer_video_type_out(analogizer_video_type),
        .SC_fx_out(),
        .pocket_blank_screen_out(pocket_blank_screen),
        .analogizer_osd_out(),

        //Video Y/C Encoder interface
        .CHROMA_PHASE_INC(CHROMA_PHASE_INC),
        .PALFLAG(PALFLAG),
        //Video SVGA Scandoubler interface
        .ce_pix(ce_pixel_core),
        .scandoubler(1'b1), //logic for disable/enable the scandoubler
        //SNAC interface
        .p1_btn_state(p1_btn_CK),
        .p1_joy_state(p1_joy_CK),
        .p2_btn_state(p2_btn_CK),  
        .p2_joy_state(p2_joy_CK),
        .p3_btn_state(),
        .p4_btn_state(),  
        .busy(busy),    
        //Pocket Analogizer IO interface to the Pocket cartridge port
        .cart_tran_bank2(cart_tran_bank2),
        .cart_tran_bank2_dir(cart_tran_bank2_dir),
        .cart_tran_bank3(cart_tran_bank3),
        .cart_tran_bank3_dir(cart_tran_bank3_dir),
        .cart_tran_bank1(cart_tran_bank1),
        .cart_tran_bank1_dir(cart_tran_bank1_dir),
        .cart_tran_bank0(cart_tran_bank0),
        .cart_tran_bank0_dir(cart_tran_bank0_dir),
        .cart_tran_pin30(cart_tran_pin30),
        .cart_tran_pin30_dir(cart_tran_pin30_dir),
        .cart_pin30_pwroff_reset(cart_pin30_pwroff_reset),
        .cart_tran_pin31(cart_tran_pin31),
        .cart_tran_pin31_dir(cart_tran_pin31_dir),
        //debug
        .o_stb()
    );
    /*[ANALOGIZER_HOOK_END]*/
endmodule
