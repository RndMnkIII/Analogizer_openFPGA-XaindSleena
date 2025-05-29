// Testbench para SDRAM Controller + Modelo SDRAM

`timescale 1ns/1ps

module tb_sdram_controller;

  reg clk = 0;
  reg clk_en = 1;

  always #5 clk = ~clk; // 100 MHz

  // Señales SDRAM
  wire [15:0] dq;
  wire [12:0] addr;
  wire [1:0]  ba;
  wire        dqml, dqmh;
  wire        cs_n, ras_n, cas_n, we_n;

  // Señales de prueba
  reg init_n = 0;
  initial begin
    #100 init_n = 1;
  end

  // Señales de prueba básicas (puerto 1)
  reg        port1_req = 0;
  wire       port1_ack;
  reg        port1_we;
  reg [23:1] port1_a;
  reg [15:0] port1_d;
  wire [15:0] port1_q;
  reg [1:0]  port1_ds;

  // Controlador DUT (debes conectar tu controlador aquí)
  sdram_controller dut (
    .clk(clk),
    .init_n(init_n),
    .SDRAM_DQ(dq),
    .SDRAM_A(addr),
    .SDRAM_BA(ba),
    .SDRAM_DQML(dqml),
    .SDRAM_DQMH(dqmh),
    .SDRAM_nCS(cs_n),
    .SDRAM_nRAS(ras_n),
    .SDRAM_nCAS(cas_n),
    .SDRAM_nWE(we_n),
    .port1_req(port1_req),
    .port1_ack(port1_ack),
    .port1_we(port1_we),
    .port1_a(port1_a),
    .port1_d(port1_d),
    .port1_q(port1_q),
    .port1_ds(port1_ds)
  );

  // Modelo de memoria SDRAM
  sdram_model_sim mem (
    .clk(clk),
    .clk_en(clk_en),
    .dq(dq),
    .addr(addr),
    .ba(ba),
    .dqml(dqml),
    .dqmh(dqmh),
    .cs_n(cs_n),
    .ras_n(ras_n),
    .cas_n(cas_n),
    .we_n(we_n)
  );

  initial begin
    $dumpfile("sdram_test.vcd");
    $dumpvars(0, tb_sdram_controller);

    // Esperar a que termine init
    wait (init_n);
    repeat(10) @(posedge clk);

    // Escritura 32 bits
    @(posedge clk);
    port1_a   <= 23'h000010;
    port1_d   <= 16'hDEAD;
    port1_we  <= 1;
    port1_ds  <= 2'b11;
    port1_req <= 1;
    @(posedge clk);
    port1_req <= 0;
    wait (port1_ack);

    // Esperar unos ciclos y leer
    repeat(6) @(posedge clk);

    @(posedge clk);
    port1_a   <= 23'h000010;
    port1_we  <= 0;
    port1_req <= 1;
    @(posedge clk);
    port1_req <= 0;
    wait (port1_ack);
    @(posedge clk);
    $display("Lectura SDRAM = %h (esperado DEAD)", port1_q);

    #100;
    $finish;
  end

endmodule
