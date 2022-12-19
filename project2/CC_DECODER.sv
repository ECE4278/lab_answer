// Copyright (c) 2022 Sungkyunkwan University

module CC_DECODER
(
	input	wire	[28:0]	inct_araddr_i,
	input	wire			inct_arvalid_i,
	output	wire			inct_arready_o,

	input	wire			miss_addr_fifo_afull_i,
	input	wire			miss_req_fifo_afull_i,
	input	wire			hit_flag_fifo_afull_i,
	input	wire			hit_data_fifo_afull_i,

	// We will only use 3 upper bits of offset
	output	wire	[16:0]	tag_o,
	output	wire	[8:0]	index_o,
	output	wire	[2:0]	offset_o, 
	
	output	wire			hs_pulse_o
);

	assign inct_arready_o				= ~|{miss_addr_fifo_afull_i, 
											miss_req_fifo_afull_i,
											hit_flag_fifo_afull_i, 
											hit_data_fifo_afull_i};

	assign {tag_o, index_o, offset_o} 	= inct_araddr_i;
	assign	hs_pulse_o					= inct_arvalid_i & inct_arready_o;

endmodule
