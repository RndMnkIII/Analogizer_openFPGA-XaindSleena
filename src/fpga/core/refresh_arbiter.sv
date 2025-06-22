module refresh_arbiter #(
  parameter integer CLK_FREQ_HZ = 96_000_000,
  parameter real    TREFI_US    = 7.8
)(
  input  logic        clk,
  input  logic        reset,
  input  logic        loader_busy,
  input  logic [15:0] loader_cycles_left,
  output logic        doRefresh
);

  localparam integer TREFI_CYCLES = CLK_FREQ_HZ * TREFI_US / 1_000_000;
  localparam integer MAX_DEFERS = 8;

  integer trefi_cnt = 0;
  integer defer_cnt = 0;
  logic completed;  // indica si ya terminó la fase de carga

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      trefi_cnt   <= 0;
      defer_cnt   <= 0;
      completed   <= 0;
      doRefresh   <= 0;
    end else if (!completed) begin
      // durante la carga
      doRefresh <= 0;
      if (trefi_cnt >= TREFI_CYCLES) begin
        if (loader_busy && loader_cycles_left > 0 && defer_cnt < MAX_DEFERS) begin
          trefi_cnt <= 0;
          defer_cnt <= defer_cnt + 1;
        end else begin
          doRefresh <= 1;
          trefi_cnt <= 0;
          defer_cnt <= 0;
        end
      end else begin
        trefi_cnt <= trefi_cnt + 1;
      end

      // Cuando la carga finaliza y se ejecuta un refresh
      if (!loader_busy && doRefresh) begin
        completed <= 1;
      end
    end else begin
      // post-carga: mantener doRefresh = 1
      doRefresh <= 1;
    end
  end
endmodule