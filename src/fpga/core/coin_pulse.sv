// -----------------------------------------------------------------------------
// coin_pulse.sv
// Convierte una tecla de coin MANTENIDA en un pulso momentáneo de ancho fijo,
// emulando el impulso del microswitch del mecanismo de monedas real.
//
//   - Una pulsación  -> un único pulso de PULSE_MS ms (aunque mantengas la tecla).
//   - No vuelve a disparar hasta que sueltas la tecla (evita monedas repetidas).
//   - El pulso siempre completa su ancho, aunque sueltes antes, para que la
//     rutina de coin del juego lo muestree y lo debounce con fiabilidad.
//
// Ajusta CLK_HZ a la frecuencia del dominio de reloj donde instancies esto.
// PULSE_MS ~50 ms va sobrado para el debounce del juego; súbelo si algún
// crédito no registra.
// -----------------------------------------------------------------------------
module coin_pulse #(
    parameter int unsigned CLK_HZ   = 50_000_000,  // frecuencia de clk
    parameter int unsigned PULSE_MS = 50           // ancho del impulso de moneda
) (
    input  logic clk,
    input  logic reset,
    input  logic key,     // nivel ALTO mientras la tecla de coin está pulsada
    output logic coin     // un único pulso por pulsación (ancho fijo)
);
    localparam int unsigned PULSE_CYCLES = (CLK_HZ / 1000) * PULSE_MS;
    localparam int unsigned CW           = $clog2(PULSE_CYCLES + 1);

    logic          key_d;     // muestra anterior de key (detección de flanco)
    logic          armed;     // listo para disparar (bloquea repetición al mantener)
    logic [CW-1:0] cnt;

    wire key_rise = key & ~key_d;

    always_ff @(posedge clk) begin
        if (reset) begin
            key_d <= 1'b0;
            armed <= 1'b1;
            cnt   <= '0;
            coin  <= 1'b0;
        end else begin
            key_d <= key;

            if (key_rise && armed) begin
                coin  <= 1'b1;
                cnt   <= CW'(PULSE_CYCLES);
                armed <= 1'b0;                 // no repetir mientras se mantiene
            end else if (cnt != 0) begin
                cnt <= cnt - 1'b1;
                if (cnt == 1) coin <= 1'b0;    // fin del pulso de ancho fijo
            end

            if (!key) armed <= 1'b1;           // re-armar al soltar la tecla
        end
    end
endmodule