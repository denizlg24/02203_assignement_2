module sobel_kernel (
    input  logic [2:0][2:0][7:0] win,
    output logic [7:0]           pixel
);

    logic signed [10:0] gx, gy;
    logic        [10:0] abs_gx, abs_gy;
    logic        [11:0] mag;

    // win[row][col] -> zero-extended signed pixel, so differences can go negative
    function automatic logic signed [10:0] s(input logic [7:0] p);
        return $signed({3'b000, p});
    endfunction

    always_comb begin : compute
        // Dx = (s13 - s11) + 2(s23 - s21) + (s33 - s31), |Dx| <= 1020
        gx = (s(win[0][2]) - s(win[0][0]))
           + ((s(win[1][2]) - s(win[1][0])) <<< 1)
           + (s(win[2][2]) - s(win[2][0]));

        // Dy = (s11 - s31) + 2(s12 - s32) + (s13 - s33), |Dy| <= 1020
        gy = (s(win[0][0]) - s(win[2][0]))
           + ((s(win[0][1]) - s(win[2][1])) <<< 1)
           + (s(win[0][2]) - s(win[2][2]));

        abs_gx = gx[10] ? 11'(-gx) : 11'(gx);
        abs_gy = gy[10] ? 11'(-gy) : 11'(gy);

        // |D| = |Dx| + |Dy|, at most 1530 for 8-bit pixels
        mag = 12'(abs_gx) + 12'(abs_gy);

        // saturate to the 8-bit output range
        pixel = (mag > 12'd255) ? 8'd255 : mag[7:0];
    end

endmodule
