module CC_TOP
(
    input   wire        clk,
    input   wire        rst_n,

    // AMBA APB interface
    input   wire                psel_i,
    input   wire                penable_i,
    input   wire    [11:0]      paddr_i,
    input   wire                pwrite_i,
    input   wire    [31:0]      pwdata_i,
    output  reg                 pready_o,
    output  reg     [31:0]      prdata_o,
    output  reg                 pslverr_o,

    // AMBA AXI interface between INCT and CC (AR channel)
    input   wire    [3:0]       inct_arid_i,
    input   wire    [31:0]      inct_araddr_i,
    input   wire    [3:0]       inct_arlen_i,
    input   wire    [2:0]       inct_arsize_i,
    input   wire    [1:0]       inct_arburst_i,
    input   wire                inct_arvalid_i,
    output  wire                inct_arready_o,
    
    // AMBA AXI interface between INCT and CC  (R channel)
    output  wire    [3:0]       inct_rid_o,
    output  wire    [63:0]      inct_rdata_o,
    output  wire    [1:0]       inct_rresp_o,
    output  wire                inct_rlast_o,
    output  wire                inct_rvalid_o,
    input   wire                inct_rready_i,

    // AMBA AXI interface between memory and CC (AR channel)
    output  wire    [3:0]       mem_arid_o,
    output  wire    [31:0]      mem_araddr_o,
    output  wire    [3:0]       mem_arlen_o,
    output  wire    [2:0]       mem_arsize_o,
    output  wire    [1:0]       mem_arburst_o,
    output  wire                mem_arvalid_o,
    input   wire                mem_arready_i,

    // AMBA AXI interface between memory and CC  (R channel)
    input   wire    [3:0]       mem_rid_i,
    input   wire    [63:0]      mem_rdata_i,
    input   wire    [1:0]       mem_rresp_i,
    input   wire                mem_rlast_i,
    input   wire                mem_rvalid_i,
    output  wire                mem_rready_o,    

    // SRAM read port interface
    output  wire                rden_o,
    output  wire    [8:0]       raddr_o,
    input   wire    [17:0]      rdata_tag_i,
    input   wire    [511:0]     rdata_data_i,

    // SRAM write port interface
    output  wire                wren_o,
    output  wire    [8:0]       waddr_o,
    output  wire    [17:0]      wdata_tag_o,
    output  wire    [511:0]     wdata_data_o    
);

    localparam      ADDR_FIFO_DEPTH     =   2;
    localparam      REQ_FIFO_DEPTH      =   2;

    wire    [28:0]  mem_araddr;

    wire    [16:0]  tag,    tag_delayed;
    wire    [8:0]   index,  index_delayed;
    wire    [2:0]   offset, offset_delayed;

    wire            hs_pulse;
    wire            hit;
    wire            miss;

    wire            miss_req_fifo_afull;
    wire            miss_req_fifo_empty;
    wire            miss_req_fifo_rden;

    wire            miss_addr_fifo_afull;
    wire            miss_addr_fifo_rden;
    wire    [28:0]  miss_addr_fifo_rdata;

    wire            hit_flag_fifo_afull;

    wire            hit_data_fifo_afull;

    CC_CFG u_cfg(
        .clk            (clk),
        .rst_n          (rst_n),
        .psel_i         (psel_i),
        .penable_i      (penable_i),
        .paddr_i        (paddr_i),
        .pwrite_i       (pwrite_i),
        .pwdata_i       (pwdata_i),
        .pready_o       (pready_o),
        .prdata_o       (prdata_o),
        .pslverr_o      (pslverr_o)
    );

    CC_DECODER u_decoder(
        .inct_araddr_i          (inct_araddr_i[31:3]),
        .inct_arvalid_i         (inct_arvalid_i),
        .inct_arready_o         (inct_arready_o),
        .miss_addr_fifo_afull_i (miss_addr_fifo_afull),
        .miss_req_fifo_afull_i  (miss_req_fifo_afull),
        .hit_flag_fifo_afull_i  (hit_flag_fifo_afull), 
        .hit_data_fifo_afull_i  (hit_data_fifo_afull), 
        .tag_o                  (tag),
        .index_o                (index),
        .offset_o               (offset),
        .hs_pulse_o             (hs_pulse)
    );

    CC_TAG_COMPARATOR u_tag_comparator(
        .clk                    (clk),
        .rst_n                  (rst_n),
        .tag_i                  (tag),
        .index_i                (index),
        .offset_i               (offset),
        .tag_delayed_o          (tag_delayed),
        .index_delayed_o        (index_delayed),
        .offset_delayed_o       (offset_delayed),
        .hs_pulse_i             (hs_pulse),
        .rdata_tag_i            (rdata_tag_i),
        .hit_o                  (hit),
        .miss_o                 (miss)
    );

    CC_FIFO #(
        .FIFO_DEPTH(REQ_FIFO_DEPTH), 
        .DATA_WIDTH(29), 
        .AFULL_THRESHOLD(REQ_FIFO_DEPTH - 1)
    ) u_miss_req_fifo(
        .clk                    (clk),
        .rst_n                  (rst_n),
        .full_o                 (),
        .afull_o                (miss_req_fifo_afull),
        .wren_i                 (miss),
        .wdata_i                ({tag_delayed, index_delayed, offset_delayed}),
        .empty_o                (miss_req_fifo_empty),
        .aempty_o               (),
        .rden_i                 (miss_req_fifo_rden),
        .rdata_o                (mem_araddr)
    );

    CC_FIFO #(
        .FIFO_DEPTH(ADDR_FIFO_DEPTH), 
        .DATA_WIDTH(29), 
        .AFULL_THRESHOLD(ADDR_FIFO_DEPTH - 1)
    ) u_miss_addr_fifo(
        .clk                    (clk),
        .rst_n                  (rst_n),
        .full_o                 (),
        .afull_o                (miss_addr_fifo_afull),
        .wren_i                 (miss),
        .wdata_i                ({tag_delayed, index_delayed, offset_delayed}),
        .empty_o                (miss_addr_fifo_empty),
        .aempty_o               (),
        .rden_i                 (miss_addr_fifo_rden),
        .rdata_o                (miss_addr_fifo_rdata)
    );

    CC_DATA_REORDER_UNIT    u_data_reorder_unit(
        .clk                        (clk),  
        .rst_n                      (rst_n),
        .mem_rdata_i                (mem_rdata_i),
        .mem_rlast_i                (mem_rlast_i),
        .mem_rvalid_i               (mem_rvalid_i),
        .mem_rready_o               (mem_rready_o),
        .hit_flag_fifo_afull_o      (hit_flag_fifo_afull),
        .hit_flag_fifo_wren_i       (hit | miss),
        .hit_flag_fifo_wdata_i      (hit),
        .hit_data_fifo_afull_o      (hit_data_fifo_afull),
        .hit_data_fifo_wren_i       (hit),
        .hit_data_fifo_wdata_i      ({offset_delayed,rdata_data_i}),
        .inct_rdata_o               (inct_rdata_o),
        .inct_rlast_o               (inct_rlast_o),
        .inct_rvalid_o              (inct_rvalid_o),
        .inct_rready_i              (inct_rready_i)
    );

    CC_DATA_FILL_UNIT       u_data_fill_unit(
        .clk                        (clk),
        .rst_n                      (rst_n),
        .mem_rdata_i                (mem_rdata_i),
        .mem_rlast_i                (mem_rlast_i),
        .mem_rvalid_i               (mem_rvalid_i),
        .mem_rready_i               (mem_rready_o),
        .miss_addr_fifo_empty_i     (miss_addr_fifo_empty),
        .miss_addr_fifo_rdata_i     (miss_addr_fifo_rdata),
        .miss_addr_fifo_rden_o      (miss_addr_fifo_rden),
        .wren_o                     (wren_o),
        .waddr_o                    (waddr_o),
        .wdata_tag_o                (wdata_tag_o),    
        .wdata_data_o               (wdata_data_o)
    );

    assign mem_arid_o           = inct_arid_i;
    assign mem_araddr_o         = {mem_araddr,3'd0};
    assign mem_arlen_o          = inct_arlen_i;
    assign mem_arsize_o         = inct_arsize_i;
    assign mem_arburst_o        = inct_arburst_i;
    assign mem_arvalid_o        = !miss_req_fifo_empty;
    assign miss_req_fifo_rden   = mem_arvalid_o & mem_arready_i;
    assign rden_o               = hs_pulse;
    assign raddr_o              = index;

endmodule
