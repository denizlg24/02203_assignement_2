module sobel_loader #(
    parameter int BUF_AW    = 15,
    parameter int IMG_WIDTH = 88
)(
    input  logic                     clk,
    input  logic                     rst_n,

    input  logic                     load_en,
    input  logic [1:0]               row_sel,
    input  logic                     init,

    output logic                     ibuf_rd_en,
    output logic [BUF_AW-1:0]        ibuf_rd_addr,
    input  logic [31:0]              ibuf_rd_data,

    // win_i[row][col] = pixel at (top/mid/bot, column i+col)
    output logic [2:0][2:0][7:0]     win_0,
    output logic [2:0][2:0][7:0]     win_1,
    output logic [2:0][2:0][7:0]     win_2,
    output logic [2:0][2:0][7:0]     win_3
);

    typedef enum logic {
        IDLE    = 1'b0,
        CAPTURE = 1'b1
    } state_t;

    state_t              state_q, state_d;

    logic [1:0]          sel_q;
    logic                init_q;
    logic [BUF_AW-1:0]   base_q, base_d;

    // R0..R5 per window row: two carried pixels + four from the current word
    logic [2:0][5:0][7:0] row_q, row_d;

endmodule
