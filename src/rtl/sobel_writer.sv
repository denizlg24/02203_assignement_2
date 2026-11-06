module sobel_writer #(
    parameter int BUF_AW = 15
)(
    input  logic               clk,
    input  logic               rst_n,

    input  logic [7:0]         pixel_0,
    input  logic [7:0]         pixel_1,
    input  logic [7:0]         pixel_2,
    input  logic [7:0]         pixel_3,

    input  logic               first,
    input  logic               write,
    input  logic               flush,
    input  logic               zero_row,

    output logic               obuf_wr_en,
    output logic [BUF_AW-1:0]  obuf_wr_addr,
    output logic [31:0]        obuf_wr_data
);

    typedef enum logic [2:0] {
        IDLE    = 3'd0,
        STORE_2 = 3'd1,
        STORE_4 = 3'd2,
        FLUSH   = 3'd3,
        ZERO    = 3'd4
    } state_t;

    state_t             state_q, state_d;

    logic [23:0]        carry_q, carry_d;
    logic [BUF_AW-1:0]  wa_q, wa_d;

    logic               wr_en;
    logic [31:0]        wr_data;

endmodule
