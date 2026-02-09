module dist2gain (
    input  wire        clk,
    input  wire        reset,

    // from register
    input  wire [31:0] dist_sensitivity_reg,

    // from dist_if
    input  wire [15:0] dist_data,
    input  wire        dist_valid,

    // to iir_filter
    output wire [15:0] gain_data,
    output wire        gain_valid,

    // to register
    output wire [15:0] dist_raw_mm,
    output wire [15:0] dist_clamp_mm
);
    // -------------------------------
    // パラメータ
    // -------------------------------
    localparam LUT_DEPTH = 88;
    localparam LUT_WIDTH = 16;

    // 上下限閾値（Supported for 200mm to 3000mm）
    localparam DIST_MIN_MM = 16'd200;
    localparam DIST_MAX_MM = 16'd3000;

    localparam STEP_LOG2 = 5;  // 32mm = 2^5

    localparam S_IDLE      = 3'd0;
    localparam S_CLAMP     = 3'd1;
    localparam S_DIFF      = 3'd2;
    localparam S_JUDGE     = 3'd3;
    localparam S_OFFSET    = 3'd4;
    localparam S_ADDR      = 3'd5;
    localparam S_READ      = 3'd6;
    localparam S_WAIT_READ = 3'd7;

    localparam READ_LATENCY = 2;

    // -------------------------------
    // 内部信号
    // -------------------------------
    reg  [ 2:0] r_state;
    reg  [ 2:0] r_next_state;

    reg  [15:0] r_dist_raw_mm;
    reg  [16:0] r_dist_diff_mm;
    reg  [15:0] r_dist_clamped_mm;
    reg  [15:0] r_offset_mm;

    reg  [ 6:0] r_addr;
    reg         r_rden;
    wire        w_rden;
    reg  [ 2:0] r_wait_cnt;
    wire        w_wait_done;
    reg  [15:0] r_pre_dist;
    wire [15:0] w_dist_sensitivity_reg;

    // -------------------------------
    // レジスタ関連
    // -------------------------------
    assign w_dist_sensitivity_reg = dist_sensitivity_reg[15:0];
    assign dist_raw_mm            = r_dist_raw_mm;
    assign dist_clamp_mm          = r_dist_clamped_mm;

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
        // IDLE：dToFからのデータ待ち
        // -------------------------------
        S_IDLE: begin
            if (dist_valid) begin
                r_next_state = S_CLAMP;
            end else begin
                r_next_state = S_IDLE;
            end
        end
        // -------------------------------
        // CLAMP：有効距離の上下限ガード
        // -------------------------------
        S_CLAMP: begin
            r_next_state = S_DIFF;
        end
        // -------------------------------
        // DIFF：差分抽出
        // -------------------------------
        S_DIFF: begin
            r_next_state = S_JUDGE;
        end
        // -------------------------------
        // JUDGE：感度調整
        // -------------------------------
        S_JUDGE: begin
            if (r_dist_diff_mm >= w_dist_sensitivity_reg) begin
                r_next_state = S_OFFSET;
            end else begin
                // 更新がない場合はそのまま終了
                r_next_state = S_IDLE;
            end
        end
        // -------------------------------
        // OFFSET：下限の200mmのオフセット調整
        // -------------------------------
        S_OFFSET: begin
            r_next_state = S_ADDR;
        end
        // -------------------------------
        // ADDR：アドレス変換
        // -------------------------------
        S_ADDR: begin
            r_next_state = S_READ;
        end
        // -------------------------------
        // READ：LUTからデータ読み出し開始
        // -------------------------------
        S_READ: begin
            r_next_state = S_WAIT_READ;
        end
        // -------------------------------
        // WAIT_READ：LUTからの読み出し待ち
        // -------------------------------
        S_WAIT_READ: begin
            if (w_wait_done) begin
                r_next_state = S_IDLE;
            end else begin
                r_next_state = S_WAIT_READ;
            end
        end
        endcase
    end

    // -------------------------------
    // [IDLE] 生測距データの保持
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_dist_raw_mm <= 16'd0;
        end else begin
            if (r_state == S_IDLE && dist_valid) begin
                r_dist_raw_mm <= dist_data;
            end else begin
                r_dist_raw_mm <= r_dist_raw_mm;
            end
        end
    end

    // -------------------------------
    // [CLAMP] 上下限ガード
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_dist_clamped_mm <= 16'd0;
        end else begin
            if (r_state == S_CLAMP) begin
                r_dist_clamped_mm <=
                    (r_dist_raw_mm <= DIST_MIN_MM) ? DIST_MIN_MM :
                    (r_dist_raw_mm >= DIST_MAX_MM) ? DIST_MAX_MM : r_dist_raw_mm;
            end else begin
                r_dist_clamped_mm <= r_dist_clamped_mm;
            end
        end
    end

    // -------------------------------
    // [DIFF] 差分抽出
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_dist_diff_mm <= 17'd0;
        end else begin
            if (r_state == S_DIFF) begin
                if (r_dist_clamped_mm > r_pre_dist) begin
                    r_dist_diff_mm <= r_dist_clamped_mm - r_pre_dist;
                end else begin
                    r_dist_diff_mm <= r_pre_dist - r_dist_clamped_mm;
                end
            end else begin
                r_dist_diff_mm <= r_dist_diff_mm;
            end
        end
    end

    // -------------------------------
    // [JUDGE] 更新確認
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_pre_dist <= 16'd0;
        end else begin
            if (r_state == S_JUDGE) begin
                if (r_dist_diff_mm >= w_dist_sensitivity_reg) begin
                    r_pre_dist <= r_dist_clamped_mm;
                end else begin
                    r_pre_dist <= r_pre_dist;
                end
            end else begin
                r_pre_dist <= r_pre_dist;
            end
        end
    end

    // -------------------------------
    // [OFFSET] オフセット調整
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_offset_mm <= 16'd0;
        end else begin
            if (r_state == S_OFFSET) begin
                r_offset_mm <= r_dist_clamped_mm - DIST_MIN_MM;
            end else begin
                r_offset_mm <= r_offset_mm;
            end
        end
    end

    // -------------------------------
    // [ADDR] アドレス変換&イネーブル生成
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_rden <= 1'b0;
            r_addr <= 7'd0;
        end else begin
            if (r_state == S_ADDR) begin
                r_rden <= 1'b1;
                r_addr <= r_offset_mm >> STEP_LOG2;
            end else begin
                r_rden <= 1'b0;
                r_addr <= r_addr;
            end
        end
    end

    assign w_rden = r_rden;

    // -------------------------------
    // [WAIT_READ] LUTの読み出し待ち
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_wait_cnt <= 1'd0;
        end else begin
            if (r_state == S_WAIT_READ) begin
                if (w_wait_done) begin
                    r_wait_cnt <= 1'd0;
                end else begin
                    r_wait_cnt <= r_wait_cnt + 1'd1;
                end
            end else begin
                r_wait_cnt <= 1'd0;
            end
        end
    end

    assign w_wait_done = (r_wait_cnt == (READ_LATENCY-1));
    assign gain_valid  = w_wait_done;

    // -------------------------------
    // LUT本体
    // -------------------------------
    xpm_memory_sprom #(
        .ADDR_WIDTH_A(7),              // DECIMAL
        .AUTO_SLEEP_TIME(0),           // DECIMAL
        .CASCADE_HEIGHT(0),            // DECIMAL
        .ECC_BIT_RANGE("7:0"),         // String
        .ECC_MODE("no_ecc"),           // String
        .ECC_TYPE("none"),             // String
        .IGNORE_INIT_SYNTH(0),         // DECIMAL
        .MEMORY_INIT_FILE("gain_lut.mem"), // String
        .MEMORY_INIT_PARAM("0"),       // String
        .MEMORY_OPTIMIZATION("true"),  // String
        .MEMORY_PRIMITIVE("auto"),     // String
        .MEMORY_SIZE(LUT_DEPTH*LUT_WIDTH), // DECIMAL
        .MESSAGE_CONTROL(0),           // DECIMAL
        .RAM_DECOMP("auto"),           // String
        .READ_DATA_WIDTH_A(LUT_WIDTH), // DECIMAL
        .READ_LATENCY_A(READ_LATENCY), // DECIMAL
        .READ_RESET_VALUE_A("0"),      // String
        .RST_MODE_A("SYNC"),           // String
        .SIM_ASSERT_CHK(0),            // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
        .USE_MEM_INIT(1),              // DECIMAL
        .USE_MEM_INIT_MMI(0),          // DECIMAL
        .WAKEUP_TIME("disable_sleep")  // String
    )
    xpm_memory_sprom_inst (
        .dbiterra(/* not use */),        // 1-bit output: Leave open.
        .douta(gain_data),               // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
        .sbiterra(/* not use */),        // 1-bit output: Leave open.
        .addra(r_addr),                  // ADDR_WIDTH_A-bit input: Address for port A read operations.
        .clka(clk),                      // 1-bit input: Clock signal for port A.
        .ena(w_rden),                    // 1-bit input: Memory enable signal for port A. Must be high on clock
                                         // cycles when read operations are initiated. Pipelined internally.
        .injectdbiterra(1'b0),           // 1-bit input: Do not change from the provided value.
        .injectsbiterra(1'b0),           // 1-bit input: Do not change from the provided value.
        .regcea(1'b1),                   // 1-bit input: Do not change from the provided value.
        .rsta(reset),                    // 1-bit input: Reset signal for the final port A output register stage.
                                         // Synchronously resets output port douta to the value specified by
                                         // parameter READ_RESET_VALUE_A.
        .sleep(1'b0)                     // 1-bit input: sleep signal to enable the dynamic power saving feature.
    );

endmodule
