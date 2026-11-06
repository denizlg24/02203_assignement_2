`timescale 1ns/1ns

module tb_sobel_loader;

    localparam int BUF_AW     = 15;
    localparam int IMG_WIDTH  = 88;
    localparam int IMG_HEIGHT = 288;
    localparam int BUF_DEPTH  = IMG_WIDTH * IMG_HEIGHT;
    localparam int FRAMES     = 2;
    localparam int MAX_REPORT = 10;

    logic clk = 1'b0;
    always #5 clk = ~clk;
    logic rst_n;

    logic                 load_en, init;
    logic [1:0]           row_sel;
    logic                 ibuf_rd_en;
    logic [BUF_AW-1:0]    ibuf_rd_addr;
    logic [31:0]          ibuf_rd_data;
    logic [2:0][2:0][7:0] win [4];

    sobel_loader #(
        .BUF_AW     (BUF_AW),
        .IMG_WIDTH  (IMG_WIDTH),
        .IMG_HEIGHT (IMG_HEIGHT)
    ) dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .load_en      (load_en),
        .row_sel      (row_sel),
        .init         (init),
        .ibuf_rd_en   (ibuf_rd_en),
        .ibuf_rd_addr (ibuf_rd_addr),
        .ibuf_rd_data (ibuf_rd_data),
        .win_0        (win[0]),
        .win_1        (win[1]),
        .win_2        (win[2]),
        .win_3        (win[3])
    );

    // ibuf model: 1-cycle read latency. When not enabled the output is
    // garbage so a design that relies on stale data fails loudly.
    logic [31:0] ibuf [BUF_DEPTH];

    always_ff @(posedge clk) begin
        if (ibuf_rd_en) begin
            if (int'(ibuf_rd_addr) >= BUF_DEPTH) begin
                $error("ibuf read out of range: addr=%0d", ibuf_rd_addr);
                ibuf_rd_data <= 32'hDEAD_BEEF;
            end else begin
                ibuf_rd_data <= ibuf[ibuf_rd_addr];
            end
        end else begin
            ibuf_rd_data <= $urandom();
        end
    end

    function automatic logic [7:0] pixel_at(int row, int col);
        if (col < 0) return 8'h00;
        return ibuf[row * IMG_WIDTH + col / 4][8 * (col % 4) +: 8];
    endfunction

    int errors = 0;
    int checks = 0;

    function automatic void fail(string msg);
        errors++;
        if (errors <= MAX_REPORT) $display("ERROR @%0t: %s", $time, msg);
    endfunction

    // rd_en must follow load_en combinationally in every cycle
    always @(negedge clk) begin
        if (rst_n && ibuf_rd_en !== load_en)
            fail($sformatf("ibuf_rd_en=%b but load_en=%b", ibuf_rd_en, load_en));
    end

    task automatic step();
        @(posedge clk);
        #1;
    endtask

    task automatic idle_cycles(int n);
        load_en = 1'b0;
        row_sel = 2'd0;
        init    = 1'b0;
        repeat (n) step();
    endtask

    task automatic run_group(int r, int k);
        int base = IMG_WIDTH * (r - 1) + k;

        for (int ld = 0; ld < 3; ld++) begin
            load_en = 1'b1;
            row_sel = 2'(ld);
            init    = (k == 0);
            #1;
            checks++;
            if (int'(ibuf_rd_addr) != base + IMG_WIDTH * ld)
                fail($sformatf("r=%0d k=%0d ld=%0d: ibuf_rd_addr=%0d expected %0d",
                               r, k, ld, ibuf_rd_addr, base + IMG_WIDTH * ld));
            step();
        end

        // wait: bottom row word arrives and is captured at the end of this cycle
        load_en = 1'b0;
        init    = 1'b0;
        step();

        // comp: windows must be stable and correct
        for (int i = 0; i < 4; i++) begin
            for (int rr = 0; rr < 3; rr++) begin
                for (int c = 0; c < 3; c++) begin
                    logic [7:0] exp = pixel_at(r - 1 + rr, 4 * k - 2 + i + c);
                    checks++;
                    if (win[i][rr][c] !== exp)
                        fail($sformatf("r=%0d k=%0d win_%0d[%0d][%0d]=%02h expected %02h",
                                       r, k, i, rr, c, win[i][rr][c], exp));
                end
            end
        end
        step();
    endtask

    initial begin
        foreach (ibuf[a]) ibuf[a] = $urandom();

        load_en = 1'b0;
        row_sel = 2'd0;
        init    = 1'b0;
        rst_n   = 1'b0;
        repeat (3) @(posedge clk);
        #1 rst_n = 1'b1;
        step();

        for (int f = 0; f < FRAMES; f++) begin
            idle_cycles(1 + IMG_WIDTH);              // idle + zero_top
            for (int r = 1; r <= IMG_HEIGHT - 2; r++) begin
                for (int k = 0; k < IMG_WIDTH; k++)
                    run_group(r, k);
                idle_cycles(1);                      // flush
            end
            idle_cycles(IMG_WIDTH + 1);              // zero_bot + done
            $display("INFO: frame %0d done, %0d checks, %0d errors", f, checks, errors);
        end

        if (errors == 0) begin
            $display("PASS: sobel_loader (%0d checks)", checks);
        end else begin
            $fatal(1, "FAIL: sobel_loader (%0d errors in %0d checks)", errors, checks);
        end
        $finish;
    end

    initial begin
        if ($test$plusargs("trace")) begin
            $dumpfile("tb_sobel_loader.vcd");
            $dumpvars(0, tb_sobel_loader);
        end
    end

    initial begin
        #100ms;
        $fatal(1, "TIMEOUT");
    end

endmodule
