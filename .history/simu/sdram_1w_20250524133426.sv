//
// SDRAM Controller
// Copyright (c) 2013 Till Harbaum <till@harbaum.org> 
// Copyright (c) 2019-2022 Gyorgy Szombathelyi
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3.
//
// This program is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
// General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.
//
//------------------------------------------------------------------------------

// 🧠 1. Arquitectura general del controlador
// El controlador gestiona una memoria SDRAM (tipo MT48LC16M16) de 16 bits.
// Dispone de dos canales lógicos: canal 0 (bancos 0 y 1) y canal 1 (bancos 2 y 3).
// Cada canal puede atender múltiples puertos periféricos o CPU: lectura, escritura y tamaños de 16/32/64 bits.
// Utiliza una FSM de 12 estados (t = 0..11), con acceso intercalado entre bancos.

// 🔁 2. Máquina de estados FSM (t)
// STATE_RAS0 y STATE_RAS1: emiten el comando ACTIVE para abrir una fila en bancos 0/1 o 2/3.
// STATE_CAS0 y STATE_CAS1: emiten READ o WRITE, según we_latch/oe_latch.
// STATE_READ0, STATE_READ1: capturan el primer dato de lectura (16 bits).
// STATE_READ1b → STATE_READ1d: capturan los siguientes fragmentos en ráfagas de 32 o 64 bits.
// STATE_DS1b–DS1d: aplican la máscara DQM durante el burst.
// El ciclo FSM se repite, permitiendo solapar activaciones y transferencias entre bancos.

// 📦 3. Gestión de canales y puertos
// Canal 0: port1, cpu1_rom, cpu1_ram, cpu2, cpu3
// Evaluados en orden de prioridad.
// Latch de dirección, datos (din), y tipo de acceso (we, oe).
// En STATE_RAS0, se decide si se activa el banco.
// En STATE_CAS0, se realiza la operación real.

// Canal 1: port2, gfx1/2, sample, sp
// También con arbitraje por prioridad.
// port2 puede ser lectura o escritura.
// gfx, sample, sp son de solo lectura, típicamente 32 o 64 bits.

// En STATE_RAS1 → CMD_ACTIVE, en STATE_CAS1 → CMD_READ o CMD_WRITE.

// ✍️ 4. Escritura
// Comando CMD_WRITE en STATE_CASx si we_latch[x] == 1.
// Se aplican máscaras DQMH/DQML según ds[x].
// Dato din_latch[x] se coloca en SDRAM_DQ.
// Se activa *_ack para señalizar fin de escritura.

// 📥 5. Lectura y ensamblado de datos
// Comando CMD_READ en STATE_CASx si oe_latch[x] == 1.
// Primer fragmento se captura en STATE_READx.
// Para 32 bits: segundo fragmento en READ1b.
// Para 64 bits: fragmentos adicionales en READ1c, READ1d.
// El dato se ensambla en registros como port*_q, gfx*_q, sample_q, sp_q.

// *_valid o *_ack se activan al completarse la transferencia.

// 🔁 6. Refresco automático (AUTO_REFRESH)
// refresh_cnt acumula ciclos.
// Cuando supera RFRSH_CYCLES, need_refresh se activa.
// En STATE_RAS1, si no hay operaciones pendientes, se emite CMD_AUTO_REFRESH y se resetea el contador.

// 🧰 7. Inicialización SDRAM (init)
// Secuencia controlada por reset en STATE_RAS0:
// CMD_PRECHARGE con A10=1 → cierra todos los bancos.
// CMD_AUTO_REFRESH ×2 → estabiliza el array DRAM.
// CMD_LOAD_MODE → configura CAS latency, burst length, etc.
// Tras completar reset, comienza la operación normal.

