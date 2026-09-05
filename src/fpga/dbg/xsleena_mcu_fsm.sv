// ============================================================================
//  xsleena_mcu_fsm.sv
//
//  Behavioural, drop-in replacement for the MC68705P5 on Xain'd Sleena
//  (Technos, 1986 - romset "xsleena"). It does NOT emulate the 6805 core:
//  it reproduces the host-visible byte protocol and the three table-lookup
//  commands the MCU implements, carrying the MCU's own data tables as a ROM
//  plus the hand-decoded selection logic. Every constant/table/branch below
//  was reverse-engineered from the real ROMs and cross-checked with the MAME
//  driver memory map (technos/xain.cpp).
//
//  HOST BUS (main 6809 side):
//     $3A0E  write : host -> MCU data latch   (command / parameter byte)
//     $3A04  read  : MCU  -> host data latch   (result byte; read clears MCU-sema)
//     $3A05  read  : status  bit3=MCU-sema  bit4=host-sema   (BOTH ACTIVE LOW)
//                    bit5=VBLANK is supplied by other hardware; OR bit3/bit4
//                    from this module into that port read.
//     $3A06  read  : pulse -> comm reset       (host does this once at boot)
//
//  Host handshake (6809 code at $FF57 send / $FF68 recv):
//     send: wait until (status & $10)!=0 then write $3A0E
//     recv: wait until (status & $08)==0 then read  $3A04
//
//  SCRAMBLING: host XORs each sent byte with a 42-entry table (main ROM $9FEA)
//     indexed by a mod-42 counter (0 after the boot comm-reset). The MCU
//     descrambles with an IDENTICAL table ($0233). Verified byte-for-byte
//     identical, so we descramble incoming bytes with that table and counter.
//     Replies are RAW (host does not descramble on read).
//
//  BOOT: after $3A06 the host writes one byte then reads one, expecting $4D
//     ('M' = checksum of MCU ROM[$080..$6FF], verified). We emit $4D and do
//     not descramble/count that first byte (real MCU consumes it in its
//     power-on send branch without advancing the descramble counter).
//
//  COMMAND (descrambled control byte: [7:4]=param count, [3:0]=cmd):
//     cmd0: 5 params -> 3 result bytes   (the only reply this game reads back)
//     cmd1: n params -> 1 result byte
//     cmd2: n params -> 1 result byte
//     other: params consumed, NO reply.
//     Reply = COUNT byte (=#results) then the result bytes; host reads COUNT+1.
//
//  Param map: p0=game $48($10) p1=$4A($11) p2=$49($12) p3=$4E($13) p4=$53($14)
//  cmd0 r1 (2nd result) is only refreshed when (p0==1 && p4==0); otherwise it
//  returns the value from the previous cmd0 -> modelled by r1_hold.
//  The MCU internal timeout ($23) only forces an error reply on a stalled
//  transaction; a synchronous FSM never stalls, so it is the normal (0) path.
// ============================================================================

