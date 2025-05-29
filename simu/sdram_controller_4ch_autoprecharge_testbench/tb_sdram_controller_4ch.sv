
`timescale 1ns / 1ps

module tb_sdram_controller_4ch;

    logic clk = 0;
    logic reset = 1;

    logic [23:0] addr0 = 24'h000100;
    logic rd0 = 0, wr0 = 0, req0 = 0;
    logic [15:0] wdata0 = 16'h1234;
    logic [15:0] rdata0;
    logic ready0;

    logic [23:0] addr1 = 24'h000200;
    logic rd1 = 0, wr1 = 0, req1 = 0;
    logic [15:0] wdata1 = 16'h2345;
    logic [15:0] rdata1;
    logic ready1;

    logic [23:0] addr2 = 24'h000300;
    logic rd2 = 0, wr2 = 0, req2 = 0;
    logic [15:0] wdata2 = 16'h3456;
    logic [15:0] rdata2;
    logic ready2;

    logic [23:0] addr3 = 24'h000400;
    logic rd3 = 0, wr3 = 0, req3 = 0;
    logic [15:0] wdata3 = 16'h4567;
    logic [15:0] rdata3;
    logic ready3;

    logic        clk_sdram, cke, cs_n, ras_n, cas_n, we_n;
    logic [1:0]  ba;
    logic [12:0] addr;
    logic [15:0] dq;
    logic [1:0]  dqm;

    // Instanciar DUT
    sdram_controller_4ch dut (
        .clk(clk), .reset(reset),
        .addr0(addr0), .rd0(rd0), .wr0(wr0), .req0(req0), .wdata0(wdata0), .rdata0(rdata0), .ready0(ready0),
        .addr1(addr1), .rd1(rd1), .wr1(wr1), .req1(req1), .wdata1(wdata1), .rdata1(rdata1), .ready1(ready1),
        .addr2(addr2), .rd2(rd2), .wr2(wr2), .req2(req2), .wdata2(wdata2), .rdata2(rdata2), .ready2(ready2),
        .addr3(addr3), .rd3(rd3), .wr3(wr3), .req3(req3), .wdata3(wdata3), .rdata3(rdata3), .ready3(ready3),
        .clk_sdram(clk_sdram), .cke(cke), .cs_n(cs_n),
        .ras_n(ras_n), .cas_n(cas_n), .we_n(we_n),
        .ba(ba), .addr(addr), .dq(dq), .dqm(dqm)
    );

    // Generar clock 96 MHz
    always #5.208 clk = ~clk;  // Periodo ≈ 10.416 ns

    initial begin
        $dumpfile("tb_sdram_controller.vcd");
        $dumpvars(0, tb_sdram_controller_4ch);

        #100 reset = 0;

        // Esperar a que se complete inicialización
        #120000;

        // Petición de lectura canal 0
        rd0 = 1;
        req0 = 1;
        #20;
        req0 = 0;

        wait (ready0 == 1);
        #40;

        $display("Lectura canal 0 completada: %h", rdata0);

        
        // Escritura canal 1
        wr1 = 1;
        req1 = 1;
        #20;
        req1 = 0;
        wr1 = 0;

        wait (ready1 == 1);
        #20;
        $display("Escritura canal 1 completada");

        // Lectura canal 2
        rd2 = 1;
        req2 = 1;
        #20;
        req2 = 0;

        wait (ready2 == 1);
        #20;
        $display("Lectura canal 2 completada: %h", rdata2);

        // Escritura canal 3
        wr3 = 1;
        req3 = 1;
        #20;
        req3 = 0;
        wr3 = 0;

        wait (ready3 == 1);
        #20;
        $display("Escritura canal 3 completada");

        // Acceso adicional a banco 0 tras auto-precharge
        #40;
        rd0 = 1;
        req0 = 1;
        addr0 = 24'h000110; // diferente columna, mismo banco
        #20;
        req0 = 0;

        wait (ready0 == 1);
        #20;
        $display("Lectura post-auto-precharge canal 0: %h", rdata0);

        $finish;
    
    end

endmodule