// ✅ Resumen funcional
// Ciclo FSM	Acción principal
// RASx	Activación de fila (row) en banco
// CASx	Ejecución del comando READ o WRITE
// READx	Captura del dato leídos
// READxb–d	Ensamblado de palabra extendida (32/64 bits)
// DSxb–d	Máscara DQM aplicada durante burst de lectura
// AUTO_REFRESH	Mantenimiento periódico de integridad DRAM
module sdram_4w (

	// interface to the MT48LC16M16 chip
	inout  reg [15:0] SDRAM_DQ,   // 16 bit bidirectional data bus
	output reg [12:0] SDRAM_A,    // 13 bit multiplexed address bus
	output reg        SDRAM_DQML, // máscara de byte bajo
	output reg        SDRAM_DQMH, // máscara de byte alto
	output reg [1:0]  SDRAM_BA,   // two banks
	output            SDRAM_nCS,  // a single chip select
	output            SDRAM_nWE,  // write enable
	output            SDRAM_nRAS, // row address select
	output            SDRAM_nCAS, // columns address select

	// cpu/chipset interface
	input             init_n,     // init signal after FPGA config to initialize RAM
	input             clk,        // sdram clock

	// 1st bank
	input             port1_req,
	output reg        port1_ack = 0,
	input             port1_we,
	input      [23:1] port1_a,
	input       [1:0] port1_ds,
	input      [15:0] port1_d,
	output reg [15:0] port1_q,

	// cpu1 rom/ram
	// cpu1_rom_cs: señal de chip select (indica acceso activo).
	// cpu1_rom_addr[20:1]: dirección de solo lectura.
	// cpu1_rom_q: salida de datos leídos.
	// cpu1_rom_valid: indica que el dato en cpu1_rom_q es válido.
	input      [20:1] cpu1_rom_addr,
	input             cpu1_rom_cs,
	output reg [15:0] cpu1_rom_q,
	output reg        cpu1_rom_valid,


	// cpu1_ram_req: señal de solicitud de acceso.
	// cpu1_ram_we: indica si es lectura (0) o escritura (1).
	// cpu1_ram_addr[22:1]: dirección RAM.
	// cpu1_ram_ds[1:0]: máscara de byte para escritura parcial (como DQML/DQMH).
	// cpu1_ram_d[15:0]: dato de entrada para escritura.
	// cpu1_ram_q[15:0]: dato leído desde SDRAM.
	// cpu1_ram_ack: se activa cuando la transferencia ha concluido.
	input             cpu1_ram_req,
	output reg        cpu1_ram_ack = 0,
	input      [22:1] cpu1_ram_addr,
	input             cpu1_ram_we,
	input       [1:0] cpu1_ram_ds,
	input      [15:0] cpu1_ram_d,
	output reg [15:0] cpu1_ram_q,

	// cpu2 ram
	input      [22:1] cpu2_addr,
	input             cpu2_cs,
	output reg        cpu2_valid = 0,
	input             cpu2_we,
	input       [1:0] cpu2_ds,
	input      [15:0] cpu2_d,
	output reg [15:0] cpu2_q,

	// cpu3 rom
	input             cpu3_req,
	output reg        cpu3_ack = 0,
	input      [22:1] cpu3_addr,
	output reg [15:0] cpu3_q,

	// 2nd bank
	input             port2_req,
	output reg        port2_ack = 0,
	input             port2_we,
	input      [23:1] port2_a,
	input       [1:0] port2_ds,
	input      [15:0] port2_d,
	output reg [15:0] port2_q,

	input             gfx1_req,
	output reg        gfx1_ack = 0,
	input      [22:1] gfx1_addr,
	output reg [15:0] gfx1_q,

	input             gfx2_req,
	output reg        gfx2_ack = 0,
	input      [22:1] gfx2_addr,
	output reg [15:0] gfx2_q,

	input             sample_req,
	output reg        sample_ack = 0,
	input      [22:1] sample_addr,
	output reg [15:0] sample_q,

	input             sp_req,
	output reg        sp_ack = 0,
	input      [22:1] sp_addr,
	output reg [15:0] sp_q
);

parameter  MHZ = 16'd80; // 80 MHz default clock, set it to proper value to calculate refresh rate

localparam RASCAS_DELAY   = 3'd2;   // tRCD=20ns -> 2 cycles@<100MHz
localparam BURST_LENGTH   = 3'b000; // 000=1, 001=2, 010=4, 011=8
localparam ACCESS_TYPE    = 1'b0;   // 0=sequential, 1=interleaved
localparam CAS_LATENCY    = 3'd2;   // 2/3 allowed
localparam OP_MODE        = 2'b00;  // only 00 (standard operation) allowed
localparam NO_WRITE_BURST = 1'b1;   // 0= write burst enabled, 1=only single access write

localparam MODE = { 3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH}; 

// 64ms/8192 rows = 7.8us
// Es un umbral constante que representa cuántos ciclos de reloj pueden pasar antes de que sea obligatorio refrescar la SDRAM. Su valor depende de:
// La frecuencia de reloj (clk) del sistema.
// El requerimiento de refresco del chip SDRAM (típicamente, todas las filas deben refrescarse en 64 ms).
// Por ejemplo, si el chip requiere 8192 ciclos de refresco en 64 ms y tienes un reloj de 100 MHz:
// RFRSH_CYCLES = (100_000_000 * 64e-3) / 8192 ≈ 781
localparam RFRSH_CYCLES = 16'd78*MHZ/4'd10;

// ---------------------------------------------------------------------
// ------------------------ cycle state machine ------------------------
// ---------------------------------------------------------------------

