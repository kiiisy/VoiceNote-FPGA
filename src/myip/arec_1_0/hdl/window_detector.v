module window_detector (
    input  wire               clk,
    input  wire               reset,

    // from register
    input  wire               enable,
    input  wire [4:0]         window_shift_reg,
    input  wire [3:0]         required_windows_reg,
    input  wire [15:0]        threshold_reg,

    input  wire               sample_stb,
    input  wire signed [15:0] sample16,

    // to core_ctrl
    output wire               trigger_pulse,

    output wire               triggered_latched
);
    // -------------------------------
    // パラメータ
    // -------------------------------
    localparam S_IDLE  = 2'd0;
    localparam S_ACCUM = 2'd1;
    localparam S_JUDGE  = 2'd2;
    localparam S_DONE  = 2'd3;

    // -------------------------------
    // 内部信号
    // -------------------------------
    reg [1:0]  r_state;
    reg [1:0]  r_next_state;

    reg [31:0] r_sum_abs;
    reg [15:0] r_window_cnt;
    reg [ 3:0] r_cont_window_cnt;
    reg        r_trigger_pulse;
    reg        r_triggered_latched;
    reg        r_is_threshold_over;

    wire [15:0] w_abs_sample;
    wire [15:0] w_window_last;
    wire [15:0] w_mean;
    wire [ 3:0] w_required_windows;
    wire        w_window_done;
    wire        w_threshold_over;
    wire        w_trigger_hit;

    // 入力サンプルの絶対値を計算
    assign w_abs_sample  = sample16[15] ? ((sample16 == 16'h8000) ? 16'h7fff : (~sample16 + 16'd1)) : sample16;
    // 窓の最終カウント値（2^shift - 1）
    assign w_window_last = (16'd1 << window_shift_reg) - 16'd1;
    // 連続窓数の下限を1に補正
    assign w_required_windows = (required_windows_reg == 4'd0) ? 4'd1 : required_windows_reg;
    // 窓終わり時に評価する平均絶対値
    assign w_mean = (r_sum_abs + w_abs_sample) >> window_shift_reg;
    // 平均絶対値がしきい値以上か
    assign w_threshold_over = (w_mean >= threshold_reg);

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
        r_next_state = r_state;

        case (r_state)
        // ---------------------------
        // IDLE: アイドル状態
        // ---------------------------
        S_IDLE: begin
            if (!enable) begin
                r_next_state = S_IDLE;
            end else begin
                r_next_state = S_ACCUM;
            end
        end

        // ---------------------------
        // ACCUM: サンプルを積算中
        // ---------------------------
        S_ACCUM: begin
            if (!enable) begin
                r_next_state = S_IDLE;
            end else if (w_window_done) begin
                r_next_state = S_JUDGE;
            end else begin
                r_next_state = S_ACCUM;
            end
        end

        // ---------------------------
        // JUDGE: 窓1つ分を判定中
        // ---------------------------
        S_JUDGE: begin
            if (!enable) begin
                r_next_state = S_IDLE;
            end else if (w_trigger_hit) begin
                r_next_state = S_DONE;
            end else begin
                r_next_state = S_ACCUM;
            end
        end

        // ---------------------------
        // DONE: 完了状態
        // ---------------------------
        S_DONE: begin
            if (!enable) begin
                r_next_state = S_IDLE;
            end else begin
                r_next_state = S_DONE;
            end
        end

        default: begin
            r_next_state = S_IDLE;
        end
        endcase
    end

    // -------------------------------
    // 窓積算値
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_sum_abs <= 32'd0;
        end else begin
            if (!enable) begin
                r_sum_abs <= 32'd0;
            end else begin
                case (r_state)
                S_IDLE: begin
                    r_sum_abs <= 32'd0;
                end
                S_ACCUM: begin
                    if (sample_stb) begin
                        if (w_window_done) begin
                            r_sum_abs <= 32'd0;
                        end else begin
                            r_sum_abs <= r_sum_abs + w_abs_sample;
                        end
                    end
                end
                default: begin
                    r_sum_abs <= r_sum_abs;
                end
                endcase
            end
        end
    end

    // -------------------------------
    // 窓カウンタ
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_window_cnt <= 16'd0;
        end else begin
            if (!enable) begin
                r_window_cnt <= 16'd0;
            end else begin
                case (r_state)
                S_IDLE: begin
                    r_window_cnt <= 16'd0;
                end
                S_ACCUM: begin
                    if (sample_stb) begin
                        if (w_window_done) begin
                            r_window_cnt <= 16'd0;
                        end else begin
                            r_window_cnt <= r_window_cnt + 16'd1;
                        end
                    end
                end
                default: begin
                    r_window_cnt <= r_window_cnt;
                end
                endcase
            end
        end
    end

    assign w_window_done = sample_stb && (r_window_cnt == w_window_last);

    // -------------------------------
    // 窓終わり時のしきい値比較結果を保持
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_is_threshold_over <= 1'b0;
        end else begin
            if (!enable) begin
                r_is_threshold_over <= 1'b0;
            end else if (r_state == S_ACCUM && w_window_done) begin
                r_is_threshold_over <= w_threshold_over;
            end
        end
    end

    // -------------------------------
    // 連続窓カウンタ
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_cont_window_cnt <= 4'd0;
        end else begin
            if (!enable) begin
                r_cont_window_cnt <= 4'd0;
            end else begin
                case (r_state)
                S_IDLE: begin
                    r_cont_window_cnt <= 4'd0;
                end
                S_JUDGE: begin
                    if (r_is_threshold_over) begin
                        r_cont_window_cnt <= r_cont_window_cnt + 4'd1;
                    end else begin
                        r_cont_window_cnt <= 4'd0;
                    end
                end
                default: begin
                    r_cont_window_cnt <= r_cont_window_cnt;
                end
                endcase
            end
        end
    end

    assign w_trigger_hit = r_is_threshold_over && (r_cont_window_cnt + 4'd1 >= w_required_windows);

    // -------------------------------
    // トリガパルス & ラッチ
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_trigger_pulse <= 1'b0;
        end else begin
            if (!enable) begin
                r_trigger_pulse <= 1'b0;
            end else begin
                r_trigger_pulse <= (r_state == S_JUDGE) && w_trigger_hit;
            end
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_triggered_latched <= 1'b0;
        end else begin
            if (!enable) begin
                r_triggered_latched <= 1'b0;
            end else if ((r_state == S_JUDGE) && w_trigger_hit) begin
                r_triggered_latched <= 1'b1;
            end
        end
    end

    assign trigger_pulse     = r_trigger_pulse;
    assign triggered_latched = r_triggered_latched;

endmodule
