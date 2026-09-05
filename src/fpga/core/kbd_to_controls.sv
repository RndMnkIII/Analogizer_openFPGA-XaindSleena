// -----------------------------------------------------------------------------
// kbd_to_controls.sv  (corregido)
// Conversión de scancodes PS/2 (Set 2) a señales de control estilo MAME.
//
// FIX: cada byte se consume UNA sola vez mediante detección de flanco sobre
// code_valid. Así funciona tanto si code_valid es un strobe de 1 ciclo como
// si se mantiene alto varios ciclos o es un nivel. Antes, al reprocesar el
// byte de scancode tras un break (0xF0), 'breaking' ya estaba limpio y la
// tecla se volvía a pulsar sola -> el release no funcionaba.
//
// Salidas activas a nivel ALTO (1 = tecla pulsada).
// -----------------------------------------------------------------------------
module kbd_to_controls (
    input  logic       clk,
    input  logic       reset,

    input  logic       code_valid,   // strobe/nivel cuando 'scancode' es válido
    input  logic [7:0] scancode,     // byte crudo (PS/2 Set 2)

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
    output logic       pause
);

    logic extended;   // se vio 0xE0
    logic breaking;   // se vio 0xF0

    // ---- Detección de flanco: un byte = un pulso, sea cual sea el ancho -----
    logic code_valid_d;
    wire  byte_stb = code_valid & ~code_valid_d;

    wire  is_prefix = (scancode == 8'hE0) || (scancode == 8'hF0);
    wire  pressed   = ~breaking;   // 1 = make (pulsar), 0 = break (soltar)

    // -------------------------------------------------------------------------
    // Seguimiento de prefijos (solo en el flanco de code_valid)
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            code_valid_d <= 1'b0;
            extended     <= 1'b0;
            breaking     <= 1'b0;
        end else begin
            code_valid_d <= code_valid;
            if (byte_stb) begin
                case (scancode)
                    8'hE0:   extended <= 1'b1;
                    8'hF0:   breaking <= 1'b1;
                    default: begin       // scancode real: limpiar prefijos
                        extended <= 1'b0;
                        breaking <= 1'b0;
                    end
                endcase
            end
        end
    end

    // -------------------------------------------------------------------------
    // Estado de cada tecla/control (solo en el flanco de code_valid)
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
        end else if (byte_stb && !is_prefix) begin
            if (!extended) begin
                // ---- Teclas normales -------------------------------------
                case (scancode)
                    8'h14: p1_b1    <= pressed;  // L-Ctrl  -> P1 boton 1
                    8'h11: p1_b2    <= pressed;  // L-Alt   -> P1 boton 2
                    8'h2D: p2_up    <= pressed;  // R
                    8'h2B: p2_down  <= pressed;  // F
                    8'h23: p2_left  <= pressed;  // D
                    8'h34: p2_right <= pressed;  // G
                    8'h1C: p2_b1    <= pressed;  // A       -> P2 boton 1
                    8'h1B: p2_b2    <= pressed;  // S       -> P2 boton 2
                    8'h2E: coin1    <= pressed;  // 5
                    8'h36: coin2    <= pressed;  // 6
                    8'h16: start1   <= pressed;  // 1
                    8'h1E: start2   <= pressed;  // 2
                    8'h4D: pause    <= pressed;  // P
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