
module spi_master #(
    parameter CLK_DIV = 4
)(
    input  wire clk,
    input  wire rst,
    input  wire start,
    input  wire [7:0] data_in,
    output reg  [7:0] data_out,
    output reg  ready,

    output reg  sclk,
    output wire mosi,
    input  wire miso
);

reg [2:0] bit_cnt;
reg [7:0] shift_reg;
reg [7:0] clk_div_cnt;
reg active;

assign mosi = shift_reg[7];

always @(posedge clk or posedge rst) begin
    if (rst) begin
        ready <= 1;
        sclk <= 0;
        clk_div_cnt <= 0;
        active <= 0;
    end else begin
        if (start && ready) begin
            shift_reg <= data_in;
            ready <= 0;
            active <= 1;
            bit_cnt <= 7;
            sclk <= 0;
            clk_div_cnt <= 0;
        end else if (active) begin
            clk_div_cnt <= clk_div_cnt + 1;
            if (clk_div_cnt == CLK_DIV - 1) begin
                clk_div_cnt <= 0;
                sclk <= ~sclk;

                if (sclk == 0) begin
                    // Captura en flanco de subida
                    shift_reg <= {shift_reg[6:0], miso};
                    if (bit_cnt == 0) begin
                        data_out <= {shift_reg[6:0], miso};
                        ready <= 1;
                        active <= 0;
                    end else begin
                        bit_cnt <= bit_cnt - 1;
                    end
                end
            end
        end
    end
end

endmodule
