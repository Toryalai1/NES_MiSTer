// MMC 2 and 4 mappers. These can probably be consolidated.

// MMC2 mapper chip. PRG ROM: 128kB. Bank Size: 8kB. CHR ROM: 128kB
module MMC2(
	input clk,
	input ce,
	input reset,
	input [31:0] flags,
	input [15:0] prg_ain,
	output [21:0] prg_aout,
	input prg_read,
	input prg_write,          // Read / write signals
	input [7:0] prg_din,
	output prg_allow,         // Enable access to memory for the specified operation.
	input chr_read,
	input [13:0] chr_ain,
	output [21:0] chr_aout,
	output chr_allow,         // Allow write
	output vram_a10,          // Value for A10 address line
	output vram_ce            // True if the address should be routed to the internal 2kB VRAM.
);

// PRG ROM bank select ($A000-$AFFF)
// 7  bit  0
// ---- ----
// xxxx PPPP
//      ||||
//      ++++- Select 8 KB PRG ROM bank for CPU $8000-$9FFF
reg [3:0] prg_bank;

// CHR ROM $FD/0000 bank select ($B000-$BFFF)
// 7  bit  0
// ---- ----
// xxxC CCCC
//    | ||||
//    +-++++- Select 4 KB CHR ROM bank for PPU $0000-$0FFF
//            used when latch 0 = $FD
reg   [4:0] chr_bank_0a;

// CHR ROM $FE/0000 bank select ($C000-$CFFF)
// 7  bit  0
// ---- ----
// xxxC CCCC
//    | ||||
//    +-++++- Select 4 KB CHR ROM bank for PPU $0000-$0FFF
//            used when latch 0 = $FE
reg [4:0] chr_bank_0b;

// CHR ROM $FD/1000 bank select ($D000-$DFFF)
// 7  bit  0
// ---- ----
// xxxC CCCC
//    | ||||
//    +-++++- Select 4 KB CHR ROM bank for PPU $1000-$1FFF
//            used when latch 1 = $FD
reg [4:0] chr_bank_1a;

// CHR ROM $FE/1000 bank select ($E000-$EFFF)
// 7  bit  0
// ---- ----
// xxxC CCCC
//    | ||||
//    +-++++- Select 4 KB CHR ROM bank for PPU $1000-$1FFF
//            used when latch 1 = $FE
reg [4:0] chr_bank_1b; 

// Mirroring ($F000-$FFFF)
// 7  bit  0
// ---- ----
// xxxx xxxM
//         |
//         +- Select nametable mirroring (0: vertical; 1: horizontal)  
reg mirroring;

reg latch_0, latch_1;
	
// Update registers
always @(posedge clk) if (ce) begin
	if (prg_write && prg_ain[15]) begin
		case(prg_ain[14:12])
			2: prg_bank <= prg_din[3:0];     // $A000
			3: chr_bank_0a <= prg_din[4:0];  // $B000
			4: chr_bank_0b <= prg_din[4:0];  // $C000
			5: chr_bank_1a <= prg_din[4:0];  // $D000
			6: chr_bank_1b <= prg_din[4:0];  // $E000
			7: mirroring <=  prg_din[0];     // $F000
		endcase
	end
end

// PPU reads $0FD8: latch 0 is set to $FD for subsequent reads
// PPU reads $0FE8: latch 0 is set to $FE for subsequent reads
// PPU reads $1FD8 through $1FDF: latch 1 is set to $FD for subsequent reads
// PPU reads $1FE8 through $1FEF: latch 1 is set to $FE for subsequent reads
always @(posedge clk) if (ce && chr_read) begin
	latch_0 <= (chr_ain & 14'h3fff) == 14'h0fd8 ? 1'd0 : (chr_ain & 14'h3fff) == 14'h0fe8 ? 1'd1 : latch_0;
	latch_1 <= (chr_ain & 14'h3ff8) == 14'h1fd8 ? 1'd0 : (chr_ain & 14'h3ff8) == 14'h1fe8 ? 1'd1 : latch_1;
end

