module sram_controller #(
    parameter int CLK_MHZ = 50  // Frecuencia del reloj en MHz
)(
    input  logic        clk,
    input  logic        rst,

    // Interfaz de control
    input  logic        read_req,
    input  logic        write_req,
    input  logic [16:0] addr_in,
    input  logic [15:0] write_data,
    output logic [15:0] read_data,
    output logic        ready,

    // Interfaz con SRAM
    output logic [16:0] sram_addr,
    inout  wire  [15:0] sram_dq,
    output logic        sram_ce_n,
    output logic        sram_oe_n,
    output logic        sram_we_n
);

    // ===============================
    // 🔧 Cálculo de ciclos de espera
    // ===============================
    localparam real CLK_NS = 1000.0 / CLK_MHZ;

    localparam int CYCLES_READ_WAIT   = int'($ceil(55.0 / CLK_NS));
    localparam int CYCLES_WRITE_PULSE = int'($ceil(40.0 / CLK_NS));
    localparam int CYCLES_WRITE_HOLD  = int'($ceil(10.0 / CLK_NS));

    // ===============================
    // FSM principal
    // ===============================
    typedef enum logic [2:0] {
        IDLE, READ_SETUP, READ_WAIT,
        WRITE_SETUP, WRITE_PULSE, WRITE_HOLD
    } state_t;

    state_t state, next_state;

    logic [15:0] data_latch;
    logic [7:0]  wait_counter;
	logic ready_pulse;
	assign ready = ready_pulse;

    assign sram_addr = addr_in;
    assign read_data = data_latch;
    //assign ready = (state == IDLE);

    // ===============================
    // Bus bidireccional
    // ===============================
    logic [15:0] sram_dq_out;
    logic        sram_dq_oe;

    assign sram_dq   = sram_dq_oe ? sram_dq_out : 16'bz;
    wire   [15:0] sram_dq_in = sram_dq;

    // ===============================
    // FSM síncrona
    // ===============================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            wait_counter <= 0;
			//ready_pulse <= 0;
        end else begin
            state <= next_state;
            if (next_state != state)
                wait_counter <= 0;
            else
                wait_counter <= wait_counter + 1;

			// ✅ pulso de ready solo cuando se entra en IDLE después de una operación
			// if ((state == READ_DONE || state == WRITE_DONE) && next_state == IDLE)
			// 	ready_pulse <= 1;
			// else
			// 	ready_pulse <= 0;  // pulso de un ciclo
        end
    end

    // ===============================
    // FSM combinacional
    // ===============================
    always_comb begin
        next_state = state;
        sram_ce_n = 1;
        sram_oe_n = 1;
        sram_we_n = 1;
        sram_dq_out = 16'h0000;
        sram_dq_oe  = 0;

        case (state)
            IDLE: begin
				ready_pulse = 0;
                if (read_req)
                    next_state = READ_SETUP;
                else if (write_req)
                    next_state = WRITE_SETUP;
            end

            // Lectura
            READ_SETUP: begin
                sram_ce_n = 0;
                next_state = READ_WAIT;
            end
            READ_WAIT: begin
                sram_ce_n = 0;
                sram_oe_n = 0;
                if (wait_counter >= CYCLES_READ_WAIT) begin
                    data_latch = sram_dq_in;  // 🔁 captura dato directamente
					ready_pulse = 1;
        			next_state = IDLE;
				end
            end

            // Escritura
            WRITE_SETUP: begin
                sram_ce_n = 0;
                sram_dq_out = write_data;
                sram_dq_oe  = 1;
                next_state = WRITE_PULSE;
            end
            WRITE_PULSE: begin
                sram_ce_n = 0;
                sram_we_n = 0;
                sram_dq_out = write_data;
                sram_dq_oe  = 1;
                if (wait_counter >= CYCLES_WRITE_PULSE)
                    next_state = WRITE_HOLD;
            end
            WRITE_HOLD: begin
                sram_ce_n = 0;
                sram_dq_out = write_data;
                sram_dq_oe  = 1;
                if (wait_counter >= CYCLES_WRITE_PULSE + CYCLES_WRITE_HOLD) begin
					ready_pulse = 1;
                    next_state = IDLE;
				end
            end
            // WRITE_DONE: begin
			// 	ready_pulse = 1;
            //     next_state = IDLE;
            // end
        endcase
    end

endmodule