/*
 SDRAM state machine for 2 bank interleaved access
 1 words burst, CL2
cmd issued  registered
 0 RAS0     data1 returned
 1          ras0, data1 returned
 2 CAS0
 3 RAS1     cas0
 4          ras1
 5          data0 returned
 6          data0 returned (but masked via DQM)
 7 CAS1     data0 returned (but masked via DQM)
 8          cas1 - data0 masked
*/

localparam STATE_RAS0      = 4'd0;   // first state in cycle
localparam STATE_CAS0      = 4'd2;
localparam STATE_READ0     = 4'd6;   
localparam STATE_RAS1      = 4'd3;   
localparam STATE_CAS1      = 4'd7;   
localparam STATE_READ1     = 4'd11;

// localparam STATE_READ1b    = 4'd0;
// localparam STATE_READ1c    = 4'd1;
// localparam STATE_READ1d    = 4'd2;
// localparam STATE_DS1b      = 4'd8;
// localparam STATE_DS1c      = 4'd9;
// localparam STATE_DS1d      = 4'd10;
localparam STATE_LAST      = 4'd11;

reg [3:0] t;

always @(posedge clk) begin
	t <= t + 1'd1;
	if (t == STATE_LAST) t <= STATE_RAS0;
end

// ---------------------------------------------------------------------
// --------------------------- startup/reset ---------------------------
// ---------------------------------------------------------------------

// wait 1ms (32 8Mhz cycles) after FPGA config is done before going
// into normal operation. Initialize the ram in the last 16 reset cycles (cycles 15-0)
reg [4:0]  reset;
reg        init = 1'b1;
always @(posedge clk, negedge init_n) begin
	if(!init_n) begin
		reset <= 5'h1f;
		init <= 1'b1;
	end else begin
		if((t == STATE_LAST) && (reset != 0)) reset <= reset - 5'd1;
		init <= !(reset == 0);
	end
end

// ---------------------------------------------------------------------
// ------------------ generate ram control signals ---------------------
// ---------------------------------------------------------------------
// Estas constantes siguen la codificación estándar JEDEC para SDRAM, donde las señales activas-bajas nCS, nRAS, nCAS, nWE se agrupan como un campo de 4 bits.

// Comando SDRAM		nCS	nRAS	nCAS	nWE	Descripción breve
// CMD_INHIBIT			1	1		1		1	No se emite ningún comando
// CMD_NOP				0	1		1		1	No operación (mantener estado anterior)
// CMD_ACTIVE			0	0		1		1	Activar una fila (row) en un banco
// CMD_READ				0	1		0		1	Leer desde dirección (columna)
// CMD_WRITE			0	1		0		0	Escribir en dirección (columna)
// CMD_BURST_TERMINATE	0	1		1		0	Finaliza una ráfaga activa
// CMD_PRECHARGE		0	0		1		0	Cierra la fila abierta
// CMD_AUTO_REFRESH		0	0		0		1	Inicia un ciclo de refresco
// CMD_LOAD_MODE		0	0		0		0	Carga el registro de modo

// all possible commands
localparam CMD_INHIBIT         = 4'b1111;
localparam CMD_NOP             = 4'b0111;
localparam CMD_ACTIVE          = 4'b0011;
localparam CMD_READ            = 4'b0101;
localparam CMD_WRITE           = 4'b0100;
localparam CMD_BURST_TERMINATE = 4'b0110;
localparam CMD_PRECHARGE       = 4'b0010;
localparam CMD_AUTO_REFRESH    = 4'b0001;
localparam CMD_LOAD_MODE       = 4'b0000;

reg [3:0]  sd_cmd;   // current command sent to sd ram
reg [15:0] sd_din;
// drive control signals according to current command
assign SDRAM_nCS  = sd_cmd[3];
assign SDRAM_nRAS = sd_cmd[2];
assign SDRAM_nCAS = sd_cmd[1];
assign SDRAM_nWE  = sd_cmd[0];

reg [24:1] addr_latch[3];
reg [24:1] addr_latch_next[2];
reg [15:0] din_next;
reg [15:0] din_latch[2];
reg        oe_next;
reg  [1:0] oe_latch;
reg        we_next;
reg  [1:0] we_latch;
reg  [1:0] ds_next;
reg  [1:0] ds[2];

reg        port1_state;
reg        port2_state;
reg        cpu1_ram_req_state;
reg        cpu3_req_state;
reg        sp_req_state;
reg        sample_req_state;

localparam PORT_NONE     = 3'd0;
localparam PORT_CPU1_ROM = 3'd1;
localparam PORT_CPU1_RAM = 3'd2;
localparam PORT_CPU2     = 3'd3;
localparam PORT_CPU3     = 3'd4;
localparam PORT_GFX1     = 3'd1;
localparam PORT_GFX2     = 3'd2;
localparam PORT_SAMPLE   = 3'd3;
localparam PORT_SP       = 3'd4;
localparam PORT_REQ      = 3'd6;

