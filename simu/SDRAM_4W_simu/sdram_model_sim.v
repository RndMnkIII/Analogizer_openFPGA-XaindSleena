// SDRAM model for simulation only (MT48LC16M16-like, 16-bit wide)

module sdram_model_sim #(
    parameter ROWS = 4096,
    parameter COLS = 256,
    parameter BANKS = 4,
    parameter tRCD = 2,      // delay from ACTIVE to READ/WRITE (in clk cycles)
    parameter tCAS = 2,      // CAS latency (in clk cycles)
    parameter tRP  = 2       // delay for PRECHARGE to next ACTIVE
)(
    input             clk,
    input             clk_en,
    inout      [15:0] dq,
    input     [12:0]  addr,
    input     [1:0]   ba,
    input             dqml,
    input             dqmh,
    input             cs_n,
    input             ras_n,
    input             cas_n,
    input             we_n
);

    localparam CMD_ACTIVE = 3'b011;
    localparam CMD_READ   = 3'b101;
    localparam CMD_WRITE  = 3'b100;
    localparam CMD_PRECH  = 3'b010;
    localparam CMD_AUTO_R = 3'b001;
    localparam CMD_NOP    = 3'b111;

    reg [15:0] mem [0:BANKS-1][0:ROWS-1][0:COLS-1];
    reg [12:0] open_row[0:BANKS-1];
    reg        row_open[0:BANKS-1];

    reg [15:0] dq_out;
    assign #3.5 dq = (driving && !cs_n) ? dq_out : 16'bz; // model pin delay

    reg driving = 0;
    reg [2:0] cmd;

    reg [3:0] burst_ctr;
    reg [12:0] col_addr;
    reg [1:0] burst_bank;
    reg [12:0] burst_row;
    reg [2:0] burst_timer = 0;

    reg [2:0] read_latency = 0;
    reg [15:0] read_buffer;
    reg read_pending = 0;

    integer b, r, c;

    always @(posedge clk) if (clk_en) begin
        cmd <= {ras_n, cas_n, we_n};
        driving <= 0;

        // delay mechanism for read burst output
        if (read_pending) begin
            if (read_latency == tCAS) begin
                dq_out <= read_buffer;
                driving <= 1;
                burst_ctr <= burst_ctr + 1;
                if (burst_ctr < 3) begin
                    read_buffer <= mem[burst_bank][burst_row][col_addr + burst_ctr + 1];
                    read_latency <= 1; // next word comes one cycle after
                end else begin
                    read_pending <= 0;
                end
            end else begin
                read_latency <= read_latency + 1;
            end
        end

        // decode commands
        case (cmd)
            CMD_ACTIVE: begin
                if (!cs_n) begin
                    open_row[ba] <= addr;
                    row_open[ba] <= 1;
                end
            end

            CMD_READ: begin
                if (!cs_n && row_open[ba]) begin
                    col_addr <= addr[9:0];
                    burst_bank <= ba;
                    burst_row <= open_row[ba];
                    burst_ctr <= 0;
                    read_buffer <= mem[ba][open_row[ba]][addr[9:0]];
                    read_latency <= 1;
                    read_pending <= 1;
                end
            end

            CMD_WRITE: begin
                if (!cs_n && row_open[ba]) begin
                    if (!dqml) mem[ba][open_row[ba]][addr[9:0]][7:0]  <= #4 dq[7:0];
                    if (!dqmh) mem[ba][open_row[ba]][addr[9:0]][15:8] <= #4 dq[15:8];
                end
            end

            CMD_PRECH: begin
                if (!cs_n) row_open[ba] <= 0;
            end

            CMD_AUTO_R: begin
                if (!cs_n) begin
                    for (b = 0; b < BANKS; b = b + 1) begin
                        if (row_open[b]) begin
                            row_open[b] <= 0;
                        end
                    end
                end
            end
        endcase
    end
endmodule
