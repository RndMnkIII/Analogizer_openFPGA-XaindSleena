
module sdram_model_real (
    input  logic clk,
    input  logic cs_n, ras_n, cas_n, we_n,
    input  logic [1:0] ba,
    input  logic [12:0] addr,
    inout  logic [15:0] dq,
    input  logic [1:0] dqm
);

    typedef enum logic [1:0] {
        IDLE, ACTIVE, READ, WRITE
    } bank_state_t;

    logic [15:0] mem [0:4*8192*2048-1]; // 4 bancos × 8192 filas × 2048 columnas
    logic [12:0] open_row[3:0];
    bank_state_t bank_state[3:0];

    logic [15:0] dq_out;
    logic        dq_drive;
    assign dq = dq_drive ? dq_out : 16'hzzzz;

    logic [3:0] read_pending;
    logic [3:0][15:0] read_data;
    logic [3:0][1:0]  read_latency;

    always_ff @(posedge clk) begin
        dq_drive <= 0;
        for (int b = 0; b < 4; b++) begin
            if (read_pending[b]) begin
                if (read_latency[b] == 2'd0) begin
                    dq_out <= read_data[b];
                    dq_drive <= 1;
                    read_pending[b] <= 0;
                end else begin
                    read_latency[b] <= read_latency[b] - 1;
                end
            end
        end

        if (!cs_n) begin
            if (!ras_n && cas_n && we_n) begin
                // ACTIVE
                open_row[ba] <= addr;
                bank_state[ba] <= ACTIVE;
            end
            else if (ras_n && !cas_n && we_n) begin
                // READ
                if (bank_state[ba] == ACTIVE) begin
                    int index = ba * 8192*2048 + open_row[ba] * 2048 + addr[9:0];
                    read_data[ba] <= mem[index];
                    read_latency[ba] <= 2;  // simulación de CAS latency 2
                    read_pending[ba] <= 1;
                end
            end
            else if (ras_n && !cas_n && !we_n) begin
                // WRITE
                if (bank_state[ba] == ACTIVE) begin
                    int index = ba * 8192*2048 + open_row[ba] * 2048 + addr[9:0];
                    if (!dqm[0]) mem[index] <= dq;
                end
            end
            else if (!ras_n && cas_n && !we_n) begin
                // PRECHARGE
                bank_state[ba] <= IDLE;
            end
        end
    end
endmodule
