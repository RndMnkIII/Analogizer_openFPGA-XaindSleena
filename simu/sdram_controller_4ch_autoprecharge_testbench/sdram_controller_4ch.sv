
// sdram_controller_4ch.sv
// Controlador SDRAM optimizado con interleaving para 4 canales + refresco automático

module sdram_controller_4ch (
    input  logic clk,
    input  logic reset,

    // Canal 0
    input  logic        req0,  // nueva señal de solicitud
    input  logic [23:0] addr0,
    input  logic        rd0,
    input  logic        wr0,
    input  logic [15:0] wdata0,
    output logic [15:0] rdata0,
    output logic        ready0,

    // Canal 1
    input  logic        req1,
    input  logic [23:0] addr1,
    input  logic        rd1,
    input  logic        wr1,
    input  logic [15:0] wdata1,
    output logic [15:0] rdata1,
    output logic        ready1,

    // Canal 2
    input  logic        req2,
    input  logic [23:0] addr2,
    input  logic        rd2,
    input  logic        wr2,
    input  logic [15:0] wdata2,
    output logic [15:0] rdata2,
    output logic        ready2,

    // Canal 3
    input  logic        req3,
    input  logic [23:0] addr3,
    input  logic        rd3,
    input  logic        wr3,
    input  logic [15:0] wdata3,
    output logic [15:0] rdata3,
    output logic        ready3,

    // SDRAM
    output logic        clk_sdram,
    output logic        cke,
    output logic        cs_n,
    output logic        ras_n,
    output logic        cas_n,
    output logic        we_n,
    output logic [1:0]  ba,
    output logic [12:0] addr,
    inout  logic [15:0] dq,
    output logic [1:0]  dqm
);

    
    
    // Señales internas
    logic [1:0] bank_selector;
    logic [1:0] channel;          // canal actualmente atendido
    logic [3:0] requests;         // {canal3, canal2, canal1, canal0}
    logic [1:0] rr_pointer;       // puntero de prioridad rotativa
    logic [3:0] ready_flags;

    logic [1:0] bank_selector;
    logic [1:0] channel;  // canal actualmente atendido
    logic [3:0] requests; // bits: {canal3, canal2, canal1, canal0}

    logic [12:0] refresh_counter;
    logic        do_refresh;
    logic [9:0]  refresh_timer;

    
    // Salidas ready por canal
    assign ready0 = ready_flags[0];
    assign ready1 = ready_flags[1];
    assign ready2 = ready_flags[2];
    assign ready3 = ready_flags[3];

    // Máquina de estados
    typedef enum logic [3:0] {
        INIT_WAIT,
        INIT_WAIT_AUTO,
        INIT_REFRESH1,
        INIT_REFRESH2,
        INIT_LOAD_MODE,
        IDLE,
        ACTIVATE,
        READ,
        WRITE,
        WAIT_AUTO,
        REFRESH
    } state_t;

    state_t state;

    // Iniciar señales
    assign clk_sdram = clk;
    assign cke = 1;
    assign dqm = 2'b00;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= INIT_WAIT;
            refresh_timer <= 0;
            refresh_counter <= 0;
            rr_pointer <= 0;
            ready_flags <= 0;
            ras_n <= 1;
            cas_n <= 1;
            we_n  <= 1;
            cs_n  <= 0;

            refresh_timer <= 0;
            refresh_counter <= 0;
        end else begin
            // Temporizador de refresco (~7.81us con reloj a ~100MHz -> 781 ciclos)
            if (refresh_timer >= 10'd750) begin
                do_refresh <= 1;
                refresh_timer <= 0;
            end else begin
                refresh_timer <= refresh_timer + 1;
                do_refresh <= 0;
            end

            
            // Registro de peticiones de canales
            requests[0] <= req0;
            requests[1] <= req1;
            requests[2] <= req2;
            requests[3] <= req3;

            
            // Arbitraje sintetizable: prioridad rotatoria codificada estáticamente
            if (state == IDLE && !do_refresh) begin
                case (rr_pointer)
                    2'd0: if (requests[0]) channel <= 2'd0;
                          else if (requests[1]) channel <= 2'd1;
                          else if (requests[2]) channel <= 2'd2;
                          else if (requests[3]) channel <= 2'd3;
                    2'd1: if (requests[1]) channel <= 2'd1;
                          else if (requests[2]) channel <= 2'd2;
                          else if (requests[3]) channel <= 2'd3;
                          else if (requests[0]) channel <= 2'd0;
                    2'd2: if (requests[2]) channel <= 2'd2;
                          else if (requests[3]) channel <= 2'd3;
                          else if (requests[0]) channel <= 2'd0;
                          else if (requests[1]) channel <= 2'd1;
                    2'd3: if (requests[3]) channel <= 2'd3;
                          else if (requests[0]) channel <= 2'd0;
                          else if (requests[1]) channel <= 2'd1;
                          else if (requests[2]) channel <= 2'd2;
                endcase
                rr_pointer <= rr_pointer + 2'd1;
            end

            if (state == IDLE && !do_refresh) begin
                for (int i = 0; i < 4; i++) begin
                    int idx = (rr_pointer + i) % 4;
                    if (requests[idx]) begin
                        channel <= idx[1:0];
                        rr_pointer <= idx[1:0] + 1;
                        break;
                    end
                end
            end

            requests[0] <= rd0 | wr0;
            requests[1] <= rd1 | wr1;
            requests[2] <= rd2 | wr2;
            requests[3] <= rd3 | wr3;

            // Arbitraje simple: prioridad fija canal 0 a 3
            if (state == IDLE && !do_refresh) begin
                if (requests[0]) channel <= 2'd0;
                else if (requests[1]) channel <= 2'd1;
                else if (requests[2]) channel <= 2'd2;
                else if (requests[3]) channel <= 2'd3;
            end

            
            case (state)
                INIT_WAIT: begin
                    // Espera mínima de 100 us después del encendido
                    // A 96 MHz: 9600 ciclos
                    if (refresh_timer >= 14'd9600) begin
                        state <= INIT_PRECHARGE;
                        refresh_timer <= 0;
                    end else begin
                        refresh_timer <= refresh_timer + 1;
                    end
                end
                INIT_WAIT_AUTO: begin
                    // Esperar al menos 1 ciclo tras comando con A10=1
                    state <= IDLE;
                end
                PRECHARGE: begin
                    // Comando PRECHARGE ALL
                    ras_n <= 0;
                    cas_n <= 1;
                    we_n  <= 0;
                    addr[10] <= 1; // A10 = 1 para todos los bancos
                    state <= INIT_REFRESH1;
                end
                INIT_REFRESH1: begin
                    // Primer AUTO REFRESH
                    ras_n <= 0;
                    cas_n <= 0;
                    we_n  <= 1;
                    state <= INIT_REFRESH2;
                end
                INIT_REFRESH2: begin
                    // Segundo AUTO REFRESH
                    ras_n <= 0;
                    cas_n <= 0;
                    we_n  <= 1;
                    state <= INIT_LOAD_MODE;
                end
                INIT_LOAD_MODE: begin
                    // Cargar registro de modo
                    ras_n <= 0;
                    cas_n <= 0;
                    we_n  <= 0;
                    addr <= 13'b000_0_010_0_0_0_000; // Burst=1, tipo=seq, CL=2, write burst=programmed
                    ba <= 2'b00;
                    state <= IDLE;
                end
                IDLE: begin
                    if (do_refresh) begin
                        state <= REFRESH;
                    end else if (requests[channel]) begin
                        ba <= channel;
                        case (channel)
                        2'd0: addr <= addr0[22:10];
                        2'd1: addr <= addr1[22:10];
                        2'd2: addr <= addr2[22:10];
                        2'd3: addr <= addr3[22:10];
                    endcase
                        state <= ACTIVATE;
                    end
                end
                ACTIVATE: begin
                    ras_n <= 0;
                    cas_n <= 1;
                    we_n  <= 1;
                    case (channel)
                        2'd0: case (channel)
                        2'd0: state <= (rd0 ? READ : WRITE);
                        2'd1: state <= (rd1 ? READ : WRITE);
                        2'd2: state <= (rd2 ? READ : WRITE);
                        2'd3: state <= (rd3 ? READ : WRITE);
                    endcase
                    addr[10] <= 1; // Auto-precharge activado
                        2'd1: state <= (rd1 ? READ : WRITE);
                        2'd2: state <= (rd2 ? READ : WRITE);
                        2'd3: state <= (rd3 ? READ : WRITE);
                    endcase
                end
                READ: begin
                    ras_n <= 1;
                    cas_n <= 0;
                    we_n  <= 1;
                    case (channel)
                        2'd0: ready_flags[channel] <= 1;
                        2'd1: ready1 <= 1;
                        2'd2: ready2 <= 1;
                        2'd3: ready3 <= 1;
                    endcase
                    state <= PRECHARGE;
                end
                WRITE: begin
                    ras_n <= 1;
                    cas_n <= 0;
                    we_n  <= 0;
                    case (channel)
                        2'd0: ready_flags[channel] <= 1;
                        2'd1: ready1 <= 1;
                        2'd2: ready2 <= 1;
                        2'd3: ready3 <= 1;
                    endcase
                    state <= PRECHARGE;
                end
                WAIT_AUTO: begin
                    // Esperar al menos 1 ciclo tras comando con A10=1
                    state <= IDLE;
                end
                PRECHARGE: begin
                    ras_n <= 0;
                    cas_n <= 1;
                    we_n  <= 0;
                    state <= INIT_WAIT;
            refresh_timer <= 0;
            refresh_counter <= 0;
            rr_pointer <= 0;
            ready_flags <= 0;
            ras_n <= 1;
            cas_n <= 1;
            we_n  <= 1;
            cs_n  <= 0;

                end
                REFRESH: begin
                    ras_n <= 0;
                    cas_n <= 0;
                    we_n  <= 1;
                    refresh_counter <= refresh_counter + 1;
                    state <= INIT_WAIT;
            refresh_timer <= 0;
            refresh_counter <= 0;
            rr_pointer <= 0;
            ready_flags <= 0;
            ras_n <= 1;
            cas_n <= 1;
            we_n  <= 1;
            cs_n  <= 0;

                end
            endcase
        end
    end

endmodule
