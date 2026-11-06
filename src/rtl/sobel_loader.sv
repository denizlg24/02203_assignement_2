module sobel_loader #(
    parameter int BUF_AW     = 15,
    parameter int IMG_WIDTH  = 88,
    parameter int IMG_HEIGHT = 288
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
    // TOP ROW WORD ADDRESS OF THE LAST GROUP
    localparam logic [BUF_AW-1:0] BASE_LAST = BUF_AW'(IMG_WIDTH * (IMG_HEIGHT - 2) - 1);

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
    logic      [5:0][7:0] captured;

    assign ibuf_rd_en = load_en;
    assign ibuf_rd_addr = base_q + BUF_AW'(row_sel) * BUF_AW'(IMG_WIDTH);

    always_comb begin : read_data
        state_d = load_en ? CAPTURE : IDLE;
        base_d = base_q;
        row_d = row_q;

        captured[5:2] =     ibuf_rd_data;
        captured[1:0] = init_q ? '0 : row_q[sel_q][5:4];

        if(state_q == CAPTURE) begin
            row_d[sel_q] = captured;
            if(sel_q == 2'd2)
                base_d = (base_q == BASE_LAST) ? '0 : base_q + 1'b1;
        end
    end

    always_ff @( posedge clk or negedge rst_n ) begin : fsm
        if(!rst_n) begin
            state_q <= IDLE;
            sel_q <= '0;
            init_q <= 1'b0;
            base_q <= '0;
            row_q <= '0; 
        end else begin
            state_q <= state_d;
            sel_q <= row_sel;
            init_q <= init;
            base_q <= base_d;
            row_q <= row_d;
        end
    end

    always_comb begin : move_data
        for (int r = 0; r < 3; r++) begin
            for (int c = 0; c < 3 ;c++ ) begin
                win_0[r][c] = row_q[r][c];
                win_1[r][c] = row_q[r][c + 1];
                win_2[r][c] = row_q[r][c + 2];
                win_3[r][c] = row_q[r][c + 3];
            end
        end
    end

endmodule
