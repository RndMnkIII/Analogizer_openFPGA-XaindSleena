module string_to_ram_writer (
    input  logic        clk,
    input  logic        start,
    input  logic [5:0]  string_index,
    input  logic [10:0] base_addr,
    output logic        wr_en,
    output logic [10:0] wr_addr,
    output logic [7:0]  wr_data,
    output logic        busy
);

    typedef enum logic [2:0] {
        IDLE,
        LOAD_OFFSET,
        READ_CHAR,
        WRITE_CHAR,
        NEXT_CHAR,
        DONE
    } state_t;

    state_t state;

    localparam int STRING_MEM_SIZE = 369;
    logic [7:0] string_data [0:STRING_MEM_SIZE-1];
    logic [8:0] string_offsets [0:39];

    // Datos de las cadenas
    initial begin
        string_data[0] = "R";
        string_data[1] = "G";
        string_data[2] = "B";
        string_data[3] = "S";
        string_data[4] = 8'h00;
        string_data[5] = "R";
        string_data[6] = "G";
        string_data[7] = "s";
        string_data[8] = "B";
        string_data[9] = 8'h00;
        string_data[10] = "Y";
        string_data[11] = "P";
        string_data[12] = "b";
        string_data[13] = "P";
        string_data[14] = "r";
        string_data[15] = 8'h00;
        string_data[16] = "Y";
        string_data[17] = "/";
        string_data[18] = "C";
        string_data[19] = " ";
        string_data[20] = "N";
        string_data[21] = "T";
        string_data[22] = "S";
        string_data[23] = "C";
        string_data[24] = 8'h00;
        string_data[25] = "Y";
        string_data[26] = "/";
        string_data[27] = "C";
        string_data[28] = " ";
        string_data[29] = "P";
        string_data[30] = "A";
        string_data[31] = "L";
        string_data[32] = 8'h00;
        string_data[33] = "S";
        string_data[34] = "C";
        string_data[35] = " ";
        string_data[36] = "0";
        string_data[37] = "%";
        string_data[38] = " ";
        string_data[39] = "R";
        string_data[40] = "G";
        string_data[41] = "B";
        string_data[42] = "H";
        string_data[43] = "V";
        string_data[44] = 8'h00;
        string_data[45] = "S";
        string_data[46] = "C";
        string_data[47] = " ";
        string_data[48] = "2";
        string_data[49] = "5";
        string_data[50] = "%";
        string_data[51] = " ";
        string_data[52] = "R";
        string_data[53] = "G";
        string_data[54] = "B";
        string_data[55] = "H";
        string_data[56] = "V";
        string_data[57] = 8'h00;
        string_data[58] = "S";
        string_data[59] = "C";
        string_data[60] = " ";
        string_data[61] = "5";
        string_data[62] = "0";
        string_data[63] = "%";
        string_data[64] = " ";
        string_data[65] = "R";
        string_data[66] = "G";
        string_data[67] = "B";
        string_data[68] = "H";
        string_data[69] = "V";
        string_data[70] = 8'h00;
        string_data[71] = "S";
        string_data[72] = "C";
        string_data[73] = " ";
        string_data[74] = "7";
        string_data[75] = "5";
        string_data[76] = "%";
        string_data[77] = " ";
        string_data[78] = "R";
        string_data[79] = "G";
        string_data[80] = "B";
        string_data[81] = "H";
        string_data[82] = "V";
        string_data[83] = 8'h00;
        string_data[84] = "S";
        string_data[85] = "C";
        string_data[86] = " ";
        string_data[87] = "H";
        string_data[88] = "Q";
        string_data[89] = "2";
        string_data[90] = "x";
        string_data[91] = " ";
        string_data[92] = "R";
        string_data[93] = "G";
        string_data[94] = "B";
        string_data[95] = "H";
        string_data[96] = "V";
        string_data[97] = 8'h00;
        string_data[98] = "S";
        string_data[99] = "N";
        string_data[100] = "A";
        string_data[101] = "C";
        string_data[102] = " ";
        string_data[103] = "P";
        string_data[104] = "1";
        string_data[105] = " ";
        string_data[106] = "-";
        string_data[107] = ">";
        string_data[108] = " ";
        string_data[109] = "P";
        string_data[110] = "o";
        string_data[111] = "c";
        string_data[112] = "k";
        string_data[113] = "e";
        string_data[114] = "t";
        string_data[115] = " ";
        string_data[116] = "P";
        string_data[117] = "1";
        string_data[118] = 8'h00;
        string_data[119] = "S";
        string_data[120] = "N";
        string_data[121] = "A";
        string_data[122] = "C";
        string_data[123] = " ";
        string_data[124] = "P";
        string_data[125] = "1";
        string_data[126] = " ";
        string_data[127] = "-";
        string_data[128] = ">";
        string_data[129] = " ";
        string_data[130] = "P";
        string_data[131] = "o";
        string_data[132] = "c";
        string_data[133] = "k";
        string_data[134] = "e";
        string_data[135] = "t";
        string_data[136] = " ";
        string_data[137] = "P";
        string_data[138] = "2";
        string_data[139] = 8'h00;
        string_data[140] = "S";
        string_data[141] = "N";
        string_data[142] = "A";
        string_data[143] = "C";
        string_data[144] = " ";
        string_data[145] = "P";
        string_data[146] = "1";
        string_data[147] = ",";
        string_data[148] = "P";
        string_data[149] = "2";
        string_data[150] = " ";
        string_data[151] = "-";
        string_data[152] = ">";
        string_data[153] = " ";
        string_data[154] = "P";
        string_data[155] = "o";
        string_data[156] = "c";
        string_data[157] = "k";
        string_data[158] = "e";
        string_data[159] = "t";
        string_data[160] = " ";
        string_data[161] = "P";
        string_data[162] = "1";
        string_data[163] = ",";
        string_data[164] = "P";
        string_data[165] = "2";
        string_data[166] = 8'h00;
        string_data[167] = "S";
        string_data[168] = "N";
        string_data[169] = "A";
        string_data[170] = "C";
        string_data[171] = " ";
        string_data[172] = "P";
        string_data[173] = "1";
        string_data[174] = ",";
        string_data[175] = "P";
        string_data[176] = "2";
        string_data[177] = " ";
        string_data[178] = "-";
        string_data[179] = ">";
        string_data[180] = " ";
        string_data[181] = "P";
        string_data[182] = "o";
        string_data[183] = "c";
        string_data[184] = "k";
        string_data[185] = "e";
        string_data[186] = "t";
        string_data[187] = " ";
        string_data[188] = "P";
        string_data[189] = "2";
        string_data[190] = ",";
        string_data[191] = "P";
        string_data[192] = "1";
        string_data[193] = 8'h00;
        string_data[194] = "S";
        string_data[195] = "N";
        string_data[196] = "A";
        string_data[197] = "C";
        string_data[198] = " ";
        string_data[199] = "P";
        string_data[200] = "1";
        string_data[201] = ",";
        string_data[202] = "P";
        string_data[203] = "2";
        string_data[204] = " ";
        string_data[205] = "-";
        string_data[206] = ">";
        string_data[207] = " ";
        string_data[208] = "P";
        string_data[209] = "o";
        string_data[210] = "c";
        string_data[211] = "k";
        string_data[212] = "e";
        string_data[213] = "t";
        string_data[214] = " ";
        string_data[215] = "P";
        string_data[216] = "3";
        string_data[217] = ",";
        string_data[218] = "P";
        string_data[219] = "4";
        string_data[220] = 8'h00;
        string_data[221] = "S";
        string_data[222] = "N";
        string_data[223] = "A";
        string_data[224] = "C";
        string_data[225] = " ";
        string_data[226] = "P";
        string_data[227] = "1";
        string_data[228] = "-";
        string_data[229] = "P";
        string_data[230] = "4";
        string_data[231] = " ";
        string_data[232] = "-";
        string_data[233] = ">";
        string_data[234] = " ";
        string_data[235] = "P";
        string_data[236] = "o";
        string_data[237] = "c";
        string_data[238] = "k";
        string_data[239] = "e";
        string_data[240] = "t";
        string_data[241] = " ";
        string_data[242] = "P";
        string_data[243] = "1";
        string_data[244] = "-";
        string_data[245] = "P";
        string_data[246] = "4";
        string_data[247] = 8'h00;
        string_data[248] = "N";
        string_data[249] = "o";
        string_data[250] = "n";
        string_data[251] = "e";
        string_data[252] = 8'h00;
        string_data[253] = "D";
        string_data[254] = "B";
        string_data[255] = "1";
        string_data[256] = "5";
        string_data[257] = " ";
        string_data[258] = "N";
        string_data[259] = "o";
        string_data[260] = "r";
        string_data[261] = "m";
        string_data[262] = "a";
        string_data[263] = "l";
        string_data[264] = 8'h00;
        string_data[265] = "N";
        string_data[266] = "E";
        string_data[267] = "S";
        string_data[268] = 8'h00;
        string_data[269] = "S";
        string_data[270] = "N";
        string_data[271] = "E";
        string_data[272] = "S";
        string_data[273] = 8'h00;
        string_data[274] = "P";
        string_data[275] = "C";
        string_data[276] = "E";
        string_data[277] = " ";
        string_data[278] = "2";
        string_data[279] = "B";
        string_data[280] = "t";
        string_data[281] = "n";
        string_data[282] = 8'h00;
        string_data[283] = "P";
        string_data[284] = "C";
        string_data[285] = "E";
        string_data[286] = " ";
        string_data[287] = "6";
        string_data[288] = "B";
        string_data[289] = "t";
        string_data[290] = "n";
        string_data[291] = 8'h00;
        string_data[292] = "P";
        string_data[293] = "C";
        string_data[294] = "E";
        string_data[295] = " ";
        string_data[296] = "M";
        string_data[297] = "u";
        string_data[298] = "l";
        string_data[299] = "t";
        string_data[300] = "i";
        string_data[301] = "t";
        string_data[302] = "a";
        string_data[303] = "p";
        string_data[304] = 8'h00;
        string_data[305] = "D";
        string_data[306] = "B";
        string_data[307] = "1";
        string_data[308] = "5";
        string_data[309] = " ";
        string_data[310] = "F";
        string_data[311] = "a";
        string_data[312] = "s";
        string_data[313] = "t";
        string_data[314] = 8'h00;
        string_data[315] = "P";
        string_data[316] = "S";
        string_data[317] = "X";
        string_data[318] = " ";
        string_data[319] = "D";
        string_data[320] = "i";
        string_data[321] = "g";
        string_data[322] = "i";
        string_data[323] = "t";
        string_data[324] = "a";
        string_data[325] = "l";
        string_data[326] = 8'h00;
        string_data[327] = "P";
        string_data[328] = "S";
        string_data[329] = "X";
        string_data[330] = " ";
        string_data[331] = "A";
        string_data[332] = "n";
        string_data[333] = "a";
        string_data[334] = "l";
        string_data[335] = "o";
        string_data[336] = "g";
        string_data[337] = 8'h00;
        string_data[338] = "S";
        string_data[339] = "N";
        string_data[340] = "E ";
        string_data[341] = "S";
        string_data[342] = " ";
        string_data[343] = "R";
        string_data[344] = "e";
        string_data[345] = "m";
        string_data[346] = "a";
        string_data[347] = "p";
        string_data[348] = 8'h00;
        string_data[349] = "5";
        string_data[350] = "5";
        string_data[351] = "H";
        string_data[352] = "z";
        string_data[353] = 8'h00;
        string_data[354] = "5";
        string_data[355] = "0";
        string_data[356] = "H";
        string_data[357] = "z";
        string_data[358] = 8'h00;
        string_data[359] = "5";
        string_data[360] = "7";
        string_data[361] = "H";
        string_data[362] = "z";
        string_data[363] = 8'h00;
        string_data[364] = "6";
        string_data[365] = "0";
        string_data[366] = "H";
        string_data[367] = "z";
        string_data[368] = 8'h00;
    end

    // Offsets de inicio de cada cadena
    initial begin
        string_offsets[0] = 0;    // "RGBS"
        string_offsets[1] = 5;    // "RGsB"
        string_offsets[2] = 10;    // "YPbPr"
        string_offsets[3] = 16;    // "Y/C NTSC"
        string_offsets[4] = 25;    // "Y/C PAL"
        string_offsets[5] = 33;    // "SC 0% RGBHV"
        string_offsets[6] = 45;    // "SC 25% RGBHV"
        string_offsets[7] = 58;    // "SC 50% RGBHV"
        string_offsets[8] = 71;    // "SC 75% RGBHV"
        string_offsets[9] = 84;    // "SC HQ2x RGBHV"
        string_offsets[10] = 98;    // "SNAC P1 -> Pocket P1"
        string_offsets[11] = 119;    // "SNAC P1 -> Pocket P2"
        string_offsets[12] = 140;    // "SNAC P1,P2 -> Pocket P1,P2"
        string_offsets[13] = 167;    // "SNAC P1,P2 -> Pocket P2,P1"
        string_offsets[14] = 194;    // "SNAC P1,P2 -> Pocket P3,P4"
        string_offsets[15] = 221;    // "SNAC P1-P4 -> Pocket P1-P4"
        string_offsets[16] = 248;    // "None"
        string_offsets[17] = 253;    // "DB15 Normal"
        string_offsets[18] = 265;    // "NES"
        string_offsets[19] = 269;    // "SNES"
        string_offsets[20] = 274;    // "PCE 2Btn"
        string_offsets[21] = 283;    // "PCE 6Btn"
        string_offsets[22] = 292;    // "PCE Multitap"
        string_offsets[23] = 337;    // 
        string_offsets[24] = 337;    //  
        string_offsets[25] = 305;    // "DB15 Fast"
        string_offsets[26] = 337;    //  
        string_offsets[27] = 338;    // SNES A,B<->X,Y - SNES with remapped buttons 
        string_offsets[28] = 337;    
        string_offsets[29] = 337;    
        string_offsets[30] = 337;    
        string_offsets[31] = 337;    
        string_offsets[32] = 337;    
        string_offsets[33] = 315;    // "PSX Digital"
        string_offsets[34] = 337;    
        string_offsets[35] = 327;    // "PSX Analog"
        string_offsets[36] = 349;    // "55Hz"
        string_offsets[37] = 354;    // "50Hz"
        string_offsets[38] = 359;    // "57Hz"
        string_offsets[39] = 364;    // "60Hz"
    end

    logic [7:0] current_char;
    logic [8:0] offset;
    logic [8:0] char_index;

    always_ff @(posedge clk) begin
        wr_en <= 0;

        case (state)
            IDLE: begin
                if (start) begin
                    offset <= string_offsets[string_index];
                    char_index <= 0;
                    state <= LOAD_OFFSET;
                end
            end

            LOAD_OFFSET: begin
                current_char <= string_data[offset];
                state <= READ_CHAR;
            end

            READ_CHAR: begin
                if (current_char == 8'h00) begin
                    state <= DONE;
                end else begin
                    wr_addr <= base_addr + char_index;
                    wr_data <= current_char;
                    wr_en   <= 1;
                    state   <= WRITE_CHAR;
                end
            end

            WRITE_CHAR: begin
                wr_en <= 0;
                state <= NEXT_CHAR;
            end

            NEXT_CHAR: begin
                char_index <= char_index + 1;
                offset     <= offset + 1;
                current_char <= string_data[offset + 1];
                state <= READ_CHAR;
            end

            DONE: begin
                state <= IDLE;
            end
        endcase
    end

    assign busy = (state != IDLE);

endmodule
