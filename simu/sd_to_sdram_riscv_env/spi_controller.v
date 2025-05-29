
module spi_controller (
    input  wire clk,
    input  wire reset_n,
    input  wire [7:0] din,
    input  wire wr_en,
    output reg  [7:0] dout,
    output reg  ready,
    output wire sd_cs,
    output wire sd_clk,
    output wire sd_mosi,
    input  wire sd_miso
);
    reg [7:0] shift_reg;
    reg [2:0] bit_cnt;
    reg active;

    assign sd_cs = 0;  // siempre activo (modo SPI simple)
    assign sd_mosi = shift_reg[7];
    assign sd_clk = clk;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            bit_cnt <= 0;
            active <= 0;
            ready <= 1;
        end else if (wr_en && ready) begin
            shift_reg <= din;
            bit_cnt <= 3'd7;
            active <= 1;
            ready <= 0;
        end else if (active) begin
            shift_reg <= {shift_reg[6:0], sd_miso};
            if (bit_cnt == 0) begin
                dout <= {shift_reg[6:0], sd_miso};
                active <= 0;
                ready <= 1;
            end else begin
                bit_cnt <= bit_cnt - 1;
            end
        end
    end
endmodule
