
module sdram_model_dummy (
    input logic clk,
    input logic cs_n, ras_n, cas_n, we_n,
    input logic [1:0] ba,
    input logic [12:0] addr,
    inout logic [15:0] dq,
    input logic [1:0] dqm
);
    logic [15:0] mem [0:65535];
    logic [15:0] dq_out;
    assign dq = (!cs_n && !cas_n && ras_n && we_n) ? dq_out : 16'hzzzz;

    always_ff @(posedge clk) begin
        if (!cs_n && !ras_n && cas_n && we_n) begin
            // ACTIVE command (simulate row open)
        end else if (!cs_n && ras_n && !cas_n && we_n) begin
            // READ
            dq_out <= mem[{ba, addr[9:0]}];
        end else if (!cs_n && ras_n && !cas_n && !we_n) begin
            // WRITE
            if (!dqm[0]) mem[{ba, addr[9:0]}] <= dq;
        end
    end
endmodule
