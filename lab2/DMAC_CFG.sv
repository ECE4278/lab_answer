// Copyright (c) 2021 Sungkyunkwan University
//
// Authors:
// - Jungrae Kim <dale40@skku.edu>

module DMAC_CFG
(
    input   wire                clk,
    input   wire                rst_n,  // _n means active low

    // AMBA APB interface
    input   wire                psel_i,
    input   wire                penable_i,
    input   wire    [11:0]      paddr_i,
    input   wire                pwrite_i,
    input   wire    [31:0]      pwdata_i,
    output  reg                 pready_o,
    output  reg     [31:0]      prdata_o,
    output  reg                 pslverr_o,

    // configuration registers
    output  reg     [31:0]      src_addr_o,
    output  reg     [31:0]      dst_addr_o,
    output  reg     [15:0]      byte_len_o,
    output  wire                start_o,
    input   wire                done_i
);

    // Configuration register to read/write
    reg     [31:0]              src_addr;
    reg     [31:0]              dst_addr;
    reg     [15:0]              byte_len;

    //----------------------------------------------------------
    // Write
    //----------------------------------------------------------
    // an APB write occurs when PSEL & PENABLE & PWRITE
    // clk     : __--__--__--__--__--__--__--__--__--__--
    // psel    : ___--------_____________________________
    // penable : _______----_____________________________
    // pwrite  : ___--------_____________________________
    // wren    : _______----_____________________________
    //
    // DMA start command must be asserted when APB writes 1 to the DMA_CMD
    // register
    // clk     : __--__--__--__--__--__--__--__--__--__--
    // psel    : ___--------_____________________________
    // penable : _______----_____________________________
    // pwrite  : ___--------_____________________________
    // paddr   :    |DMA_CMD|
    // pwdata  :    |   1   |
    // start   : _______----_____________________________

    wire    wren                = psel_i & penable_i & pwrite_i;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            src_addr            <= 32'd0;
            dst_addr            <= 32'd0;
            byte_len            <= 16'd0;
        end
        else if (wren) begin
            case (paddr_i)
                'h100: src_addr         <= pwdata_i[31:0];
                'h104: dst_addr         <= pwdata_i[31:0];
                'h108: byte_len         <= pwdata_i[15:0];
            endcase
        end
    end
    wire    start               = wren & (paddr_i=='h10C) & pwdata_i[0];

    //----------------------------------------------------------
    // READ
    //----------------------------------------------------------
    // an APB read occurs when PSEL & PENABLE & !PWRITE
    // To make read data a direct output from register,
    // this code shall buffer the muxed read data into a register
    // in the SETUP cycle (PSEL & !PENABLE)
    // clk        : __--__--__--__--__--__--__--__--__--__--
    // psel       : ___--------_____________________________
    // penable    : _______----_____________________________
    // pwrite     : ________________________________________
    // reg update : ___----_________________________________
    // prdata     :        |DATA

    reg     [31:0]              rdata;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rdata               <= 32'd0;
        end
        else if (psel_i & !penable_i & !pwrite_i) begin // in the setup cycle in the APB state diagram
            case (paddr_i)
                'h0:   rdata            <= 32'h0001_0101;
                'h100: rdata            <= src_addr;
                'h104: rdata            <= dst_addr;
                'h108: rdata            <= {16'd0, byte_len};
                'h110: rdata            <= {31'd0, done_i};
                default: rdata          <= 32'd0;
            endcase
        end
    end

    // output assignments
    assign  pready_o            = 1'b1;
    assign  prdata_o            = rdata;
    assign  pslverr_o           = 1'b0;

    assign  src_addr_o          = src_addr;
    assign  dst_addr_o          = dst_addr;
    assign  byte_len_o          = byte_len;
    assign  start_o             = start;

endmodule
