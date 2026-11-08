`timescale 1ns/1ns

module tb_sobel_kernel;

    localparam int N_RANDOM   = 1_000_000;
    localparam int SMOOTH_MAX = 24;          // max deviation for "smooth" windows
    localparam int MAX_REPORT = 10;

    logic [2:0][2:0][7:0] win;
    logic [7:0]           pixel;

    sobel_kernel dut (
        .win   (win),
        .pixel (pixel)
    );

    int errors = 0;
    int checks = 0;
    int n_sat  = 0;                          // how many checks hit saturation

    // Reference model: plain 32-bit ints, no width/sign tricks
    function automatic int sobel_ref(logic [2:0][2:0][7:0] w);
        int s [3][3];
        int dx, dy, d;
        foreach (s[r, c]) s[r][c] = int'(w[r][c]);

        dx = (s[0][2] - s[0][0]) + 2 * (s[1][2] - s[1][0]) + (s[2][2] - s[2][0]);
        dy = (s[0][0] - s[2][0]) + 2 * (s[0][1] - s[2][1]) + (s[0][2] - s[2][2]);
        d  = (dx < 0 ? -dx : dx) + (dy < 0 ? -dy : dy);
        return (d > 255) ? 255 : d;
    endfunction

    function automatic logic [2:0][2:0][7:0] make_win(int rows [3][3]);
        logic [2:0][2:0][7:0] w;
        foreach (rows[r, c]) w[r][c] = 8'(rows[r][c]);
        return w;
    endfunction

    task automatic fail(string msg);
        errors++;
        if (errors <= MAX_REPORT) $error("%s", msg);
        else if (errors == MAX_REPORT + 1) $display("... further errors suppressed");
    endtask

    // Apply a window, let the combinational logic settle, compare
    task automatic check(logic [2:0][2:0][7:0] w, int expected, string name = "");
        win = w;
        #1;
        checks++;
        if (expected == 255) n_sat++;
        if (int'(pixel) != expected) begin
            fail($sformatf("%s win={%0d %0d %0d | %0d %0d %0d | %0d %0d %0d} got %0d expected %0d",
                 name,
                 w[0][0], w[0][1], w[0][2],
                 w[1][0], w[1][1], w[1][2],
                 w[2][0], w[2][1], w[2][2],
                 pixel, expected));
        end
    endtask

    // Directed case: expected value is written by hand, and must also
    // agree with the reference model (catches mistakes in the tb itself)
    task automatic directed(string name, int rows [3][3], int expected);
        logic [2:0][2:0][7:0] w = make_win(rows);
        if (sobel_ref(w) != expected)
            fail($sformatf("TB BUG: %s hand value %0d, model %0d", name, expected, sobel_ref(w)));
        check(w, expected, name);
    endtask

    task automatic directed_tests();
        //                                     top row          mid row          bottom row
        directed("all zero",          '{'{  0,  0,  0}, '{  0,  0,  0}, '{  0,  0,  0}},   0);
        directed("all 255",           '{'{255,255,255}, '{255,255,255}, '{255,255,255}},   0);
        directed("flat 50",           '{'{ 50, 50, 50}, '{ 50, 50, 50}, '{ 50, 50, 50}},   0);
        directed("weak vertical",     '{'{ 10, 10, 20}, '{ 10, 10, 20}, '{ 10, 10, 20}},  40);
        directed("strong vertical",   '{'{ 10, 10,200}, '{ 10, 10,200}, '{ 10, 10,200}}, 255); // |D| = 760
        directed("vertical reversed", '{'{ 20, 10, 10}, '{ 20, 10, 10}, '{ 20, 10, 10}},  40); // Dx < 0
        directed("weak horizontal",   '{'{ 30, 30, 30}, '{ 20, 20, 20}, '{ 15, 15, 15}},  60);
        directed("horizontal rev.",   '{'{ 15, 15, 15}, '{ 20, 20, 20}, '{ 30, 30, 30}},  60); // Dy < 0
        directed("strong horizontal", '{'{255,255,255}, '{128,128,128}, '{  0,  0,  0}}, 255);
        directed("diagonal mixed",    '{'{  0,  0, 40}, '{  0,  0,  0}, '{ 40,  0,  0}},   0); // Dx = 0, Dy = 0
        directed("dx neg, dy pos",    '{'{ 40,  0,  0}, '{  0,  0,  0}, '{  0,  0,  0}},  80);
        // |D| is always even (all coefficients of Dx+Dy are even), so 255 itself is unreachable
        directed("just below sat",    '{'{  0,127,  0}, '{  0,  0,  0}, '{  0,  0,  0}}, 254); // |D| = 254
        directed("just above sat",    '{'{  0,  0, 64}, '{  0,  0, 64}, '{  0,  0, 64}}, 255); // |D| = 256
        directed("theoretical max",   '{'{  0,255,255}, '{  0,  0,255}, '{  0,  0,  0}}, 255); // |D| = 1530
    endtask

    // Fully random windows: almost always saturate
    task automatic random_window(output logic [2:0][2:0][7:0] w);
        foreach (w[r, c]) w[r][c] = 8'($urandom_range(0, 255));
    endtask

    // Smooth windows: nine pixels close to a common base, so |D| often
    // lands in 0..255 and the exact arithmetic is checked, not just saturation.
    // The base is drawn near 0 and 255 too, to stress the 8-bit ends.
    task automatic smooth_window(output logic [2:0][2:0][7:0] w);
        int base = $urandom_range(0, 255);
        int v;
        foreach (w[r, c]) begin
            v = base + $urandom_range(0, 2 * SMOOTH_MAX) - SMOOTH_MAX;
            w[r][c] = 8'((v < 0) ? 0 : (v > 255) ? 255 : v);
        end
    endtask

    initial begin
        logic [2:0][2:0][7:0] w;
        int sat_before;

        win = '0;
        #1;

        directed_tests();
        $display("INFO: directed tests done, %0d checks, %0d errors", checks, errors);

        sat_before = n_sat;
        for (int i = 0; i < N_RANDOM; i++) begin
            if (i % 2 == 0) random_window(w);
            else            smooth_window(w);
            check(w, sobel_ref(w), "random");
        end
        $display("INFO: random tests done, %0d checks (%0d saturated, %0d exact), %0d errors",
                 N_RANDOM, n_sat - sat_before, N_RANDOM - (n_sat - sat_before), errors);

        if (errors == 0) begin
            $display("PASS: sobel_kernel (%0d checks)", checks);
        end else begin
            $fatal(1, "FAIL: sobel_kernel (%0d errors in %0d checks)", errors, checks);
        end
        $finish;
    end

    initial begin
        if ($test$plusargs("trace")) begin
            $dumpfile("tb_sobel_kernel.vcd");
            $dumpvars(0, tb_sobel_kernel);
        end
    end

    initial begin
        #100ms;
        $fatal(1, "TIMEOUT");
    end

endmodule
