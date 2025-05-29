module sram_controller_sync (
    input  logic        clk,
    input  logic        rst,

    input  logic [16:0] addr,
    input  logic [15:0] din,
    input  logic        req,
    input  logic        wr,      // 1 = write, 0 = read
    output logic [15:0] dout,
    output logic        ready,

    // SRAM interface
    output logic [16:0] sram_addr,
    inout  tri   [15:0] sram_data,
    output logic        sram_ce_n,
    output logic        sram_we_n,
    output logic        sram_oe_n,
    output logic        sram_lb_n,
    output logic        sram_ub_n
);

    // Parámetros de timing
    parameter WAIT_CYCLES = 3;

    // Estado interno
    typedef enum logic [1:0] {IDLE, SETUP, WAIT, DONE} state_t;
    state_t state;
    logic [1:0] wait_count;
    logic [15:0] data_latch;
    logic dir_write;

    assign sram_addr = addr;
    assign sram_lb_n = 1'b0;  // Siempre accedemos a los 16 bits
    assign sram_ub_n = 1'b0;
    assign sram_ce_n = (state == IDLE);
    assign sram_oe_n = dir_write ? 1'b1 : 1'b0;
    assign sram_we_n = dir_write ? 1'b0 : 1'b1;
    assign sram_data = (dir_write && state == WAIT) ? din : 'bz;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            wait_count <= 0;
            ready <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    ready <= 1'b0;
                    if (req) begin
                        dir_write <= wr;
                        state <= SETUP;
                    end
                end
                SETUP: begin
                    wait_count <= WAIT_CYCLES;
                    state <= WAIT;
                end
                WAIT: begin
                    if (wait_count == 0) begin
                        if (!dir_write)
                            data_latch <= sram_data;
                        state <= DONE;
                    end else begin
                        wait_count <= wait_count - 1;
                    end
                end
                DONE: begin
                    ready <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

    assign dout = data_latch;

endmodule
