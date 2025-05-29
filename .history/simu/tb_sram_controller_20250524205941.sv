`timescale 1ns/1ps

module tb_sram_controller;

    // === Parámetros ===
    localparam CLK_MHZ = 50;
    localparam CLK_PERIOD = 1000 / CLK_MHZ;  // en ns

    // === Señales de testbench ===
    logic clk = 0;
    logic rst = 1;

    logic read_req, write_req;
    logic [16:0] addr_in;
    logic [15:0] write_data;
    logic [15:0] read_data;
    logic ready;

    // === Señales de SRAM ===
    logic [16:0] sram_addr;
    tri   [15:0] sram_dq;
    logic        sram_ce_n;
    logic        sram_oe_n;
    logic        sram_we_n;

    // === Modelo de SRAM (comportamental, 128K x 16) ===
    logic [15:0] sram_mem [0:131071];
    assign sram_dq = (sram_ce_n == 0 && sram_oe_n == 0 && sram_we_n == 1) ? sram_mem[sram_addr] : 16'bz;

    always_ff @(negedge sram_we_n) begin
        if (!sram_ce_n)
            sram_mem[sram_addr] <= sram_dq;
    end

    // === Instancia del controlador ===
    sram_controller #(
        .CLK_MHZ(CLK_MHZ)
    ) uut (
        .clk(clk),
        .rst(rst),
        .read_req(read_req),
        .write_req(write_req),
        .addr_in(addr_in),
        .write_data(write_data),
        .read_data(read_data),
        .ready(ready),
        .sram_addr(sram_addr),
        .sram_dq(sram_dq),
        .sram_ce_n(sram_ce_n),
        .sram_oe_n(sram_oe_n),
        .sram_we_n(sram_we_n)
    );

    // === Reloj de simulación ===
    always #(CLK_PERIOD / 2.0) clk = ~clk;

    // === Tareas auxiliares ===
    task write(input [16:0] addr, input [15:0] data);
        @(posedge clk);
        wait (ready == 0);
        write_data = data;
        addr_in = addr;
        write_req = 1;
        @(posedge clk);
        write_req = 0;
        wait (ready == 1); // pulso de ready
        @(posedge clk);
    endtask

    task read(input [16:0] addr, output [15:0] data_out);
        @(posedge clk);
        wait (ready == 0);
        addr_in = addr;
        read_req = 1;
        @(posedge clk);
        read_req = 0;
        wait (ready == 1); // pulso de ready
        @(posedge clk);
        data_out = read_data;
    endtask

    // === Prueba principal ===
    initial begin
        $display("Inicio del testbench...");
        #100 rst = 0;

        // Valores de prueba
        logic [15:0] rdata;

        // Escritura
        $display("Escribiendo en dirección 0x0010 el valor 0x1234...");
        write(17'h0010, 16'h1234);

        // Lectura
        $display("Leyendo desde dirección 0x0010...");
        read(17'h0010, rdata);

        // Verificación
        if (rdata === 16'h1234)
            $display("✅ Test PASADO: read_data = %h", rdata);
        else
            $display("❌ Test FALLADO: read_data = %h (esperado 0x1234)", rdata);

        $finish;
    end

endmodule
