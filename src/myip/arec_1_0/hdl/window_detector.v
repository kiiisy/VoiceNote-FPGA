// window_detector.v
// Time-window based level detector (mean abs) for I2S RX AES AXIS sample stream
//
// Inputs:
//  - sample_stb : 1-cycle strobe when a new sample is accepted (in_fire)
//  - sample16   : signed 16-bit sample (e.g., TDATA[27:12])
//  - tid        : channel id (useful to select only one channel)
//
// Function:
//  - Accumulate abs(sample) over N = 2^WINDOW_SHIFT samples
//  - Compute mean = sum >> WINDOW_SHIFT
//  - Compare with threshold
//  - Require CONSEC_WINS consecutive windows above threshold to assert trigger_pulse (1-cycle)
//
// Notes:
//  - If you feed both L/R (same data), mean doubles; prefer gating by tid.
//
// Style matches user's example: simple regs, posedge reset, clear with W1P-like inputs.


//	1.	サンプルが来た？
//	2.	enable & チャネルOK？
//	3.	|sample| を計算
//	4.	窓内で加算
//	5.	窓満了？
//	6.	平均を計算
//	7.	しきい値と比較
//	8.	連続回数を更新
//	9.	条件成立で trigger
//	10.	窓をリセット


module window_detector (
    input  wire        clk,
    input  wire        reset,

    // -------------------------------
    // Control registers
    // -------------------------------
    input  wire        enable,
    input  wire [4:0]  window_shift_reg,   // window = 2^shift samples
    input  wire [3:0]  consec_wins_reg,     // consecutive windows
    input  wire [15:0] threshold_reg,       // mean |sample| threshold

    // -------------------------------
    // Sample input
    // -------------------------------
    input  wire        sample_stb,
    input  wire signed [15:0] sample16,

    // -------------------------------
    // Outputs
    // -------------------------------
    output wire        trigger_pulse
);

    // -------------------------------
    // パラメータ
    // -------------------------------
    localparam S_IDLE      = 3'd0;
    localparam S_ACCUM     = 3'd1;
    localparam S_UPDATE    = 3'd2;
    localparam S_DONE      = 3'd3;

    // -------------------------------
    // 内部信号
    // -------------------------------
    reg [2:0] r_state;
    reg [2:0] r_next_state;

    reg [31:0] r_sigma_abs;

    reg [15:0] r_window_cnt;
    wire       w_window_cnt_done;

    reg [3:0]  r_con_window_cnt;

    reg         r_triggered;

    wire [15:0] w_abs_sample;
    wire [15:0] w_window_cnt_max;
    wire [15:0] w_mean;
    wire        w_is_th_over;

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
            if (enable && sample_stb && !r_triggered) begin
                r_next_state = S_ACCUM;
            end else begin
                r_next_state = S_IDLE;
            end
        end

        // ---------------------------
        // ACCUM: 窓数分のデータを取得 & 加算
        // ---------------------------
        S_ACCUM: begin
            if (w_window_cnt_done) begin
                r_next_state = S_UPDATE;
            end else begin
                r_next_state = S_IDLE;
            end
        end

        // ---------------------------
        // UPDATE: 連続窓数判定
        // ---------------------------
        S_UPDATE: begin
            if (w_is_th_over && (r_con_window_cnt + 1'b1 >= consec_wins_reg)) begin
                r_next_state = S_DONE;
            end else begin
                r_next_state = S_IDLE;
            end
        end

        // ---------------------------
        // DONE: latched stop
        // ---------------------------
        S_DONE: begin
            r_next_state = S_DONE;
        end
        endcase
    end

    // -------------------------------
    // 窓数カウンタ
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_window_cnt <= 16'd0;
        end else begin
            if (r_state == S_ACCUM) begin
                if (r_window_cnt == w_window_cnt_max) begin
                    r_window_cnt <= 16'd0;
                end else begin
                    r_window_cnt <= r_window_cnt 16'd1;
                end
            end else begin
                r_window_cnt <= 16'd0;
            end
        end
    end

    assign w_window_cnt_done = (r_window_cnt == w_window_cnt_max);

    // -------------------------------
    // 絶対値σ
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_sigma_abs <= 32'd0;
        end else begin
            if (r_state == S_ACCUM) begin
                r_sigma_abs <= r_sigma_abs + w_abs_sample;
            end else begin
                r_sigma_abs <= 32'd0;
            end
        end
    end

    // -------------------------------
    // 連続窓数カウンタ
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_con_window_cnt <= 4'd0;
        end else begin
            if (r_state == S_UPDATE) begin
                if (w_is_th_over) begin
                    r_con_window_cnt <= r_con_window_cnt +4'd1;
                end else begin
                    r_con_window_cnt <= r_con_window_cnt;
                end
            end else if (r_state == S_DONE) begin
                r_con_window_cnt <= 4'd0;
            end else begin
                r_con_window_cnt <= r_con_window_cnt;
            end
        end
    end

    // -------------------------------
    // Datapath / outputs
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_con_window_cnt    <= 4'd0;
            r_triggered     <= 1'b0;
        end else begin
            case (r_state)
            // -----------------------
            // UPDATE
            // -----------------------
            S_UPDATE: begin
                if (w_is_th_over) begin
                    r_con_window_cnt    <= r_con_window_cnt + 1'b1;
                    if (r_con_window_cnt + 1'b1 >= consec_wins_reg) begin
                        r_triggered <= 1'b1;
                    end
                end else begin
                    r_con_window_cnt    <= 4'd0;
                end
            end

            default: begin
                // hold
            end
            endcase
        end
    end

    // -------------------------------
    // 色んな演算達
    // -------------------------------
    // サンプルの絶対値算出
    w_abs_sample = (sample16[15]) ?
                   (sample16 == 16'h8000 ? 16'h7FFF : (~sample16 + 1'b1)) : sample16;

    // 窓数のループ上限
    w_window_cnt_max = (16'd1 << window_shift_reg) - 1'd1;

    // 平均値
    w_mean = r_sigma_abs >> window_shift_reg;

    // 平均値が閾値を超えているか
    w_is_th_over = (w_mean >= threshold_reg);

    // -------------------------------
    // Trigger pulse (1-cycle)
    // -------------------------------
    assign trigger_pulse =
        (r_state == S_UPDATE) &&
        w_is_th_over &&
        (r_con_window_cnt + 1'b1 >= consec_wins_reg);

endmodule
