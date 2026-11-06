module sobel_controller #(
    parameter int IMG_WIDTH  = 88,
    parameter int IMG_HEIGHT = 288
)(
    input  logic       clk,
    input  logic       rst_n,

    input  logic       start,
    output logic       finish,

    output logic       load_en,
    output logic [1:0] row_sel,
    output logic       init,

    output logic       first,
    output logic       write,
    output logic       flush,
    output logic       zero_row
);

    localparam int K_W = $clog2(IMG_WIDTH);
    localparam int R_W = $clog2(IMG_HEIGHT);

    typedef enum logic [3:0] {
        IDLE     = 4'd0,
        ZERO_TOP = 4'd1,
        LOAD     = 4'd2,
        WAIT     = 4'd3,
        COMP_2   = 4'd4,
        COMP_4   = 4'd5,
        FLUSH    = 4'd6,
        ZERO_BOT = 4'd7,
        DONE     = 4'd8
    } state_t;

    state_t         state_q, state_d;

    logic [K_W-1:0] k_q, k_d;
    logic [R_W-1:0] r_q, r_d;
    logic [1:0]     ld_q, ld_d;

endmodule
