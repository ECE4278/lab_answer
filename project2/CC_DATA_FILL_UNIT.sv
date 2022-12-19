// Copyright (c) 2022 Sungkyunkwan University

module CC_DATA_FILL_UNIT
(
    input   wire            clk,
    input   wire            rst_n,
	
    // AMBA AXI interface between MEM and CC (R channel)
    // No rready in this interface
    input   wire    [63:0]  mem_rdata_i,
    input   wire            mem_rlast_i,
    input   wire            mem_rvalid_i,
    input   wire            mem_rready_i,

    // Miss Addr FIFO read interface 
    input   wire            miss_addr_fifo_empty_i,
    input   wire    [28:0]  miss_addr_fifo_rdata_i,
    output  wire            miss_addr_fifo_rden_o,

    // SRAM write port interface
    output  wire                wren_o,
    output  wire    [8:0]       waddr_o,
    output  wire    [17:0]      wdata_tag_o,
    output  wire    [511:0]     wdata_data_o   
);

    reg         wren;
    reg [511:0] buffer;
    reg [2:0]   counter;

    wire [16:0] tag;
    wire [8:0]  index;
    wire [2:0]  offset;
    wire [8:0]  wrptr;
    wire        mem_hs;

    always_ff @(posedge clk)
        if(!rst_n) begin 
            buffer  <= 512'd0;
            counter <= 3'd0;
            wren    <= 1'd0;
        end
        else begin
            wren                    <= mem_hs & mem_rlast_i;                 
            buffer[wrptr +: 7'd64]  <= mem_rdata_i;
            if(mem_hs) begin
                counter <= counter + 3'd1;
            end
        end

    assign  {tag, index, offset}    = miss_addr_fifo_rdata_i;
    assign  wrptr                   = {counter + offset, 6'd0};
    assign  mem_hs                  = mem_rvalid_i & mem_rready_i;

    assign  miss_addr_fifo_rden_o   = !miss_addr_fifo_empty_i & wren;

    assign  wren_o                  = wren;
    assign  waddr_o                 = index;
    assign  wdata_tag_o             = {1'b1, tag};
    assign  wdata_data_o            = buffer;

endmodule