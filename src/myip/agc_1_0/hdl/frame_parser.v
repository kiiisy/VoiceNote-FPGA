module frame_parser (
    input  wire        clk,
    input  wire        reset,

    // from uart_rx
    input  wire [ 7:0] rx_byte,
    input  wire        rx_valid,

    // to dist2gain
    output wire [15:0] dist_mm,
    output wire        dist_valid,
    output wire        pkt_error,
    output wire        tof_working
);
    // -------------------------------
    // パラメータ
    // -------------------------------
    // ヘッダーの2Byte
    localparam H1  = 8'h59;
    localparam H2  = 8'h59;
    localparam H12 = H1 + H2;

    localparam S_WAIT_H1 = 2'd0;
    localparam S_WAIT_H2 = 2'd1;
    localparam S_COLLECT = 2'd2;
    localparam S_CHECK   = 2'd3;

    localparam TOF_TIMEOUT_CLKS = 10_000_000;  // 100ms @ 100MHz

    // -------------------------------
    // 内部信号
    // -------------------------------
    reg  [ 1:0] r_state;
    reg  [ 1:0] r_next_state;

    reg  [ 3:0] r_idx;
    reg  [ 7:0] r_buf [0:5];

    reg  [15:0] r_checksum;

    reg  [15:0] r_dist_mm;
    reg         r_dist_valid;

    reg         r_pkt_error;
    reg         r_checksum_done;
    wire        w_checksum_done;

    reg  [23:0] r_watchdog_cnt;
    reg         r_tof_working;

    // -------------------------------
    // ステートマシン
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_state <= S_WAIT_H1;
        end else begin
            r_state <= r_next_state;
        end
    end

    always @(*) begin
        r_next_state = S_WAIT_H1;

        case (r_state)
        // ----------------------------
        // WAIT_H1: 0x59
        // ----------------------------
        S_WAIT_H1: begin
            if (rx_byte == H1 && rx_valid) begin
                r_next_state = S_WAIT_H2;
            end else begin
                r_next_state = S_WAIT_H1;
            end
        end
        // ----------------------------
        // WAIT_H2: 0x59
        // ----------------------------
        S_WAIT_H2: begin
            if (rx_valid) begin
                if (rx_byte == H2) begin
                    r_next_state = S_COLLECT;
                end else begin
                    r_next_state = S_WAIT_H1;
                end
            end else begin
                r_next_state = S_WAIT_H2;
            end
        end
        // ----------------------------
        // COLLECT：データバイト 2〜7 を収集（計6バイト）
        // ----------------------------
        S_COLLECT: begin
            if (r_idx == 4'd6) begin
                r_next_state = S_CHECK;
            end else begin
                r_next_state = S_COLLECT;
            end
        end
        // ----------------------------
        // CHECK：チェックサム収集&検証
        // ----------------------------
        S_CHECK: begin
            if (w_checksum_done) begin
                r_next_state = S_WAIT_H1;
            end else begin
                r_next_state = S_CHECK;
            end
        end
        endcase
    end

    // ------------------------------
    // データバイト収集
    // ------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_buf[0] <= 8'd0;
            r_buf[1] <= 8'd0;
            r_buf[2] <= 8'd0;
            r_buf[3] <= 8'd0;
            r_buf[4] <= 8'd0;
            r_buf[5] <= 8'd0;
        end else begin
            if (r_state == S_COLLECT) begin
                if (rx_valid) begin
                    r_buf[r_idx] <= rx_byte;
                end else begin
                    r_buf[0] <= r_buf[0];
                    r_buf[1] <= r_buf[1];
                    r_buf[2] <= r_buf[2];
                    r_buf[3] <= r_buf[3];
                    r_buf[4] <= r_buf[4];
                    r_buf[5] <= r_buf[5];
                end
            end else if (r_state == S_CHECK) begin
                r_buf[0] <= r_buf[0];
                r_buf[1] <= r_buf[1];
                r_buf[2] <= r_buf[2];
                r_buf[3] <= r_buf[3];
                r_buf[4] <= r_buf[4];
                r_buf[5] <= r_buf[5];
            end else begin
                r_buf[0] <= 8'd0;
                r_buf[1] <= 8'd0;
                r_buf[2] <= 8'd0;
                r_buf[3] <= 8'd0;
                r_buf[4] <= 8'd0;
                r_buf[5] <= 8'd0;
            end
        end
    end

    // ------------------------------
    // バイト収集カウンタ生成
    // ------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_idx <= 4'd0;
        end else begin
            if (r_state == S_COLLECT) begin
                if (rx_valid) begin
                    r_idx <= r_idx + 4'd1;
                end else begin
                    r_idx <= r_idx;
                end
            end else begin
                r_idx <= 4'd0;
            end
        end
    end

    // ------------------------------
    // チェックサム処理
    // ------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_checksum <= H12;
        end else begin
            if (r_state == S_COLLECT) begin
                if (rx_valid) begin
                    r_checksum <= r_checksum + {8'd0, rx_byte};
                end else begin
                    r_checksum <= r_checksum;
                end
            end else if (r_state == S_CHECK) begin
                r_checksum <= r_checksum;
            end else begin
                r_checksum <= H12;
            end
        end
    end

    // ------------------------------
    // 出力管理
    // ------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_pkt_error     <= 1'b0;
            r_dist_mm       <= 16'd0;
            r_dist_valid    <= 1'b0;
            r_checksum_done <= 1'b0;
        end else begin
            if (r_state == S_CHECK && rx_valid) begin
                if (r_checksum[7:0] == rx_byte) begin
                    r_pkt_error     <= 1'b0;
                    r_dist_mm       <= {r_buf[1], r_buf[0]};
                    r_dist_valid    <= 1'b1;
                    r_checksum_done <= 1'b1;
                end else begin
                    r_pkt_error     <= 1'b1;
                    r_dist_mm       <= 16'd0;
                    r_dist_valid    <= 1'b0;
                    r_checksum_done <= 1'b1;
                end
            end else begin
                r_pkt_error     <= 1'b0;
                r_dist_mm       <= 16'd0;
                r_dist_valid    <= 1'b0;
                r_checksum_done <= 1'b0;
            end
        end
    end

    // ------------------------------
    // 出力管理
    // ------------------------------
    assign w_checksum_done = r_checksum_done;
    assign dist_mm         = r_dist_mm;
    assign dist_valid      = r_dist_valid;
    assign pkt_error       = r_pkt_error;

    // ------------------------------
    // ToF監視
    // ------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_watchdog_cnt <= 24'd0;
            r_tof_working  <= 1'b0;
        end else begin
            if (r_watchdog_cnt > TOF_TIMEOUT_CLKS) begin
                r_tof_working  <= 1'b0;
                r_watchdog_cnt <= 24'd0;
            // 距離フレーム受信 → 正常動作
            end else if (dist_valid && !pkt_error) begin
                r_watchdog_cnt <= 24'd0;
                r_tof_working  <= 1'b1;
            end else begin
                r_watchdog_cnt <= r_watchdog_cnt + 24'd1;
                r_tof_working  <= r_tof_working;
            end
        end
    end

    assign tof_working = r_tof_working;

endmodule
