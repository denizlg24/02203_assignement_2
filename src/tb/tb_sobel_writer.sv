`timescale 1ns/1ns

// Drives sobel_writer with the command sequence the controller produces
// (zero_top, first/write per group, flush per row, zero_bot) and random
// pixels, records every obuf write, and compares the resulting frame with
// the expected output image. Two frames back-to-back exercise the wa wrap.
//
// Pixels are only valid in the comp cycle and the cycle after it (the
// window the loader holds stable); every other cycle they are garbage.
module tb_sobel_writer;

    localparam int BUF_AW     = 15;
    localparam int IMG_WIDTH  = 88;
    localparam int IMG_HEIGHT = 288;
    localparam int BUF_DEPTH  = IMG_WIDTH * IMG_HEIGHT;
    localparam int ROW_PIX    = IMG_WIDTH * 4;
    localparam int FRAMES     = 2;
    localparam int MAX_REPORT = 10;

    logic clk = 1'b0;
    always #5 clk = ~clk;
    logic rst_n;

    logic [7:0]        pixel [4];
    logic              first, write, flush, zero_row;
    logic              obuf_wr_en;
    logic [BUF_AW-1:0] obuf_wr_addr;
    logic [31:0]       obuf_wr_data;

    sobel_writer #(
        .BUF_AW    (BUF_AW),
        .BUF_DEPTH (BUF_DEPTH)
    ) dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .pixel_0      (pixel[0]),
        .pixel_1      (pixel[1]),
        .pixel_2      (pixel[2]),
        .pixel_3      (pixel[3]),
        .first        (first),
        .write        (write),
        .flush        (flush),
        .zero_row     (zero_row),
        .obuf_wr_en   (obuf_wr_en),
        .obuf_wr_addr (obuf_wr_addr),
        .obuf_wr_data (obuf_wr_data)
    );

    // p[r][k][i] = pixel_i presented for centre row r, group k
    logic [7:0] p [IMG_HEIGHT][IMG_WIDTH][4];

    // Output column x comes from group k = (x+1)/4, kernel i = (x+1)%4.
    // Column 0 and the last column are border pixels and must be 0.
    function automatic logic [7:0] expected_pixel(int row, int col);
        if (row == 0 || row == IMG_HEIGHT - 1) return 8'h00;
        if (col == 0 || col == ROW_PIX - 1)    return 8'h00;
        return p[row][(col + 1) / 4][(col + 1) % 4];
    endfunction

    function automatic logic [31:0] expected_word(int addr);
        int row = addr / IMG_WIDTH;
        int col = 4 * (addr % IMG_WIDTH);
        return {expected_pixel(row, col + 3), expected_pixel(row, col + 2),
                expected_pixel(row, col + 1), expected_pixel(row, col)};
    endfunction

    int errors = 0;

    function automatic void fail(string msg);
        errors++;
        if (errors <= MAX_REPORT) $display("ERROR @%0t: %s", $time, msg);
    endfunction

    // obuf model / scoreboard
    logic [31:0] obuf    [BUF_DEPTH];
    int          written [BUF_DEPTH];
    int          n_writes;

    always_ff @(posedge clk) begin
        if (rst_n && obuf_wr_en) begin
            if (int'(obuf_wr_addr) >= BUF_DEPTH) begin
                fail($sformatf("obuf write out of range: addr=%0d", obuf_wr_addr));
            end else begin
                obuf[obuf_wr_addr] <= obuf_wr_data;
                written[obuf_wr_addr] <= written[obuf_wr_addr] + 1;
            end
            n_writes <= n_writes + 1;
        end
    end

    task automatic step();
        @(posedge clk);
        #1;
    endtask

    task automatic set_cmd(bit f, bit w, bit fl, bit z);
        first    = f;
        write    = w;
        flush    = fl;
        zero_row = z;
    endtask

    task automatic garbage_pixels();
        foreach (pixel[i]) pixel[i] = $urandom();
    endtask

    task automatic valid_pixels(int r, int k);
        foreach (pixel[i]) pixel[i] = p[r][k][i];
    endtask

    task automatic zero_phase();
        garbage_pixels();
        repeat (IMG_WIDTH) begin
            set_cmd(0, 0, 0, 1);
            step();
        end
    endtask

    // One group = load x3, wait, comp (5 cycles). The previous group's
    // pixels stay valid through the first load cycle; after the last group
    // of a row the cycle after comp is flush instead.
    task automatic run_group(int r, int k);
        set_cmd(0, 0, 0, 0);
        step();
        repeat (3) begin
            garbage_pixels();
            step();
        end
        valid_pixels(r, k);
        set_cmd(k == 0, k != 0, 0, 0);
        step();
        set_cmd(0, 0, 0, 0);
        if (k == IMG_WIDTH - 1) begin
            flush = 1'b1;
            step();
            flush = 1'b0;
            garbage_pixels();
        end
    endtask

    task automatic check_frame(int f);
        int missing = 0, multiple = 0;
        for (int a = 0; a < BUF_DEPTH; a++) begin
            if (written[a] == 0) begin
                missing++;
                fail($sformatf("frame %0d: word %0d (row %0d, word %0d) never written",
                               f, a, a / IMG_WIDTH, a % IMG_WIDTH));
            end else begin
                if (written[a] > 1) begin
                    multiple++;
                    fail($sformatf("frame %0d: word %0d written %0d times", f, a, written[a]));
                end
                if (obuf[a] !== expected_word(a))
                    fail($sformatf("frame %0d: word %0d (row %0d, word %0d) = %08h expected %08h",
                                   f, a, a / IMG_WIDTH, a % IMG_WIDTH, obuf[a], expected_word(a)));
            end
        end
        if (n_writes != BUF_DEPTH)
            fail($sformatf("frame %0d: %0d writes, expected %0d", f, n_writes, BUF_DEPTH));
        $display("INFO: frame %0d: %0d writes, %0d missing, %0d duplicated, %0d errors total",
                 f, n_writes, missing, multiple, errors);
    endtask

    initial begin
        set_cmd(0, 0, 0, 0);
        garbage_pixels();
        n_writes = 0;
        rst_n    = 1'b0;
        repeat (3) @(posedge clk);
        #1 rst_n = 1'b1;
        step();

        for (int f = 0; f < FRAMES; f++) begin
            foreach (p[r, k, i]) p[r][k][i] = 8'($urandom_range(1, 255));
            foreach (written[a]) written[a] = 0;
            n_writes = 0;

            set_cmd(0, 0, 0, 0);                  // controller idle
            step();
            zero_phase();                         // zero_top
            for (int r = 1; r <= IMG_HEIGHT - 2; r++)
                for (int k = 0; k < IMG_WIDTH; k++)
                    run_group(r, k);
            zero_phase();                         // zero_bot
            set_cmd(0, 0, 0, 0);                  // done
            repeat (4) step();

            check_frame(f);
        end

        if (errors == 0) begin
            $display("PASS: sobel_writer");
        end else begin
            $fatal(1, "FAIL: sobel_writer (%0d errors)", errors);
        end
        $finish;
    end

    initial begin
        if ($test$plusargs("trace")) begin
            $dumpfile("tb_sobel_writer.vcd");
            $dumpvars(0, tb_sobel_writer);
        end
    end

    initial begin
        #100ms;
        $fatal(1, "TIMEOUT");
    end

endmodule
