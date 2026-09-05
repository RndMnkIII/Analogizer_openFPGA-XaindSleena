// -----------------------------------------------------------------------------
// kbd_to_controls.sv
// Conversión de scancodes PS/2 (Set 2) a señales de control estilo MAME
// para el core de Xain'd Sleena.
//
// Salidas activas a nivel ALTO (1 = tecla pulsada). Si el core espera
// entradas activas a nivel bajo (típico en algunos ports arcade), invierte
// en el punto de conexión.
// -----------------------------------------------------------------------------
module kbd_to_controls (
    input  logic       clk,
    input  logic       reset,

    // Interfaz con tu módulo de captura PS/2:
    input  logic       code_valid,   // strobe de 1 ciclo cuando 'scancode' es válido
    input  logic [7:0] scancode,     // byte crudo del teclado (PS/2 Set 2)

    // Jugador 1
    output logic       p1_up,
    output logic       p1_down,
    output logic       p1_left,
    output logic       p1_right,
    output logic       p1_b1,        // disparo
    output logic       p1_b2,        // salto

    // Jugador 2
    output logic       p2_up,
    output logic       p2_down,
    output logic       p2_left,
    output logic       p2_right,
    output logic       p2_b1,
    output logic       p2_b2,

    // Sistema
    output logic       coin1,
    output logic       coin2,
    output logic       start1,
    output logic       start2,
    output logic       pause,
    output logic       service
);

    // -------------------------------------------------------------------------
    // Seguimiento de prefijos PS/2
    //   0xE0 -> la siguiente tecla es "extendida" (flechas, etc.)
    //   0xF0 -> la siguiente tecla es un "break" (liberación)
    // -------------------------------------------------------------------------
    logic extended;   // se vio 0xE0
    logic breaking;   // se vio 0xF0

    wire  is_prefix = (scancode == 8'hE0) || (scancode == 8'hF0);
    wire  pressed   = ~breaking;   // 1 = make (pulsar), 0 = break (soltar)

    always_ff @(posedge clk) begin
        if (reset) begin
            extended <= 1'b0;
            breaking <= 1'b0;
        end else if (code_valid) begin
            case (scancode)
                8'hE0:   extended <= 1'b1;
                8'hF0:   breaking <= 1'b1;
                default: begin          // scancode real: limpiar prefijos tras usarlo
                    extended <= 1'b0;
                    breaking <= 1'b0;
                end
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Estado de cada tecla/control
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            p1_up  <= 1'b0; p1_down <= 1'b0; p1_left <= 1'b0; p1_right <= 1'b0;
            p1_b1  <= 1'b0; p1_b2   <= 1'b0;
            p2_up  <= 1'b0; p2_down <= 1'b0; p2_left <= 1'b0; p2_right <= 1'b0;
            p2_b1  <= 1'b0; p2_b2   <= 1'b0;
            coin1  <= 1'b0; coin2   <= 1'b0;
            start1 <= 1'b0; start2  <= 1'b0;
            pause  <= 1'b0;
        end else if (code_valid && !is_prefix) begin
            if (!extended) begin
                // ---- Teclas normales -------------------------------------
                case (scancode)
                    8'h14: p1_b1    <= pressed;  // L-Ctrl  -> P1 botón 1
                    8'h11: p1_b2    <= pressed;  // L-Alt   -> P1 botón 2
                    8'h2D: p2_up    <= pressed;  // R
                    8'h2B: p2_down  <= pressed;  // F
                    8'h23: p2_left  <= pressed;  // D
                    8'h34: p2_right <= pressed;  // G
                    8'h1C: p2_b1    <= pressed;  // A       -> P2 botón 1
                    8'h1B: p2_b2    <= pressed;  // S       -> P2 botón 2
                    8'h2E: coin1    <= pressed;  // 5
                    8'h36: coin2    <= pressed;  // 6
                    8'h16: start1   <= pressed;  // 1
                    8'h1E: start2   <= pressed;  // 2
                    8'h4D: pause    <= pressed;  // P
                    8'h46: service  <= pressed;  // 9
                    default: /* ignorar */ ;
                endcase
            end else begin
                // ---- Teclas extendidas (prefijo 0xE0): flechas -----------
                case (scancode)
                    8'h75: p1_up    <= pressed;  // flecha arriba
                    8'h72: p1_down  <= pressed;  // flecha abajo
                    8'h6B: p1_left  <= pressed;  // flecha izquierda
                    8'h74: p1_right <= pressed;  // flecha derecha
                    default: /* ignorar */ ;
                endcase
            end
        end
    end

endmodule
