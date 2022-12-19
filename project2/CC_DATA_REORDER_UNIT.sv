// Copyright (c) 2022 Sungkyunkwan University

module CC_DATA_REORDER_UNIT
(
    input   wire            clk,
    input   wire            rst_n,
	
    // AMBA AXI interface between MEM and CC (R channel)
    input   wire    [63:0]  mem_rdata_i,
    input   wire            mem_rlast_i,
    input   wire            mem_rvalid_i,
    output  wire            mem_rready_o,    

    // Hit Flag FIFO write interface
    output  wire            hit_flag_fifo_afull_o,
    input   wire            hit_flag_fifo_wren_i,
    input   wire            hit_flag_fifo_wdata_i,

    // Hit data FIFO write interface
    output  wire            hit_data_fifo_afull_o,
    input   wire            hit_data_fifo_wren_i,
    input   wire    [514:0] hit_data_fifo_wdata_i,

	// AMBA AXI interface between INCT and CC (R channel)
    output  wire    [63:0]  inct_rdata_o,
    output  wire            inct_rlast_o,
    output  wire            inct_rvalid_o,
    input   wire            inct_rready_i
);

    localparam     FLAG_FIFO_DEPTH     =   2;
    localparam     DATA_FIFO_DEPTH     =   2;

    reg      [63:0] inct_rdata;
    reg             inct_rlast;
    reg             inct_rvalid;
    reg             hit_rready;
    reg             mem_rready;

    wire            hit_data_fifo_empty;
    wire    [514:0] hit_data_fifo_rdata;
    wire            hit_data_fifo_rden;

    wire            hit_flag_fifo_empty;
    wire            hit_flag_fifo_rdata;
    wire            hit_flag_fifo_rden;

    wire     [63:0] hit_rdata;
    wire            hit_rvalid;
    wire            hit_rlast;

    always_comb begin 
        inct_rdata  =   64'd0;
        inct_rlast  =   1'b0;
        inct_rvalid =   1'b0;
        hit_rready  =   1'b0;
        mem_rready  =   1'b0;
        if(!hit_flag_fifo_empty) begin
            inct_rdata  = (hit_flag_fifo_rdata) ? hit_rdata  : mem_rdata_i;
            inct_rvalid = (hit_flag_fifo_rdata) ? hit_rvalid : mem_rvalid_i;
            inct_rlast  = (hit_flag_fifo_rdata) ? hit_rlast  : mem_rlast_i;
            hit_rready  = (hit_flag_fifo_rdata) ? inct_rready_i : 1'b0;
            mem_rready  = (hit_flag_fifo_rdata) ? 1'b0 : inct_rready_i;
        end
    end

    CC_FIFO #(
        .FIFO_DEPTH(FLAG_FIFO_DEPTH), 
        .DATA_WIDTH(1), 
        .AFULL_THRESHOLD(FLAG_FIFO_DEPTH - 1)
    ) u_hit_flag_fifo(
        .clk            (clk),
        .rst_n          (rst_n),
        .full_o         (),
        .afull_o        (hit_flag_fifo_afull_o),
        .wren_i         (hit_flag_fifo_wren_i), 
        .wdata_i        (hit_flag_fifo_wdata_i),
        .empty_o        (hit_flag_fifo_empty),
        .aempty_o       (),
        .rden_i         (hit_flag_fifo_rden),
        .rdata_o        (hit_flag_fifo_rdata)
    );

    CC_FIFO #(
        .FIFO_DEPTH(DATA_FIFO_DEPTH), 
        .DATA_WIDTH(515), 
        .AFULL_THRESHOLD(DATA_FIFO_DEPTH - 1)
    ) u_hit_data_fifo(
        .clk            (clk),
        .rst_n          (rst_n),
        .full_o         (),
        .afull_o        (hit_data_fifo_afull_o),
        .wren_i         (hit_data_fifo_wren_i),
        .wdata_i        (hit_data_fifo_wdata_i),
        .empty_o        (hit_data_fifo_empty),
        .aempty_o       (),
        .rden_i         (hit_data_fifo_rden),
        .rdata_o        (hit_data_fifo_rdata)
    );

    CC_SERIALIZER   u_serializer(
        .clk            (clk),
        .rst_n          (rst_n),
        .fifo_empty_i   (hit_data_fifo_empty),
        .fifo_aempty_i  (),
        .fifo_rdata_i   (hit_data_fifo_rdata),
        .fifo_rden_o    (hit_data_fifo_rden),
        .rdata_o        (hit_rdata),
        .rlast_o        (hit_rlast),
        .rvalid_o       (hit_rvalid),
        .rready_i       (hit_rready)
    );

    assign  hit_flag_fifo_rden  = inct_rlast;

    assign  mem_rready_o        = mem_rready;
    assign  inct_rdata_o        = inct_rdata;
    assign  inct_rlast_o        = inct_rlast;
    assign  inct_rvalid_o       = inct_rvalid;

endmodule