// The PRG bank to load. Each increment here is 8kb. So valid values are 0..15.
reg [3:0] prgsel;
always @* begin
	casez(prg_ain[14:13])
		2'b00:   prgsel = prg_bank;
		default: prgsel = {2'b11, prg_ain[14:13]};
	endcase
end

assign prg_aout = {5'b00_000, prgsel, prg_ain[12:0]};

// The CHR bank to load. Each increment here is 4kb. So valid values are 0..31.
reg [4:0] chrsel;
always @* begin
	casez({chr_ain[12], latch_0, latch_1})
		3'b00?: chrsel = chr_bank_0a;
		3'b01?: chrsel = chr_bank_0b;
		3'b1?0: chrsel = chr_bank_1a;
		3'b1?1: chrsel = chr_bank_1b;
	endcase
end

assign chr_aout = {5'b100_00, chrsel, chr_ain[11:0]};

// The a10 VRAM address line. (Used for mirroring)
assign vram_a10 = mirroring ? chr_ain[11] : chr_ain[10];
assign vram_ce = chr_ain[13];

assign prg_allow = prg_ain[15] && !prg_write;
assign chr_allow = flags[15];

endmodule

// MMC4 mapper chip. PRG ROM: 256kB. Bank Size: 16kB. CHR ROM: 128kB
module MMC4(
	input clk,
	input ce,
	input reset,
	input [31:0] flags,
	input [15:0] prg_ain,
	output [21:0] prg_aout,
	input prg_read,
	input prg_write,             // Read / write signals
	input [7:0] prg_din,
	output prg_allow,            // Enable access to memory for the specified operation.
	input chr_read,
	input [13:0] chr_ain,
	output [21:0] chr_aout,
	output chr_allow,            // Allow write
	output vram_a10,             // Value for A10 address line
	output vram_ce               // True if the address should be routed to the internal 2kB VRAM.
);

// PRG ROM bank select ($A000-$AFFF)
// 7  bit  0
// ---- ----
// xxxx PPPP
//      ||||
//      ++++- Select 16 KB PRG ROM bank for CPU $8000-$BFFF
reg [3:0] prg_bank;

// CHR ROM $FD/0000 bank select ($B000-$BFFF)
// 7  bit  0
// ---- ----
// xxxC CCCC
//    | ||||
//    +-++++- Select 4 KB CHR ROM bank for PPU $0000-$0FFF
//            used when latch 0 = $FD
reg   [4:0] chr_bank_0a;

// CHR ROM $FE/0000 bank select ($C000-$CFFF)
// 7  bit  0
// ---- ----
// xxxC CCCC
//    | ||||
//    +-++++- Select 4 KB CHR ROM bank for PPU $0000-$0FFF
//            used when latch 0 = $FE
reg [4:0] chr_bank_0b;

// CHR ROM $FD/1000 bank select ($D000-$DFFF)
// 7  bit  0
// ---- ----
// xxxC CCCC
//    | ||||
//    +-++++- Select 4 KB CHR ROM bank for PPU $1000-$1FFF
//            used when latch 1 = $FD
reg [4:0] chr_bank_1a;

// CHR ROM $FE/1000 bank select ($E000-$EFFF)
// 7  bit  0
// ---- ----
// xxxC CCCC
//    | ||||
//    +-++++- Select 4 KB CHR ROM bank for PPU $1000-$1FFF
//            used when latch 1 = $FE
reg [4:0] chr_bank_1b; 

// Mirroring ($F000-$FFFF)
// 7  bit  0
// ---- ----
// xxxx xxxM
//         |
//         +- Select nametable mirroring (0: vertical; 1: horizontal)  
reg mirroring;

reg latch_0, latch_1;

// Update registers
always @(posedge clk) if (ce) begin
	if (reset)
		prg_bank <= 4'b1110;	  
	else if (prg_write && prg_ain[15]) begin
		case(prg_ain[14:12])
			2: prg_bank <= prg_din[3:0];     // $A000
			3: chr_bank_0a <= prg_din[4:0];  // $B000
			4: chr_bank_0b <= prg_din[4:0];  // $C000
			5: chr_bank_1a <= prg_din[4:0];  // $D000
			6: chr_bank_1b <= prg_din[4:0];  // $E000
			7: mirroring <=  prg_din[0];     // $F000
		endcase
	end
end

// PPU reads $0FD8 through $0FDF: latch 0 is set to $FD for subsequent reads
// PPU reads $0FE8 through $0FEF: latch 0 is set to $FE for subsequent reads
// PPU reads $1FD8 through $1FDF: latch 1 is set to $FD for subsequent reads
// PPU reads $1FE8 through $1FEF: latch 1 is set to $FE for subsequent reads
always @(posedge clk) if (ce && chr_read) begin
	latch_0 <= (chr_ain & 14'h3ff8) == 14'h0fd8 ? 1'd0 : (chr_ain & 14'h3ff8) == 14'h0fe8 ? 1'd1 : latch_0;
	latch_1 <= (chr_ain & 14'h3ff8) == 14'h1fd8 ? 1'd0 : (chr_ain & 14'h3ff8) == 14'h1fe8 ? 1'd1 : latch_1;
end

// The PRG bank to load. Each increment here is 16kb. So valid values are 0..15.
reg [3:0] prgsel;
always @* begin
	casez(prg_ain[14])
		1'b0:    prgsel = prg_bank;
		default: prgsel = 4'b1111;
	endcase
end

wire [21:0] prg_aout_tmp = {4'b00_00, prgsel, prg_ain[13:0]};

// The CHR bank to load. Each increment here is 4kb. So valid values are 0..31.
reg [4:0] chrsel;
always @* begin
	casez({chr_ain[12], latch_0, latch_1})
		3'b00?: chrsel = chr_bank_0a;
		3'b01?: chrsel = chr_bank_0b;
		3'b1?0: chrsel = chr_bank_1a;
		3'b1?1: chrsel = chr_bank_1b;
	endcase
end

assign chr_aout = {5'b100_00, chrsel, chr_ain[11:0]};

// The a10 VRAM address line. (Used for mirroring)
assign vram_a10 = mirroring ? chr_ain[11] : chr_ain[10];
assign vram_ce = chr_ain[13];

assign chr_allow = flags[15];

wire prg_is_ram = prg_ain >= 'h6000 && prg_ain < 'h8000;
assign prg_allow = prg_ain[15] && !prg_write || prg_is_ram;
wire [21:0] prg_ram = {9'b11_1100_000, prg_ain[12:0]};
assign prg_aout = prg_is_ram ? prg_ram : prg_aout_tmp;

endmodule