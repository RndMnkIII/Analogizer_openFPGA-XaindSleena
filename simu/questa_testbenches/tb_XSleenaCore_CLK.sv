// tb_XSleenaCore_CLK.sv
// Testbench for XSleenaCore_CLK  (@RndMnkIII)
// Target: QuestaSim / ModelSim (vlog -sv). Also VCD dump for external viewers.
//
// Plusargs:
//   +SIM_MS=<real>   simulation length in milliseconds (default 40.0, ~2.4 frames @60Hz)
//   +P1_P2n=<0|1>    cocktail orientation select fed to the DUT (default 1)
//
// Compile-time defines:
//   +define+NO_VCD        disable VCD dumping (faster, view waves inside QuestaSim only)
//   +define+VCD_TOP_ONLY  dump only DUT top-level ports (smaller .vcd) instead of full hierarchy
//
`default_nettype none
`timescale 1ns/1ps

module tb_XSleenaCore_CLK;

  // ---------------- Parameters ----------------
  // 48 MHz master clock
  localparam real CLK_FREQ_MHZ = 48.0;
  localparam real CLK_PERIOD   = 1000.0 / CLK_FREQ_MHZ; // ns (~20.8333)

  // ---------------- DUT I/O -------------------
  logic        clk;
  logic        clk_12_cen;
  logic        RSTn;
  logic        P1_P2n;

  // H counter outputs
  logic        HCLK, HCLKn;
  logic [7:0]  HN;
  logic [1:0]  HPOS;
  logic [5:0]  DHPOS;
  logic        DVCUNT, VCUNT, M4Hn;

  // V counter outputs
  logic        VI;
  logic [7:0]  VPOS, DVPOS;
  logic        IMS;

  // Video sync / blank
  logic        HBLKn, VBLK, VBLKn, VSYNC, HSYNC, CSYNC;

  // Others
  logic        T1n, T2n, T3n, T3;
  logic        M0n, M1n, M2n, M3n;
  logic        CLRn, BLKn, EDIT, EDITn;
  logic        OBJCHG, OBJCHGn, OBJCLRn, RAMCLRn, OBCH, VSYNC2;

  // ---------------- 48 MHz clock --------------
  initial clk = 1'b0;
  always  #(CLK_PERIOD/2.0) clk = ~clk;

  // ---------------- 12 MHz clock enable -------
  // One clk-wide strobe every 4 clks -> 12 MHz cadence for the counter chain.
  logic [1:0] cen_div = 2'd0;
  always_ff @(posedge clk) cen_div <= cen_div + 2'd1;
  assign clk_12_cen = (cen_div == 2'd3);

  // ---------------- Stimulus ------------------
  // Orientation select (cocktail flip). 1'b1 = P1 by default.
  int unsigned p1p2_arg;
  initial begin
    P1_P2n = 1'b1;
    if ($value$plusargs("P1_P2n=%d", p1p2_arg))
      P1_P2n = p1p2_arg[0];
  end

  // Reset: RSTn is asynchronous active-low in the DUT. Released after some clks.
  initial begin
    RSTn = 1'b0;
    repeat (32) @(posedge clk);
    RSTn = 1'b1;
    $display("[TB] RSTn released at %0t ns", $time);
  end

  // ---------------- Run control ---------------
  real sim_ms;
  initial begin
    if (!$value$plusargs("SIM_MS=%f", sim_ms))
      sim_ms = 40.0;               // ~2.4 frames @60Hz
    #(sim_ms * 1_000_000.0);       // ms -> ns (timescale 1ns)
    $display("[TB] Simulation finished at %0t ns (SIM_MS=%0.3f)", $time, sim_ms);
    $finish;
  end

  // ---------------- VCD dump ------------------
`ifndef NO_VCD
  initial begin
    $dumpfile("XSleenaCore_CLK.vcd");
`ifdef VCD_TOP_ONLY
    $dumpvars(1, dut);   // DUT top-level ports only (smaller file)
    $display("[TB] VCD: XSleenaCore_CLK.vcd (top-level ports only)");
`else
    $dumpvars(0, dut);   // full DUT hierarchy (ic* counter chain visible)
    $display("[TB] VCD: XSleenaCore_CLK.vcd (full DUT hierarchy)");
`endif
  end
`endif

  // ---------------- Sanity monitor ------------
  // Count VSYNC falling edges so you can confirm frames are being produced.
  int vsync_cnt = 0;
  always @(negedge VSYNC) begin
    if (RSTn) begin
      vsync_cnt++;
      $display("[TB] VSYNC fall #%0d at %0t ns  VPOS=%0d DVPOS=%0d",
               vsync_cnt, $time, VPOS, DVPOS);
    end
  end

  // ---------------- DUT -----------------------
  XSleenaCore_CLK dut (
    .clk      (clk),
    .clk_12_cen(clk_12_cen),
    .RSTn     (RSTn),
    .P1_P2n   (P1_P2n),

    // H counter
    .HCLK     (HCLK),
    .HCLKn    (HCLKn),
    .HN       (HN),
    .HPOS     (HPOS),
    .DHPOS    (DHPOS),
    .DVCUNT   (DVCUNT),
    .VCUNT    (VCUNT),
    .M4Hn     (M4Hn),

    // V counter
    .VI       (VI),
    .VPOS     (VPOS),
    .DVPOS    (DVPOS),
    .IMS      (IMS),

    // Video
    .HBLKn    (HBLKn),
    .VBLK     (VBLK),
    .VBLKn    (VBLKn),
    .VSYNC    (VSYNC),
    .HSYNC    (HSYNC),
    .CSYNC    (CSYNC),

    // Others
    .T1n      (T1n),
    .T2n      (T2n),
    .T3n      (T3n),
    .T3       (T3),
    .M0n      (M0n),
    .M1n      (M1n),
    .M2n      (M2n),
    .M3n      (M3n),
    .CLRn     (CLRn),
    .BLKn     (BLKn),
    .EDIT     (EDIT),
    .EDITn    (EDITn),
    .OBJCHG   (OBJCHG),
    .OBJCHGn  (OBJCHGn),
    .OBJCLRn  (OBJCLRn),
    .RAMCLRn  (RAMCLRn),
    .OBCH     (OBCH),
    .VSYNC2   (VSYNC2)
  );

endmodule

`default_nettype wire
