// Copyright (c) 2021 Sungkyunkwan University
//
// Authors:
// - Jungrae Kim <dale40@skku.edu>

module DMAC_ENGINE
(
    input   wire                clk,
    input   wire                rst_n,  // _n means active low

    // configuration registers
    input   wire    [31:0]      src_addr_i,
    input   wire    [31:0]      dst_addr_i,
    input   wire    [15:0]      byte_len_i,
    input   wire                start_i,
    output  wire                done_o,

    // AMBA AXI interface (AW channel)
    output  wire    [3:0]       awid_o,
    output  wire    [31:0]      awaddr_o,
    output  wire    [3:0]       awlen_o,
    output  wire    [2:0]       awsize_o,
    output  wire    [1:0]       awburst_o,
    output  wire                awvalid_o,
    input   wire                awready_i,

    // AMBA AXI interface (W channel)
    output  wire    [3:0]       wid_o,
    output  wire    [31:0]      wdata_o,
    output  wire    [3:0]       wstrb_o,
    output  wire                wlast_o,
    output  wire                wvalid_o,
    input   wire                wready_i,

    // AMBA AXI interface (B channel)
    input   wire    [3:0]       bid_i,
    input   wire    [1:0]       bresp_i,
    input   wire                bvalid_i,
    output  wire                bready_o,

    // AMBA AXI interface (AR channel)
    output  wire    [3:0]       arid_o,
    output  wire    [31:0]      araddr_o,
    output  wire    [3:0]       arlen_o,
    output  wire    [2:0]       arsize_o,
    output  wire    [1:0]       arburst_o,
    output  wire                arvalid_o,
    input   wire                arready_i,

    // AMBA AXI interface (R channel)
    input   wire    [3:0]       rid_i,
    input   wire    [31:0]      rdata_i,
    input   wire    [1:0]       rresp_i,
    input   wire                rlast_i,
    input   wire                rvalid_i,
    output  wire                rready_o
);

    // mnemonics for state values
    localparam                  S_IDLE  = 3'd0,
                                S_RREQ  = 3'd1,
                                S_RDATA = 3'd2,
                                S_WREQ  = 3'd3,
                                S_WDATA = 3'd4;

    reg     [2:0]               state,      state_n;

    reg     [31:0]              src_addr,   src_addr_n;
    reg     [31:0]              dst_addr,   dst_addr_n;
    reg     [15:0]              cnt,        cnt_n;
    reg     [31:0]              data_buf,   data_buf_n;

    reg                         arvalid,
                                rready,
                                awvalid,
                                wvalid,
                                done;

    // it's desirable to code registers in a simple way
    always_ff @(posedge clk)
        if (!rst_n) begin
            state               <= S_IDLE;

            src_addr            <= 32'd0;
            dst_addr            <= 32'd0;
            cnt                 <= 16'd0;
            data_buf            <= 32'd0;
        end
        else begin
            state               <= state_n;

            src_addr            <= src_addr_n;
            dst_addr            <= dst_addr_n;
            cnt                 <= cnt_n;
            data_buf            <= data_buf_n;
        end


    // this block programs output values and next register values
    // based on states.
    always_comb
    begin
        state_n                 = state;

        src_addr_n              = src_addr;
        dst_addr_n              = dst_addr;
        cnt_n                   = cnt;
        data_buf_n              = data_buf;

        arvalid                 = 1'b0;
        rready                  = 1'b0;
        awvalid                 = 1'b0;
        wvalid                  = 1'b0;
        done                    = 1'b0;

        case (state)
            S_IDLE: begin
                done                    = 1'b1;
                if (start_i & byte_len_i!=16'd0) begin
                    src_addr_n              = src_addr_i;
                    dst_addr_n              = dst_addr_i;
                    cnt_n                   = byte_len_i;

                    state_n                 = S_RREQ;
                end
            end
            S_RREQ: begin
                arvalid                 = 1'b1;

                if (arready_i) begin
                    state_n                 = S_RDATA;
                    src_addr_n              = src_addr + 'd4;
                end
            end
            S_RDATA: begin
                rready                  = 1'b1;

                if (rvalid_i) begin
                    state_n                 = S_WREQ;
                    data_buf_n              = rdata_i;
                end
            end
            S_WREQ: begin
                awvalid                 = 1'b1;

                if (awready_i) begin
                    state_n                 = S_WDATA;
                    dst_addr_n              = dst_addr + 'd4;
                    cnt_n                   = cnt - 16'd4;
                end
            end
            S_WDATA: begin
                wvalid                  = 1'b1;

                if (wready_i) begin
                    if (cnt==16'd0) begin
                        state_n                 = S_IDLE;
                    end
                    else begin
                        state_n                 = S_RREQ;
                    end
                end
            end
        endcase
    end

    // Output assigments
    assign  done_o                  = done;

    assign  awid_o                  = 4'd0;
    assign  awaddr_o                = dst_addr;
    assign  awlen_o                 = 4'd0;     // 1-burst
    assign  awsize_o                = 3'b010;   // 4 bytes per transfer
    assign  awburst_o               = 2'b01;    // incremental
    assign  awvalid_o               = awvalid;

    assign  wid_o                   = 4'd0;
    assign  wdata_o                 = data_buf;
    assign  wstrb_o                 = 4'b1111;  // all bytes within 4 byte are valid
    assign  wlast_o                 = 1'b1;
    assign  wvalid_o                = wvalid;

    assign  bready_o                = 1'b1;

    assign  arvalid_o               = arvalid;
    assign  araddr_o                = src_addr;
    assign  arid_o                  = 4'd0;
    assign  arlen_o                 = 4'd0;     // 1-burst
    assign  arsize_o                = 3'b010;   // 4 bytes per transfer
    assign  arburst_o               = 2'b01;    // incremental
    assign  arvalid_o               = arvalid;

    assign  rready_o                = rready;

endmodule
