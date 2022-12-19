// Copyright (c) 2022 Sungkyunkwan University

module CC_TAG_COMPARATOR
(
	input	wire			clk,
	input	wire			rst_n,

	input	wire	[16:0]	tag_i,
	input	wire	[8:0]	index_i,
	input   wire	[2:0]	offset_i,
	output	wire	[16:0]	tag_delayed_o,
	output	wire	[8:0]	index_delayed_o,
	output	wire	[2:0]	offset_delayed_o,

	input	wire			hs_pulse_i,

	input	wire	[17:0]	rdata_tag_i,

	output	wire			hit_o,
	output	wire			miss_o
);

	reg		[16:0]	tag_delayed;
	reg		[8:0]	index_delayed;
	reg		[2:0]	offset_delayed;
	reg				hs_pulse_delayed;

	wire			tag_valid;
	wire			tag_data;
	wire			tag_match;

	always_ff @(posedge clk)
		if(!rst_n) begin
			tag_delayed			<= 17'd0;
			index_delayed		<= 9'd0;
			offset_delayed		<= 3'd0;
			hs_pulse_delayed 	<= 1'd0;
		end
		else begin 
			tag_delayed			<= tag_i;
			index_delayed		<= index_i;
			offset_delayed		<= offset_i;
			hs_pulse_delayed	<= hs_pulse_i;
		end

	assign  {tag_valid, tag_data} 	= rdata_tag_i;
	assign	tag_match				= tag_valid & (tag_delayed == tag_data);

	assign	tag_delayed_o			= tag_delayed;
	assign	index_delayed_o			= index_delayed;
	assign	offset_delayed_o		= offset_delayed;

	assign	hit_o					= hs_pulse_delayed & tag_match;
	assign	miss_o					= hs_pulse_delayed & !tag_match;

endmodule
