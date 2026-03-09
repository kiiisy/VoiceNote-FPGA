module rd_ctrl #(
    parameter integer DEPTH = 2048,
    parameter integer WIDTH = 36,
    parameter integer READ_LATENCY = 1
) (
    input  wire                        clk,
    input  wire                        reset,

    // from core_ctrl
    input  wire                        en,
    input  wire                        start_dump,
    input  wire [$clog2(DEPTH+1)-1:0]  dump_len,
    input  wire [$clog2(DEPTH)-1:0]    start_ptr,

    // to bram
    output wire                        bram_re,
    output wire [$clog2(DEPTH)-1:0]    bram_raddr,
    input  wire [WIDTH-1:0]            bram_rdata,

    // to data2stream
    output wire [WIDTH-1:0]            out_packed,
    output wire                        out_valid,
    input  wire                        out_ready,

    // to core_ctrl
    output wire                        dump_done
);
    // -------------------------------
    // パラメータ
    // -------------------------------
    localparam [1:0] S_IDLE = 2'd0;
    localparam [1:0] S_REQ  = 2'd1;
    localparam [1:0] S_WAIT = 2'd2;
    localparam [1:0] S_HOLD = 2'd3;

    localparam integer ADDR_W = $clog2(DEPTH);
    localparam integer REST_W = $clog2(DEPTH+1);
    localparam integer WAIT_W = (READ_LATENCY <= 1) ? 1 : $clog2(READ_LATENCY);

    // -------------------------------
    // 内部信号
    // -------------------------------
    reg [1:0]         r_state;
    reg [1:0]         r_next_state;
    reg [ADDR_W-1:0]  r_ptr;
    reg [REST_W-1:0]  r_rest_read_num;
    reg [WAIT_W-1:0]  r_wait_cnt;
    reg [WIDTH-1:0]   r_out_packed;
    reg               r_valid_data;
    reg               r_dump_done;

    wire w_start_enable;
    wire w_wait_done;
    wire w_out_accept;
    wire w_last_word;

    // dump読み出し開始
    assign w_start_enable = (r_state == S_IDLE) && en && start_dump && (dump_len != {REST_W{1'b0}});
    // bramのレイテンシ待ち
    assign w_wait_done    = (READ_LATENCY <= 1) ? 1'b1 : (r_wait_cnt == READ_LATENCY-1);
    // 出力データが受理されたか
    assign w_out_accept   = (r_state == S_HOLD) && r_valid_data && out_ready;
    // 最後のデータかどうか
    assign w_last_word    = w_out_accept && (r_rest_read_num == {{(REST_W-1){1'b0}}, 1'b1});

    // -------------------------------
    // ステートマシン
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_state <= S_IDLE;
        end else begin
            r_state <= r_next_state;
        end
    end

    always @(*) begin
        r_next_state = S_IDLE;

        case (r_state)
        // ---------------------------
        // IDLE: アイドル状態
        // ---------------------------
        S_IDLE: begin
            if (w_start_enable) begin
                r_next_state = S_REQ;
            end else begin
                r_next_state = S_IDLE;
            end
        end

        // ---------------------------
        // REQ: リクエスト状態
        // ---------------------------
        S_REQ: begin
            r_next_state = S_WAIT;
        end

        // ---------------------------
        // WAIT: 待ち状態
        // ---------------------------
        S_WAIT: begin
            if (w_wait_done) begin
                r_next_state = S_HOLD;
            end else begin
                r_next_state = S_WAIT;
            end
        end

        // ---------------------------
        // HOLD: 保持状態
        // ---------------------------
        S_HOLD: begin
            if (w_out_accept) begin
                if (w_last_word) begin
                    r_next_state = S_IDLE;
                end else begin
                    r_next_state = S_REQ;
                end
            end else begin
                r_next_state = S_HOLD;
            end
        end

        default: begin
            r_next_state = S_IDLE;
        end
        endcase
    end

    // -------------------------------
    // BRAM EN生成
    // -------------------------------
    assign bram_re = (r_state == S_REQ);

    // -------------------------------
    // 読み出しポインタ
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_ptr <= {ADDR_W{1'b0}};
        end else begin
            if (w_start_enable) begin
                r_ptr <= start_ptr;
            end else if (w_out_accept && !w_last_word) begin
                if (r_ptr == DEPTH-1) begin
                    r_ptr <= {ADDR_W{1'b0}};
                end else begin
                    r_ptr <= r_ptr + 1'b1;
                end
            end else begin
                r_ptr <= r_ptr;
            end
        end
    end

    assign bram_raddr = r_ptr;

    // -------------------------------
    // 残りの読み出し数
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_rest_read_num <= {REST_W{1'b0}};
        end else begin
            if (w_start_enable) begin
                r_rest_read_num <= dump_len;
            end else if (w_out_accept) begin
                if (r_rest_read_num != {REST_W{1'b0}}) begin
                    r_rest_read_num <= r_rest_read_num - 1'b1;
                end else begin
                    r_rest_read_num <= r_rest_read_num;
                end
            end else begin
                r_rest_read_num <= r_rest_read_num;
            end
        end
    end

    // -------------------------------
    // BRAM待ちカウンタ
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_wait_cnt <= {WAIT_W{1'b0}};
        end else begin
            if (r_state == S_REQ) begin
                r_wait_cnt <= {WAIT_W{1'b0}};
            end else if (r_state == S_WAIT) begin
                if (!w_wait_done) begin
                    r_wait_cnt <= r_wait_cnt + 1'b1;
                end else begin
                    r_wait_cnt <= r_wait_cnt;
                end
            end else begin
                r_wait_cnt <= r_wait_cnt;
            end
        end
    end

    // -------------------------------
    // 出力データ生成
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_out_packed <= {WIDTH{1'b0}};
        end else begin
            if ((r_state == S_WAIT) && w_wait_done) begin
                r_out_packed <= bram_rdata;
            end else begin
                r_out_packed <= r_out_packed;
            end
        end
    end

    assign out_packed = r_out_packed;

    // -------------------------------
    // 出力有効フラグ
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_valid_data <= 1'b0;
        end else begin
            if ((r_state == S_WAIT) && w_wait_done) begin
                r_valid_data <= 1'b1;
            end else if (w_out_accept) begin
                r_valid_data <= 1'b0;
            end else if (r_state == S_IDLE) begin
                r_valid_data <= 1'b0;
            end else begin
                r_valid_data <= r_valid_data;
            end
        end
    end

    assign out_valid = r_valid_data;

    // -------------------------------
    // dump完了
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_dump_done <= 1'b0;
        end else begin
            r_dump_done <= w_last_word;
        end
    end

    assign dump_done = r_dump_done;

endmodule
