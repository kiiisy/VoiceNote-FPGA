module iir_filter (
    input  wire                   clk,
    input  wire                   reset,

    // from dist2gain
    input  wire                   update_en,
    input  wire signed [15:0]     target_gain,

    // from register
    input  wire [31:0]            control_reg,
    input  wire [31:0]            alpha_config_reg,
    input  wire signed [31:0]     gain_min_reg,
    input  wire signed [31:0]     gain_max_reg,

    // to outside
    output wire  signed [15:0]    smooth_gain
);
    // -------------------------------
    // パラメータ
    // -------------------------------
    localparam S_IDLE = 4'd0;
    localparam S_DIFF = 4'd1;
    localparam S_DIV  = 4'd2;
    localparam S_ADD  = 4'd3;
    localparam S_CLIP = 4'd4;

    localparam signed [17:0] INIT_GAIN = 18'h4000; // 1.0 * 2^14

    // -------------------------------
    // 内部信号
    // -------------------------------
    reg [ 3:0] r_state;
    reg [ 3:0] r_next_state;

    reg signed [17:0] r_diff;
    reg signed [17:0] r_gain_smooth;
    reg signed [17:0] r_step;
    reg signed [17:0] r_next_gain;

    // レジスタ関連
    wire [ 3:0] w_alpha_common; // 通常α
    wire [ 3:0] w_alpha_up;     // 上昇時α
    wire [ 3:0] w_alpha_down;   // 下降時α
    wire [ 3:0] w_alpha;        // 実効α

    wire               w_reset_iir_reg;
    wire               w_freeze_reg;
    wire signed [15:0] w_gain_min_reg;
    wire signed [15:0] w_gain_max_reg;

    // 符号拡張
    wire signed [17:0] w_gain_min_q;
    wire signed [17:0] w_gain_max_q;

    // -------------------------------
    // レジスタ変換
    // -------------------------------
    assign w_alpha_common = (alpha_config_reg[3:0] > 4'd10) ? 4'd10 : alpha_config_reg[3:0];
    assign w_alpha_up     = (alpha_config_reg[7:4] > 4'd10) ? 4'd10 : alpha_config_reg[7:4];
    assign w_alpha_down   = (alpha_config_reg[11:8] > 4'd10) ? 4'd10 : alpha_config_reg[11:8];

    assign w_reset_iir_reg = control_reg[1];
    assign w_freeze_reg    = control_reg[2];
    assign w_gain_min_reg  = $signed(gain_min_reg[15:0]);
    assign w_gain_max_reg  = $signed(gain_max_reg[15:0]);

    // 符号拡張
    assign w_gain_min_q = { {2{w_gain_min_reg[15]}}, w_gain_min_reg };
    assign w_gain_max_q = { {2{w_gain_max_reg[15]}}, w_gain_max_reg };

    // 実効αの選択ロジック
    //  - 通常α != 0 の場合は常に通常α
    //  - 通常α == 0 の場合のみ、
    //      diff > 0  → UP α
    //      diff < 0  → DOWN α
    //      diff == 0 → 0（＝変化なし）
    assign w_alpha =
        (w_alpha_common != 4'd0) ? w_alpha_common :
        (r_diff > 18'd0)         ? w_alpha_up     :
        (r_diff < 18'd0)         ? w_alpha_down   : 4'd0;

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
        // -------------------------------
        // IDLE：データ待ち
        // -------------------------------
        S_IDLE: begin
            if (update_en) begin
                r_next_state = S_DIFF;
            end else begin
                r_next_state = S_IDLE;
            end
        end
        // -------------------------------
        // DIFF：差分計算
        // -------------------------------
        S_DIFF: begin
            r_next_state = S_DIV;
        end
        // -------------------------------
        // DIV：α = 1/2^k なので、算術右シフトで除算
        // -------------------------------
        S_DIV: begin
            r_next_state = S_ADD;
        end
        // -------------------------------
        // ADD：ゲイン計算
        // -------------------------------
        S_ADD: begin
            r_next_state = S_CLIP;
        end
        // -------------------------------
        // CLIP：クリッピング
        // -------------------------------
        S_CLIP: begin
            r_next_state = S_IDLE;
        end
        endcase
    end

    // -------------------------------
    // [DIFF] 差分計算
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_diff <= 18'd0;
        end else begin
            if (r_state == S_DIFF) begin
                r_diff <= {{2{target_gain[15]}}, target_gain} - r_gain_smooth;
            end else begin
                r_diff <= r_diff;
            end
        end
    end

    // -------------------------------
    // [DIV] α = 1/2^k → 算術右シフト
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_step <= 18'd0;
        end else begin
            if (r_state == S_DIV) begin
                r_step <= r_diff >>> w_alpha;
            end else begin
                r_step <= r_step;
            end
        end
    end

    // -------------------------------
    // [ADD] ゲイン計算
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_next_gain <= 18'd0;
        end else begin
            if (r_state == S_ADD) begin
                r_next_gain <= r_gain_smooth + r_step;
            end else begin
                r_next_gain <= r_next_gain;
            end
        end
    end

    // -------------------------------
    // [CLIP] クリッピング ＋ freeze/reset反映
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_gain_smooth <= INIT_GAIN;
        end else begin
            if (w_reset_iir_reg) begin
                // IIR リセット要求
                r_gain_smooth <= INIT_GAIN;
            end else if (w_freeze_reg) begin
                // ゲインを更新しない
                r_gain_smooth <= r_gain_smooth;
            end else if (r_state == S_CLIP) begin
                // 通常更新パス
                if (r_next_gain < w_gain_min_q) begin
                    r_gain_smooth <= w_gain_min_q;
                end else if (r_next_gain > w_gain_max_q) begin
                    r_gain_smooth <= w_gain_max_q;
                end else begin
                    r_gain_smooth <= r_next_gain;
                end
            end else begin
                r_gain_smooth <= r_gain_smooth;
            end
        end
    end

    // -------------------------------
    // 出力調整
    // -------------------------------
    assign smooth_gain = r_gain_smooth[15:0];

endmodule
