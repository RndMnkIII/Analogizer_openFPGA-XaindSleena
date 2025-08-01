//SRAM_dual_sync.v
//Dual port static synchronous RAM of variable size with initialization file
//Author: @RndMnkIII
//Date: 20/11/22
`default_nettype none
`timescale 1ns/1ps

//default 8x1K ram size
module SRAM_dual_sync #(parameter DATA_WIDTH = 8, ADDR_WIDTH = 10)(
    input wire clk0,
    input wire clk1,
    input wire [ADDR_WIDTH-1:0] ADDR0,
    input wire [ADDR_WIDTH-1:0] ADDR1,
    input wire [DATA_WIDTH-1:0] DATA0,
    input wire [DATA_WIDTH-1:0] DATA1,
    (* direct_enable = 1 *) input wire cen0,
    (* direct_enable = 1 *) input wire cen1,
    input wire we0,
    input wire we1,
    output reg [DATA_WIDTH-1:0] Q0,
    output reg [DATA_WIDTH-1:0] Q1
    );

    // (* ramstyle = "no_rw_check" *) reg [DATA_WIDTH-1:0] mem[0:(2**ADDR_WIDTH)-1];
    
    // always @(posedge clk0) begin
    //     Q0 <=  mem[ADDR0];

    //     if(cen0 && we0) begin
    //         mem[ADDR0] <= DATA0;
    //     end
    // end


    // always @(posedge clk1) begin
    //     Q1 <=  mem[ADDR1];

    //     if(cen1 && we1) begin
    //         mem[ADDR1] <= DATA1;
    //     end
    // end
    reg [DATA_WIDTH-1:0] mem[(2**ADDR_WIDTH)-1:0];
    
    always @(posedge clk0) begin
        if(cen0 && we0) begin
            mem[ADDR0] <= DATA0;
            Q0 <=  DATA0;
        end
        else begin
            Q0 <=  mem[ADDR0];
        end
    end


    always @(posedge clk1) begin
        if(cen1 && we1) begin
            mem[ADDR1] <= DATA1;
            Q1 <=  DATA1;
        end
        else begin
            Q1 <=  mem[ADDR1];
        end
    end
endmodule