module xsleena_mcu_fsm #(
    parameter DATA_HEX = "xsleena_mcu_data.hex"   // 2048-byte MCU ROM image
)(
    input  logic       clk,
    input  logic       rst_n,

    input  logic       wr_3a0e,   // 1-clk pulse: host wrote $3A0E (din valid)
    input  logic       rd_3a04,   // 1-clk pulse: host read  $3A04
    input  logic       rd_3a06,   // 1-clk pulse: host read  $3A06 (comm reset)
    input  logic [7:0] din,

    output logic [7:0] data_3a04, // value host reads at $3A04
    output logic       mcu_sema_n,  // status bit3 ($08): 0 = result ready
    output logic       host_sema_n  // status bit4 ($10): 0 = busy / not ready for write
);
    // -------- data-table ROM (single sync read port; block-RAM friendly) -----
    logic [7:0] rom [0:2047];
    initial $readmemh(DATA_HEX, rom);
    // combinational table read (2 KB protection ROM; maps to LUT/MLAB ROM).
    // For a synchronous block-RAM instead, sequence the reads and add a wait
    // state per lookup -- kept combinational here for a clean, correct model.

    // -------- descramble table $0233 (== host table $9FEA) -------------------
    // descramble table $0233 (== host $9FEA), packed table[0] in the MSBs
    localparam [335:0] DESCR_P =
        336'h3476B61912271B8E1892C6044A3D308B10AE81A680A7A4A680A7A902007A191220E0B61933271B8E1913;

    logic [5:0] scnt;
    wire [7:0]  raw = din ^ DESCR_P[(41-scnt)*8 +: 8];

    typedef enum logic [3:0] {
        S_RESET, S_BOOT, S_IDLE, S_PARAMS, S_D0, S_D1, S_D2, S_REPLY, S_WAIT
    } state_t;
    state_t st;

    logic [3:0] cmd, nparam;
    logic [2:0] pidx, ridx, rlen;   // rlen = #result bytes (1 or 3)
    logic [7:0] p0,p1,p2,p3,p4;
    logic [7:0] res [0:2];          // result bytes
    logic [7:0] r1_hold;            // persistent cmd0 2nd result (MCU RAM $16)
    logic [7:0] out_latch;
    logic       out_full;           // MCU-sema (active high internally)

    assign data_3a04  = out_latch;
    assign mcu_sema_n = ~out_full;
    // host may write when we are idle/collecting/boot; busy during dispatch+reply
    // bit4==1 means "ready for a write" (host $FF57 proceeds on bit4==1)
    assign host_sema_n = (st==S_BOOT)||(st==S_IDLE)||(st==S_PARAMS);

    wire [7:0] sel = (p4 != 8'h00) ? p1 : p0;      // cmd0 result0 selector
    wire       c0_r1_upd = (p0==8'h01) && (p4==8'h00);

    function automatic [10:0] r0_base(input [7:0] s, input [7:0] p2b);
        logic z; z = (p2b==8'h00);
        case (s)
            8'd0: r0_base = z?11'h39C:11'h3A0;  8'd1: r0_base = z?11'h3A5:11'h3B5;
            8'd2: r0_base = z?11'h3BA:11'h3C2;  8'd3: r0_base = z?11'h3C7:11'h3CF;
            8'd4: r0_base = z?11'h3CF:11'h3D5;  8'd5: r0_base = z?11'h3DA:11'h3E2;
            default: r0_base = 11'h3E7;         // s==6 and s>=7
        endcase
    endfunction
    function automatic [10:0] r2_base(input [7:0] p0b);
        case (p0b)
            8'd0:r2_base=11'h371; 8'd1:r2_base=11'h375; 8'd2:r2_base=11'h37A;
            8'd3:r2_base=11'h37E; 8'd4:r2_base=11'h386; 8'd5:r2_base=11'h38C;
            default:r2_base=11'h392;
        endcase
    endfunction
    function automatic [10:0] c1_base(input [7:0] p0b, input [7:0] p1b);
        logic z; z = (p1b==8'h00);
        case (p0b)
            8'd0:c1_base=z?11'h499:11'h4AC; 8'd1:c1_base=11'h54D;
            8'd2:c1_base=z?11'h4BC:11'h4AC; 8'd3:c1_base=z?11'h4CB:11'h4AC;
            8'd4:c1_base=z?11'h4DD:11'h514; 8'd5:c1_base=z?11'h514:11'h4AC;
            8'd6:c1_base=z?11'h531:11'h4AC; default:c1_base=z?11'h54D:11'h4AC;
        endcase
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st<=S_RESET; scnt<=0; out_full<=0; out_latch<=0;
            r1_hold<=0; ridx<=0; rlen<=0;
        end else begin
            if (rd_3a04) out_full<=1'b0;              // host consumed a byte

            if (rd_3a06) begin                        // comm reset -> re-arm boot
                st<=S_BOOT; scnt<=6'd0; out_full<=1'b0;
            end else case (st)
            S_RESET: begin st<=S_BOOT; scnt<=6'd0; end

            S_BOOT: if (wr_3a0e) begin                // emit $4D, no descramble/count
                out_latch<=8'h4D; out_full<=1'b1; st<=S_IDLE;
            end

            S_IDLE: if (wr_3a0e) begin
                cmd<=raw[3:0]; nparam<=raw[7:4]; pidx<=3'd0;
                scnt<=(scnt==6'd41)?6'd0:scnt+6'd1;
                if (raw[7:4]==4'd0) begin             // no params: dispatch now
                    case (raw[3:0])
                        4'd0: st<=S_D0;  4'd1: st<=S_D1;  4'd2: st<=S_D2;
                        default: st<=S_IDLE;          // noop cmd
                    endcase
                end else st<=S_PARAMS;
            end

            S_PARAMS: if (wr_3a0e) begin
                case (pidx)
                    3'd0:p0<=raw; 3'd1:p1<=raw; 3'd2:p2<=raw; 3'd3:p3<=raw; default:p4<=raw;
                endcase
                pidx<=pidx+3'd1; nparam<=nparam-4'd1;
                scnt<=(scnt==6'd41)?6'd0:scnt+6'd1;
                if (nparam==4'd1) begin
                    case (cmd)
                        4'd0: st<=S_D0;  4'd1: st<=S_D1;  4'd2: st<=S_D2;
                        default: st<=S_IDLE;
                    endcase
                end
            end

            // ---- cmd0: three combinational lookups, all indexed by p3 ----
            S_D0: begin
                res[0] <= rom[r0_base(sel,p2)+p3];
                if (c0_r1_upd) begin
                    r1_hold <= rom[11'h3AD+p3];
                    res[1]  <= rom[11'h3AD+p3];
                end else
                    res[1]  <= r1_hold;                // persistent (MCU RAM $16)
                res[2] <= rom[r2_base(p0)+p3];
                rlen <= 3'd3; ridx <= 3'd0; st <= S_REPLY;
            end

            // ---- cmd1 / cmd2: single lookup ----
            S_D1: begin res[0] <= rom[c1_base(p0,p1)+p2];       rlen<=3'd1; ridx<=3'd0; st<=S_REPLY; end
            S_D2: begin res[0] <= rom[11'h580+{7'd0,p1[3:0]}];  rlen<=3'd1; ridx<=3'd0; st<=S_REPLY; end

            // ---- stream: COUNT byte then result bytes, via MCU-sema handshake.
            //  present a byte (S_REPLY) then wait for the host read (S_WAIT).
            S_REPLY: begin
                out_latch <= (ridx==3'd0) ? {5'd0,rlen} : res[ridx-3'd1];
                out_full  <= 1'b1;
                st        <= S_WAIT;
            end
            S_WAIT: if (!out_full) begin               // host consumed the byte
                if (ridx==rlen) st<=S_IDLE;            // just sent last result
                else begin ridx<=ridx+3'd1; st<=S_REPLY; end
            end

            default: st<=S_IDLE;
            endcase
        end
    end
endmodule