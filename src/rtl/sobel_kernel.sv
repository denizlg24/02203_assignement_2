module sobel_kernel (
    input  logic [2:0][2:0][7:0] win,
    output logic [7:0]           pixel
);

    logic signed [10:0] gx, gy;
    logic        [10:0] abs_gx, abs_gy;
    logic        [11:0] mag;

endmodule
