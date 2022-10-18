`define     IP_VER      32'h000
`define     SRC_ADDR    32'h100
`define     DST_ADDR    32'h104
`define     LEN_ADDR    32'h108
`define     STAT_ADDR   32'h110
`define     START_ADDR  32'h10c

`define 	TIMEOUT_CYCLE 	99999999
module DMAC_TOP_TB ();

    reg                     clk;
    reg                     rst_n;

    // clock generation
    initial begin
        clk                     = 1'b0;

        forever #10 clk         = !clk;
    end

    // reset generation
    initial begin
        rst_n                   = 1'b0;     // active at time 0

        repeat (3) @(posedge clk);          // after 3 cycles,
        rst_n                   = 1'b1;     // release the reset
    end

    // enable waveform dump
    initial begin
        $dumpvars(0, u_DUT);
        $dumpfile("dump.vcd");
    end
	// timeout
	initial begin
		#`TIMEOUT_CYCLE $display("Timeout!");
		$finish;
	end

    APB                         apb_if  (.clk(clk));

    AXI_AW_CH                   aw_ch   (.clk(clk));
    AXI_W_CH                    w_ch    (.clk(clk));
    AXI_B_CH                    b_ch    (.clk(clk));
    AXI_AR_CH                   ar_ch   (.clk(clk));
    AXI_R_CH                    r_ch    (.clk(clk));

    task test_init();
        int data;
        apb_if.init();

        @(posedge rst_n);                   // wait for a release of the reset
        repeat (10) @(posedge clk);         // wait another 10 cycles

        apb_if.read(`IP_VER, data);
        $display("---------------------------------------------------");
        $display("IP version: %x", data);
        $display("---------------------------------------------------");

        $display("---------------------------------------------------");
        $display("Reset value test");
        $display("---------------------------------------------------");
        apb_if.read(`SRC_ADDR, data);
        if (data===0)
            $display("DMA_SRC(pass): %x", data);
        else begin
            $display("DMA_SRC(fail): %x", data);
            @(posedge clk);
            $finish;
        end
        apb_if.read(`DST_ADDR, data);
        if (data===0)
            $display("DMA_DST(pass): %x", data);
        else begin
            $display("DMA_DST(fail): %x", data);
            @(posedge clk);
            $finish;
        end
        apb_if.read(`LEN_ADDR, data);
        if (data===0)
            $display("DMA_LEN(pass): %x", data);
        else begin
            $display("DMA_LEN(fail): %x", data);
            @(posedge clk);
            $finish;
        end
        apb_if.read(`STAT_ADDR, data);
        if (data===1)
            $display("DMA_STATUS(pass): %x", data);
        else begin
            $display("DMA_STATUS(fail): %x", data);
            @(posedge clk);
            $finish;
        end
    endtask

    task test_dma(input int src, input int dst, input int len);
        int data;
        int word;
        realtime elapsed_time;

        $display("---------------------------------------------------");
        $display("Load data to memory");
        $display("---------------------------------------------------");
        for (int i=src; i<(src+len); i=i+4) begin
            word = $random;
            u_mem.write_word(i, word);
        end

        $display("---------------------------------------------------");
        $display("Configuration test");
        $display("---------------------------------------------------");
        apb_if.write(`SRC_ADDR, src);
        apb_if.read(`SRC_ADDR, data);
        if (data===src)
            $display("DMA_SRC(pass): %x", data);
        else begin
            $display("DMA_SRC(fail): %x", data);
            @(posedge clk);
            $finish;
        end
        apb_if.write(`DST_ADDR, dst);
        apb_if.read(`DST_ADDR, data);
        if (data===dst)
            $display("DMA_DST(pass): %x", data);
        else begin
            $display("DMA_DST(fail): %x", data);
            @(posedge clk);
            $finish;
        end
        apb_if.write(`LEN_ADDR, len);
        apb_if.read(`LEN_ADDR, data);
        if (data===len)
            $display("DMA_LEN(pass): %x", data);
        else begin
            $display("DMA_LEN(fail): %x", data);
            @(posedge clk);
            $finish;
        end

        $display("---------------------------------------------------");
        $display("DMA start");
        $display("---------------------------------------------------");
        apb_if.write(`START_ADDR, 32'h1);
        elapsed_time = $realtime;

        $display("---------------------------------------------------");
        $display("Wait for a DMA completion");
        $display("---------------------------------------------------");
        data = 0;
        while (data!=1) begin
            apb_if.read(`STAT_ADDR, data);
            repeat (100) @(posedge clk);
        end
        @(posedge clk);
        elapsed_time = $realtime - elapsed_time;
        $timeformat(-9, 0, " ns", 10);
        $display("Elapsed time for DMA: %t", elapsed_time);

        $display("---------------------------------------------------");
        $display("DMA completed");
        $display("---------------------------------------------------");

        repeat (len) @(posedge clk);    // to make sure data is written

        $display("---------------------------------------------------");
        $display("verify data");
        $display("---------------------------------------------------");
        for (int i=0; i<len; i=i+4) begin
            logic [31:0]        src_word;
            logic [31:0]        dst_word;
            src_word            = u_mem.read_word(src+i);
            dst_word            = u_mem.read_word(dst+i);
            if (src_word!==dst_word) begin
                $display("Mismatch! (src:%x @%x, dst:%x @%x", src_word, src+i, dst_word, dst+i);
            end
        end
    endtask

    int             src,
                    dst,
                    len;

    // main
    initial begin
        test_init();

        src = 'h0000_1000;
        dst = 'h0000_2000;
        len = 'h0100;
        $display("===================================================");
        $display("= 1st trial");
        $display("= Copying %x bytes from %x to %x", len, src, dst);
        $display("===================================================");
        test_dma(src, dst, len);

        src = 'h1234_1234;
        dst = 'h5678_5678;
        len = 'h0F00;
        $display("===================================================");
        $display("= 2nd trial (long transfer)");
        $display("= Copying %x bytes from %x to %x", len, src, dst);
        $display("===================================================");
        test_dma(src, dst, len);

        for (int i=1; i<20; i=i+1) begin
            src = 'h0001_0000 + i*'h1000;
            dst = 'h0002_0000 + i*'h1000;
            len = i*4;
            $display("===================================================");
            $display("= %2dth trial", i+2);
            $display("= Copying %x bytes from %x to %x", len, src, dst);
            $display("===================================================");
            test_dma(src, dst, len);
        end
        $finish;
    end


    AXI_SLAVE   u_mem (
        .clk                    (clk),
        .rst_n                  (rst_n),

        .aw_ch                  (aw_ch),
        .w_ch                   (w_ch),
        .b_ch                   (b_ch),
        .ar_ch                  (ar_ch),
        .r_ch                   (r_ch)
    );

    DMAC_TOP  u_DUT (
        .clk                    (clk),
        .rst_n                  (rst_n),

        // APB interface
        .psel_i                 (apb_if.psel),
        .penable_i              (apb_if.penable),
        .paddr_i                (apb_if.paddr[11:0]),
        .pwrite_i               (apb_if.pwrite),
        .pwdata_i               (apb_if.pwdata),
        .pready_o               (apb_if.pready),
        .prdata_o               (apb_if.prdata),
        .pslverr_o              (apb_if.pslverr),

        // AXI AW channel
        .awid_o                 (aw_ch.awid),
        .awaddr_o               (aw_ch.awaddr),
        .awlen_o                (aw_ch.awlen),
        .awsize_o               (aw_ch.awsize),
        .awburst_o              (aw_ch.awburst),
        .awvalid_o              (aw_ch.awvalid),
        .awready_i              (aw_ch.awready),

        // AXI W channel
        .wid_o                  (w_ch.wid),
        .wdata_o                (w_ch.wdata),
        .wstrb_o                (w_ch.wstrb),
        .wlast_o                (w_ch.wlast),
        .wvalid_o               (w_ch.wvalid),
        .wready_i               (w_ch.wready),

        // AXI B channel
        .bid_i                  (b_ch.bid),
        .bresp_i                (b_ch.bresp),
        .bvalid_i               (b_ch.bvalid),
        .bready_o               (b_ch.bready),

        // AXI AR channel
        .arid_o                 (ar_ch.arid),
        .araddr_o               (ar_ch.araddr),
        .arlen_o                (ar_ch.arlen),
        .arsize_o               (ar_ch.arsize),
        .arburst_o              (ar_ch.arburst),
        .arvalid_o              (ar_ch.arvalid),
        .arready_i              (ar_ch.arready),

        // AXI R channel
        .rid_i                  (r_ch.rid),
        .rdata_i                (r_ch.rdata),
        .rresp_i                (r_ch.rresp),
        .rlast_i                (r_ch.rlast),
        .rvalid_i               (r_ch.rvalid),
        .rready_o               (r_ch.rready)
    );

    // Functional coverage
    covergroup apb_cov;
        DIR: coverpoint apb_if.pwrite {
            bins READ           = {0};
            bins WRITE          = {1};
        }
        ADDR: coverpoint apb_if.paddr {
            bins DMA_VER        = {'h0};
            ignore_bins RSVD1   = {['h4:'hFC]};
            bins DMA_SRC        = {'h100};
            bins DMA_DST        = {'h104};
            bins DMA_LEN        = {'h108};
            bins DMA_CMD        = {'h10c};
            bins DMA_STATUS     = {'h110};
            ignore_bins RSVD2   = {['h114:$]};  // to maximum value
        }
        WDATA: coverpoint apb_if.pwdata {
            bins ZERO           = {'h0};
            bins ONE            = {'h1};
            bins OTHERS         = {['h2: $]};   // to maximum value
        }
        WDATA2: coverpoint apb_if.pwdata[1:0] {
            bins MOD4_ZERO      = {'h0};
            bins MOD4_ONE       = {'h1};
            bins MOD4_TWO       = {'h2};
            bins MOD4_THREE     = {'h3};
        }
        SFR_RW: cross ADDR, DIR {
            bins DMA_VER_RD = binsof(ADDR.DMA_VER) && binsof(DIR.READ);
            ignore_bins DMA_VER_WR = binsof(ADDR.DMA_VER) && binsof(DIR.WRITE);
            bins DMA_SRC_RD = binsof(ADDR.DMA_SRC) && binsof(DIR.READ);
            bins DMA_SRC_WR = binsof(ADDR.DMA_SRC) && binsof(DIR.WRITE);
            bins DMA_DST_RD = binsof(ADDR.DMA_DST) && binsof(DIR.READ);
            bins DMA_DST_WR = binsof(ADDR.DMA_DST) && binsof(DIR.WRITE);
            bins DMA_LEN_RD = binsof(ADDR.DMA_LEN) && binsof(DIR.READ);
            bins DMA_LEN_WR = binsof(ADDR.DMA_LEN) && binsof(DIR.WRITE);
            ignore_bins DMA_CMD_RD = binsof(ADDR.DMA_CMD) && binsof(DIR.READ);
            bins DMA_CMD_WR = binsof(ADDR.DMA_CMD) && binsof(DIR.WRITE);
            bins DMA_STATUS_RD = binsof(ADDR.DMA_STATUS) && binsof(DIR.READ);
            ignore_bins DMA_STATUS_WR = binsof(ADDR.DMA_STATUS) && binsof(DIR.WRITE);
        }
    endgroup

    apb_cov apb_cov_inst        = new();

    always @(posedge clk)
        if (rst_n & apb_if.psel & apb_if.penable)
            apb_cov_inst.sample();

    // Functional coverage
    covergroup aw_cov;
        AWLEN_CP: coverpoint aw_ch.awlen
        {
            bins LEN01 = {0};
            bins LEN02 = {1};
            bins LEN03 = {2};
            bins LEN04 = {3};
            bins LEN05 = {4};
            bins LEN06 = {5};
            bins LEN07 = {6};
            bins LEN08 = {7};
            bins LEN09 = {8};
            bins LEN10 = {9};
            bins LEN11 = {10};
            bins LEN12 = {11};
            bins LEN13 = {12};
            bins LEN14 = {13};
            bins LEN15 = {14};
            bins LEN16 = {15};
        }
    endgroup

    aw_cov aw_cov_inst          = new();

    always @(posedge clk)
        if (rst_n & aw_ch.awvalid & aw_ch.awready)
            aw_cov_inst.sample();
endmodule