reg  [2:0] next_port[2];
reg  [2:0] port[2];

reg        refresh;
reg [10:0] refresh_cnt;

// Esta señal se activa cuando refresh_cnt llega al umbral de RFRSH_CYCLES. Esto le dice al controlador que debe:
// Insertar un comando CMD_AUTO_REFRESH (valor 4'b0001 en sd_cmd).
// Esperar los ciclos necesarios (tRFC) para completar el refresco.
// Resetear refresh_cnt a cero.
// Si no se refrescan las filas, los datos en la SDRAM se corrompen debido a la descarga natural de los condensadores.
wire       need_refresh = (refresh_cnt >= RFRSH_CYCLES);



// Este bloque es un multiplexor de acceso a SDRAM, implementado en una estructura always @(*) (combinacional). Su propósito es:
// 1. Evaluar todas las posibles solicitudes.
// 2. Elegir una (la más prioritaria disponible).
// 3. Preparar señales para:
//    * Dirección (addr_latch_next[0])
//    * Máscara de escritura (ds_next)
//    * Señales de control: lectura/escritura (oe_next, we_next)
//    * Dato de entrada (din_next)
//    * Identificación de puerto (next_port[0])



// PORT1: bank 0,1
always @(*) begin

	//default behavior
	next_port[0] = PORT_NONE;
	addr_latch_next[0] = addr_latch[0];
	ds_next = 2'b00;
	{ oe_next, we_next } = 2'b00;
	din_next = 0;

	if (refresh) begin //Caso 1: Refresco SDRAM
		// nothing
		//No se hace nada si refresh = 1. Esto bloquea temporalmente los accesos durante un ciclo de AUTO_REFRESH.
	
	//PRIO: port1 > cpu1_rom > cpu1_ram > cpu2 > cpu3
	end else if (port1_req ^ port1_state) begin 
		//Caso 2: port1 (interfaz externa genérica)
		// Detecta flanco de subida en port1_req (cambio de estado).
		// Asigna el acceso al puerto PORT_REQ.
		// Calcula oe_next = ~we, we_next = we.
		// Captura dirección, máscara ds, y dato de escritura.
		next_port[0] = PORT_REQ;
		addr_latch_next[0] = { 1'b0, port1_a };
		ds_next = port1_ds;
		{ oe_next, we_next } = { ~port1_we, port1_we };
		din_next = port1_d;
	end else if (/*cpu1_rom_addr != addr_last[PORT_CPU1_ROM] &&*/ cpu1_rom_cs && !cpu1_rom_valid) begin
		//Caso 3: cpu1_rom (ROM de solo lectura)
		// Detecta cpu1_rom_cs activo y aún no válido.
		// Solo lectura: oe_next = 1, we_next = 0.
		// Máscara 2'b11: leer los dos bytes (palabra completa).
		next_port[0] = PORT_CPU1_ROM;
		addr_latch_next[0] = { 4'd0, cpu1_rom_addr };
		ds_next = 2'b11;
		{ oe_next, we_next } = 2'b10;
	end else if (cpu1_ram_req ^ cpu1_ram_req_state) begin
		//Caso 4: cpu1_ram
		// Detecta flanco de cpu1_ram_req.
		// Direccionamiento de 23 bits.
		// Permite lectura y escritura parcial mediante ds.
		next_port[0] = PORT_CPU1_RAM;
		addr_latch_next[0] = { 2'b00, cpu1_ram_addr };
		ds_next = cpu1_ram_ds;
		{ oe_next, we_next } = { ~cpu1_ram_we, cpu1_ram_we };
		din_next = cpu1_ram_d;
	end else if (cpu2_cs && !cpu2_valid) begin
		//Caso 5: cpu2 (RAM para otra CPU)
		next_port[0] = PORT_CPU2;
		addr_latch_next[0] = { 2'b00, cpu2_addr };
		ds_next = cpu2_ds;
		{ oe_next, we_next } = { ~cpu2_we, cpu2_we };
		din_next = cpu2_d;
	end else if (cpu3_req ^ cpu3_req_state) begin
		//Caso 6: cpu3_rom (ROM extra)
		// Acceso de solo lectura.
		// Mismo patrón que cpu1_rom.
		next_port[0] = PORT_CPU3;
		addr_latch_next[0] = { 2'b00, cpu3_addr };
		ds_next = 2'b11;
		{ oe_next, we_next } = 2'b10;
	end
end

// PORT1: bank 2,3
always @(*) begin
	//PRIO: port2 > gfx1 > gfx2 > sample > sp
	if (port2_req ^ port2_state) begin
		// Caso 1: port2 — acceso externo de 32 bits
		// Detecta un cambio (flanco) en la solicitud de acceso port2_req.
		// Asigna el acceso al canal PORT_REQ (igual nombre que en banco 0, pero independiente).
		// addr_latch_next[1] = { 1'b1, port2_a }: se está asignando explícitamente al banco 2 (bit alto en el MSB).
		next_port[1] = PORT_REQ;
		addr_latch_next[1] = { 1'b1, port2_a };
	end else if (gfx1_req ^ gfx1_ack) begin
		//Caso 2: gfx1 — lectura gráfica 1
		// Detecta un acceso pendiente a datos gráficos.
		// addr_latch_next[1] = { 2'b10, gfx1_addr }: fuerza el acceso al banco 2, ya que el prefijo 2'b10 en binario es banco 2.
		next_port[1] = PORT_GFX1;
		addr_latch_next[1] = { 2'b10, gfx1_addr };
	end else if (gfx2_req ^ gfx2_ack) begin
		//Caso 3: gfx2 — lectura gráfica 2
		// Mismo patrón que gfx1.
		// Usa prefijo 2'b10, también dirigido al banco 2.
		next_port[1] = PORT_GFX2;
		addr_latch_next[1] = { 2'b10, gfx2_addr };
	end else if (sample_req ^ sample_req_state) begin
		//Caso 4: sample — lectura de muestras (audio, 64 bits)
		// Detecta una solicitud de muestras de audio (accesos de 64 bits).
		// También dirigido a banco 2.
		next_port[1] = PORT_SAMPLE;
		addr_latch_next[1] = { 2'b10, sample_addr };
	end else if (sp_req ^ sp_req_state) begin
		//Caso 5: sp — sprites u otros datos 64 bits
		// Acceso de 64 bits, mismo tratamiento.
		// Se direcciona a banco 2 (2'b10 como prefijo).
		next_port[1] = PORT_SP;
		addr_latch_next[1] = { 2'b10, sp_addr };
	end else begin
		//Default: ningún acceso
		//Si no hay ninguna solicitud pendiente, se mantiene el valor anterior.
		next_port[1] = PORT_NONE;
		addr_latch_next[1] = addr_latch[1];
	end
end

always @(posedge clk) begin

	// permanently latch ram data to reduce delays
	// Aquí se captura el valor del bus de datos SDRAM (SDRAM_DQ) en un registro interno sd_din.
	// Este valor se usará posteriormente para completar una lectura iniciada anteriormente.
	// Importante: esto debe ocurrir en el ciclo en que el dato llega, típicamente después de un burst (por ejemplo, t=6 o t=11 en la FSM).
	sd_din <= SDRAM_DQ;
	// El bus de datos se coloca en alta impedancia (Z) por defecto.
	// Esto es obligatorio en cualquier arquitectura bidireccional de bus (como SDRAM), para evitar conflictos eléctricos.
	// Sólo en los ciclos de escritura reales se activa el bus como salida.
	SDRAM_DQ <= 16'bZZZZZZZZZZZZZZZZ;
	// Máscaras de byte deshabilitadas
	// Se colocan ambos bits de máscara de datos (high y low) en 1.
	// En SDRAM, un bit de DQM en 1 inhibe la escritura o la lectura de ese byte.
	// Esto deja los datos efectivamente "enmascarados", es decir, no se escribe nada en ese ciclo.
	{ SDRAM_DQMH, SDRAM_DQML } <= 2'b11;
	// El comando SDRAM por defecto es NOP, lo que significa no hacer nada.
	// Esto evita que se emitan comandos espurios si el FSM aún no ha decidido qué hacer.
	sd_cmd <= CMD_NOP;  // default: idle
	//Se incrementa el contador refresh_cnt para controlar cuándo debe realizarse un ciclo de AUTO_REFRESH.
	//Este contador se compara con un umbral (RFRSH_CYCLES) para activar need_refresh.
	refresh_cnt <= refresh_cnt + 1'd1;
	// Se limpia el estado del bus,
	// Se captura cualquier dato pendiente,
	// Se avanza el contador de refresco,
	// Y se deja todo listo para que la FSM determine el próximo paso (READ, WRITE, ACTIVE, REFRESH...).
	// Este patrón es muy importante porque protege contra errores de sincronización y sobreescritura del bus.

	if(init) begin
		//Esto desactiva las salidas de validez de datos para cpu1_rom y cpu2. Se hace para evitar que el sistema lea datos inválidos antes de que la SDRAM esté lista.
		{ cpu1_rom_valid, cpu2_valid } <= 0;
		// initialization takes place at the end of the reset phase

		//La lógica de inicialización se activa sólo durante el estado STATE_RAS0 de la FSM principal.
		//Esto asegura que los comandos se emiten de forma controlada y espaciada, típicamente uno por vuelta de la FSM (12 ciclos).
		if(t == STATE_RAS0) begin

			//Fase 1: PRECHARGE ALL (Cierra todas las filas de todos los bancos)
			//En el ciclo donde reset == 15 (primeros ciclos tras init), se emite el comando CMD_PRECHARGE con A10=1 para cerrar todas las filas de todos los bancos.
			//Esto es obligatorio antes de usar AUTO_REFRESH o LOAD_MODE.
			if(reset == 15) begin
				sd_cmd <= CMD_PRECHARGE;
				SDRAM_A[10] <= 1'b1;      // precharge all banks
			end

			//Fase 2: AUTO REFRESH (2 veces) Estabiliza el array interno de DRAM
			//Se emiten dos ciclos de refresco automático como exige el datasheet de SDRAM.
			//Espaciados entre FSM de 12 ciclos → cumplen los requisitos mínimos de espera entre refrescos.
			if(reset == 10 || reset == 8) begin
				sd_cmd <= CMD_AUTO_REFRESH;
			end

			//Fase 3: LOAD MODE REGISTER
			//Se emite el comando LOAD MODE REGISTER, que configura la SDRAM:
			// Tipo de ráfaga (burst),
			// Longitud del burst,
			// Latencia CAS,
			// Modo secuencial/interleaved.
			// La dirección SDRAM_A contiene los bits codificados en MODE.
			if(reset == 2) begin
				sd_cmd <= CMD_LOAD_MODE;
				SDRAM_A <= MODE;
				SDRAM_BA <= 2'b00;
			end
		end
	end else begin
		//Estas líneas borran las señales *_valid cuando las CPU desactivan su acceso (*_cs = 0), lo cual permite 
		//que en el siguiente ciclo una nueva lectura pueda ser considerada como válida.
		if (!cpu1_rom_cs) cpu1_rom_valid <= 0;
		if (!cpu2_cs) cpu2_valid <= 0;

		// RAS phase
		// bank 0,1
		//Este es el primer paso de un acceso SDRAM. Aquí se prepara toda la información necesaria y se emite el 
		//comando ACTIVE si hay alguna petición pendiente.
		if(t == STATE_RAS0) begin
			//Se latchan (almacenan) los valores calculados en el bloque combinacional anterior:
			// Dirección de acceso,
			// Puerto seleccionado (ej. PORT_REQ, PORT_CPU1_RAM, etc.),
			// Señales de lectura/escritura (aún se inicializan a 0 aquí).
			addr_latch[0] <= addr_latch_next[0];
			port[0] <= next_port[0];
			{ oe_latch[0], we_latch[0] } <= 2'b00;

			//Si hay un puerto pendiente (next_port[0] != PORT_NONE), se genera el comando ACTIVE para abrir una fila en la SDRAM.
			// SDRAM_A[12:0] recibe la dirección de fila (row), extraída de los bits altos.
			// SDRAM_BA[1:0] selecciona el banco (0 o 1, dependiendo del caso).
			// Este comando prepara la SDRAM para realizar luego un READ o WRITE.
			if (next_port[0] != PORT_NONE) begin
				sd_cmd <= CMD_ACTIVE;
				SDRAM_A <= addr_latch_next[0][22:10];
				SDRAM_BA <= addr_latch_next[0][24:23];
			end

			//Latch de máscara y dato de entrada
			//ds[0]: máscara de byte (similar a DQML/DQMH).
			// oe/we: determinan si la operación será de lectura o escritura.
			// din: valor que se enviará al bus de datos en caso de escritura.
			ds[0] <= ds_next;
			{ oe_latch[0], we_latch[0] } <= { oe_next, we_next };
			din_latch[0] <= din_next;

			//Actualización de estado de puertos
			//Se sincronizan los estados de los puertos con las señales de solicitud, para evitar reejecuciones.
			//Estos registros (*_state) se usan en lógica de flanco para detectar nuevas peticiones.
			if (next_port[0] == PORT_REQ) port1_state <= port1_req;
			if (next_port[0] == PORT_CPU1_RAM) cpu1_ram_req_state <= cpu1_ram_req;
			if (next_port[0] == PORT_CPU3) cpu3_req_state <= cpu3_req;
		end

		// bank 2,3
		//Este bloque maneja el estado STATE_RAS1, es decir, la activación de fila (ACTIVE) en los bancos 2 y 3 
		//para el canal lógico 1. Equivale funcionalmente a lo que STATE_RAS0 hace con los bancos 0 y 1, pero 
		//aplicado a los accesos port2, gfx, sample, sp, etc.

		//El estado STATE_RAS1 ocurre unos ciclos después de STATE_RAS0 y permite activar una fila en banco 2 
		//o banco 3, preparando para un acceso posterior.
		if(t == STATE_RAS1) begin
			//Se desactiva el flag de refresh.
			//Esto es importante porque si no se usa este ciclo para refrescar, se debe limpiar.
			refresh <= 1'b0;
			//Se almacena la dirección, tipo de operación, y número de puerto (por ejemplo, PORT_GFX1, PORT_SAMPLE...).
			//oe_latch y we_latch se inicializan a 0 (lectura por defecto).
			addr_latch[1] <= addr_latch_next[1];
			{ oe_latch[1], we_latch[1] } <= 2'b00;
			port[1] <= next_port[1];

			//Activación de banco si hay puerto válido
			if (next_port[1] != PORT_NONE) begin
				//Se genera el comando CMD_ACTIVE para abrir la fila deseada.
				//La dirección de fila y el banco se extraen de los bits altos del latch.
				sd_cmd <= CMD_ACTIVE;
				SDRAM_A <= addr_latch_next[1][22:10];
				SDRAM_BA <= addr_latch_next[1][24:23];

				//Si el acceso es PORT_REQ (port2), se determina si es escritura (we) o lectura (oe).
				// Se preparan los datos y la máscara.
				// Si no es PORT_REQ (por ejemplo, gfx1, sp, sample...), se fuerza una lectura completa sin máscara.
				if (next_port[1] == PORT_REQ) begin
					{ oe_latch[1], we_latch[1] } <= { ~port1_we, port1_we };
					ds[1] <= port2_ds;
					din_latch[1] <= port2_d;
					port2_state <= port2_req;
				end else begin
					{ oe_latch[1], we_latch[1] } <= 2'b10;
					ds[1] <= 2'b11;
				end
			end
			//Sincroniza el estado actual de los accesos a sprites y samples para evitar que se reintenten en el siguiente ciclo.
			if (next_port[1] == PORT_SP) sp_req_state <= sp_req;
			if (next_port[1] == PORT_SAMPLE) sample_req_state <= sample_req;

			//Si no hay acceso, se considera refrescar
			//Si no hay operación en curso en canal 1 y no hay escritura/lectura pendiente en canal 0:
			// Se inicia un ciclo de refresco SDRAM (CMD_AUTO_REFRESH).
			// Se reinicia refresh_cnt.
			// Esto garantiza que:
			// El refresco no interfiere con accesos activos.
			// Se ejecuta en una oportunidad segura (banco 2 o 3 libres, banco 0 o 1 sin actividad).
			if (next_port[1] == PORT_NONE && need_refresh && !we_latch[0] && !oe_latch[0]) begin
				refresh <= 1'b1;
				refresh_cnt <= 0;
				sd_cmd <= CMD_AUTO_REFRESH;
			end
		end

		//Este bloque gestiona la fase CAS (Column Address Strobe) de la FSM del controlador SDRAM, es decir, 
		//el momento en que se emite un comando READ o WRITE hacia la columna activa del banco previamente 
		//habilitado con ACTIVE.
		//Se ejecuta durante los estados STATE_CAS0 (para bancos 0 y 1) y STATE_CAS1 (para bancos 2 y 3), y 
		//lleva a cabo la operación efectiva sobre la SDRAM.

		// CAS phase
		//Solo se ejecuta si hay una operación pendiente (we o oe activado).
		if(t == STATE_CAS0 && (we_latch[0] || oe_latch[0])) begin
			sd_cmd <= we_latch[0]?CMD_WRITE:CMD_READ; //Se emite el comando real hacia SDRAM: lectura o escritura.
			{ SDRAM_DQMH, SDRAM_DQML } <= ~ds[0];     //Se configuran las máscaras de byte (DQM) en negativo (~ds) porque en SDRAM 1 = mascarar, 0 = activar byte.
			
			//En escritura, se colocan los datos (din_latch[0]) en el bus SDRAM_DQ.
			if (we_latch[0]) begin
				SDRAM_DQ <= din_latch[0];

				//Se activan las señales de respuesta correspondientes al puerto origen del acceso:
				// *_ack para señalizar fin de escritura.
				// *_valid para marcar lectura lista (en lecturas, se marcará más adelante).
				case(port[0])
					PORT_REQ: port1_ack <= port1_req;
					PORT_CPU1_RAM: cpu1_ram_ack <= cpu1_ram_req;
                    PORT_CPU2: cpu2_valid <= 1;
					default: ;
				endcase;
			end
			//Dirección de columna, con A10=1 → indica auto-precharge (cierra la fila automáticamente tras la operación).
			//Bits [9:1] son la dirección de columna real.
			SDRAM_A <= { 4'b0010, addr_latch[0][9:1] };  // auto precharge
			//Selección de banco (0 o 1) según la dirección latcheada.
			SDRAM_BA <= addr_latch[0][24:23];
		end

		//Se ejecuta en la segunda mitad del ciclo FSM, si hay operación pendiente en canal 1.
		if(t == STATE_CAS1 && (we_latch[1] || oe_latch[1])) begin
			sd_cmd <= we_latch[1]?CMD_WRITE:CMD_READ;
			{ SDRAM_DQMH, SDRAM_DQML } <= ~ds[1];

			//Si es escritura:
			// Se cargan los datos al bus,
			// Se marca port2_ack como respuesta.
			if (we_latch[1]) begin
				SDRAM_DQ <= din_latch[1];
				port2_ack <= port2_req;
			end
			//Dirección de columna + bit de auto-precharge.
			//Selección de banco 2 o 3.
			SDRAM_A <= { 4'b0010, addr_latch[1][9:1] };  // auto precharge
			SDRAM_BA <= addr_latch[1][24:23];
		end

		// Data returned
		// Este bloque corresponde al momento en que los datos leídos desde la SDRAM ya han llegado al bus de datos (SDRAM_DQ) 
		// y se capturaron previamente en el registro sd_din. Es la etapa final de una operación de lectura iniciada en STATE_CASx,
		//  y ocurre en los estados:
		// STATE_READ0 → datos del canal 0 (bancos 0 y 1),
		// STATE_READ1 → datos del canal 1 (bancos 2 y 3).
		//
		// ¿Cuándo ocurre la llegada de datos?
		// El dato llega después del comando READ con una latencia CAS (en este diseño parece ser CL=2), por lo que:
		// El comando READ se emite en t = 2 (STATE_CAS0)
		// El dato aparece en t = 6 (STATE_READ0) para banco 0
		// De forma análoga para STATE_CAS1 y STATE_READ1 en canal 1

		//🔷 Canal 0 — STATE_READ0 (bancos 0 y 1)
		// Solo se ejecuta si:
		// * El estado actual es STATE_READ0
		// * La operación capturada era una lectura (oe_latch[0] = 1)
		if(t == STATE_READ0 && oe_latch[0]) begin

			//Multiplexor de destino de datos leídos
			// Se enruta el valor leído (sd_din) hacia la salida adecuada según el puerto que originó la solicitud:
			// Puerto lógico	Acción realizada
			// PORT_REQ		Escribe en port1_q, activa port1_ack
			// PORT_CPU1_ROM	Escribe en cpu1_rom_q, activa cpu1_rom_valid
			// PORT_CPU1_RAM	Escribe en cpu1_ram_q, activa cpu1_ram_ack
			// PORT_CPU2		Escribe en cpu2_q, activa cpu2_valid
			// PORT_CPU3		Escribe en cpu3_q, activa cpu3_ack
			// ✅ Cada uno tiene su señal de respuesta sincronizada para indicar al consumidor que el dato ya está disponible.
			case(port[0])
				PORT_REQ:  begin port1_q <= sd_din; port1_ack <= port1_req; end
				PORT_CPU1_ROM: begin cpu1_rom_q <= sd_din; cpu1_rom_valid <= 1; end
				PORT_CPU1_RAM: begin cpu1_ram_q <= sd_din; cpu1_ram_ack <= cpu1_ram_req; end
				PORT_CPU2: begin cpu2_q  <= sd_din; cpu2_valid <= 1; end
				PORT_CPU3: begin cpu3_q  <= sd_din; cpu3_ack <= cpu3_req; end
				default: ;
			endcase;
		end

		//🟠 Canal 1 — STATE_READ1 (bancos 2 y 3)
		// Equivalente a STATE_READ0, pero para banco 2/3 y canal 1.
		if(t == STATE_READ1 && oe_latch[1]) begin
			//Multiplexor de destino de datos leídos
			// En este caso:
			// Todas son interfaces de solo lectura
			// Solo se escribe la palabra de 16 bits en el campo inferior ([15:0])
			// Se activa una señal *_valid aquí
			case(port[1])
				PORT_REQ  :  	begin port2_q[15:0] <= sd_din;    port2_ack <= port2_req;  end  
				PORT_GFX1 :  	begin gfx1_q[15:0] <= sd_din;     gfx1_ack <= gfx1_req;    end 
				PORT_GFX2 :  	begin gfx2_q[15:0] <= sd_din;     gfx2_ack <= gfx2_req;    end 
				PORT_SAMPLE: 	begin sample_q[15:0] <= sd_din;   sample_ack <= sample_req;end 
				PORT_SP   :    	begin sp_q[15:0] <= sd_din;       sp_ack <= sp_req;        end
				default: ;
			endcase;
		end
	end
end

endmodule
