module data_io_wrapper #(
         parameter MASK  =  0,  //! Upper 4 bits of address
         parameter AW    = 27,  //! Address Width
         parameter DW    =  8,  //! Data Width (8 or 16 bits)
         parameter DELAY =  4,  //! Number of clock cycles to delay each write output
         parameter HOLD  =  1   //! Number of clock cycles to hold the ioctl_wr signal high
)(
  input  wire        clk_74a,
  input  wire        clk_memory,
  input  wire        reset,
  // Pocket Bridge Slots
  input  logic          dataslot_requestwrite,
  input  logic          dataslot_allcomplete,
  input  logic   [15:0] dataslot_requestwrite_id,
  // Pocket Bridge
  input  logic          bridge_endian_little,
  input  logic   [31:0] bridge_addr,
  input  logic          bridge_wr,
  input  logic   [31:0] bridge_wr_data,
  // interface original data_io
  output  wire          ioctl_download, // signal indicating an active download
  output  wire   [15:0] ioctl_index,        // slot index used to upload the file
  output wire           ioctl_wr,
  output wire [AW-1:0]  ioctl_addr,
  output wire [DW-1:0]  ioctl_data,
  // señales de control para refresco
  output wire        loader_busy,
  output wire [15:0] loader_cycles_left
);

  // -- Instancia del data_io original --
  data_io #(.MASK(MASK),.AW(AW),.DW(DW),.DELAY(DELAY),.HOLD(HOLD)) u_pocket_data_io
  (
      // Clocks and Reset
      .clk_74a                  ( clk_74a                  ), // [i]
      .clk_memory               ( clk_memory               ), // [i]
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

  // -- Detectamos ráfaga de 4 bytes (+ delay/hold) --
  localparam BB = 4;  // bytes por ráfaga
  localparam BB_LENGTH = BB * (HOLD + DELAY);

  reg [7:0] burst_cycles;
  always_ff @(posedge clk_memory or posedge reset) begin
    if (reset) begin
      burst_cycles <= 0;
    end else if (ioctl_wr && burst_cycles == 0) begin
      // inicia nueva ráfaga de 4 bytes
      burst_cycles <= BB_LENGTH;
    end else if (burst_cycles != 0) begin
      burst_cycles <= burst_cycles - 1;
    end
  end

  assign loader_busy = (burst_cycles != 0);
  assign loader_cycles_left = burst_cycles;

endmodule
