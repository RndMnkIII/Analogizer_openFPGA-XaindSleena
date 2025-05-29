
module top (
    input  wire clk,
    input  wire reset_n,
    output wire [12:0] SDRAM_A,
    output wire [1:0]  SDRAM_BA,
    output wire        SDRAM_CS_N,
    output wire        SDRAM_RAS_N,
    output wire        SDRAM_CAS_N,
    output wire        SDRAM_WE_N,
    inout  wire [15:0] SDRAM_DQ,
    output wire        SDRAM_DQML,
    output wire        SDRAM_DQMH,
    output wire        SDRAM_CLK,
    output wire        SD_CS,
    output wire        SD_CLK,
    inout  wire        SD_MOSI,
    input  wire        SD_MISO
);

// Aquí se instanciarán: PicoRV32, SPI, SDRAM controller
// Esta versión es solo el esqueleto para completar

endmodule
