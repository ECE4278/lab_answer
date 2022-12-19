// Copyright (c) 2022 Sungkyunkwan University

module CC_SERIALIZER
(
	input	wire			clk,
	input	wire			rst_n,

	input	wire			fifo_empty_i,
	input	wire			fifo_aempty_i,
	input	wire 	[514:0]	fifo_rdata_i,
	output	wire			fifo_rden_o,

    output  wire    [63:0]	rdata_o,
    output  wire            rlast_o,
    output  wire            rvalid_o,
    input   wire            rready_i
);

	wire	[2:0]	offset;
	wire	[8:0]	rdptr;
	reg		[2:0]	counter;

	always_ff @(posedge clk)
		if(!rst_n) begin
			counter <= 3'd0;
		end
		else if(!fifo_empty_i & rready_i) begin
			counter <= counter + 3'd1;
		end

	assign	offset		=	fifo_rdata_i[514:512];
	assign	rdptr		=	{counter + offset, 6'd0};

	assign	fifo_rden_o	=	(counter == 3'd7);
	assign	rdata_o		=	fifo_rdata_i[rdptr +: 7'd64];
	assign	rlast_o		=	(counter == 3'd7);
	assign	rvalid_o	=	!fifo_empty_i;

endmodule
