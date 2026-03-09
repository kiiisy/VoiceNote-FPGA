module core_ctrl (
    input  wire       clk,
    input  wire       reset,

    // from register
    input  wire       enable,
    input  wire       irq_clear,

    input  wire       trigger,
    input  wire       pretrig_ready,
    input  wire       dump_start_ok,
    input  wire       dump_done,

    input  wire       af_tready,

    output wire [1:0] state_reg,
    output wire       irq,

    output wire       i2s_tready,

    output wire       en_stream2data,
    output wire       en_wr,
    output wire       en_rd,

    // to rd_ctrl
    output wire       start_dump,
    output wire       cap_start_ptr,

    output wire       is_dump
);
    // -------------------------------
    // パラメータ
    // -------------------------------
    localparam S_PASS  = 2'd0;
    localparam S_ARMED = 2'd1;
    localparam S_DUMP  = 2'd2;

    // -------------------------------
    // 内部信号
    // -------------------------------
    reg [1:0] r_state;
    reg [1:0] r_next_state;
    reg [1:0] r_state_prev;

    reg       r_trigger_flg;
    reg       r_rearm_block;
    wire      w_dump_start;
    reg       r_irq_dump;

    // -------------------------------
    // レジスタ関連
    // -------------------------------
    assign state_reg = r_state;

    // -------------------------------
    // ステートマシン
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_state <= S_PASS;
        end else begin
            r_state <= r_next_state;
        end
    end

    always @(*) begin
        r_next_state = r_state;

        if (!enable) begin
            r_next_state = S_PASS;
        end else begin
            case (r_state)
            // ---------------------------
            // PASS: パススルー状態
            // ---------------------------
            S_PASS: begin
                if (enable && !r_rearm_block) begin
                    r_next_state = S_ARMED;
                end else begin
                    r_next_state = S_PASS;
                end
            end

            // ---------------------------
            // ARMED: 判定待ち状態
            // ---------------------------
            S_ARMED: begin
                if (w_dump_start) begin
                    r_next_state = S_DUMP;
                end else begin
                    r_next_state = S_ARMED;
                end
            end

            // ---------------------------
            // DUMP: DUMP状態
            // ---------------------------
            S_DUMP: begin
                if (dump_done) begin
                    r_next_state = S_PASS;
                end else begin
                    r_next_state = S_DUMP;
                end
            end

            default: begin
                r_next_state = S_PASS;
            end
            endcase
        end
    end

    // -------------------------------
    // 1クロック前状態
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_state_prev <= S_PASS;
        end else begin
            r_state_prev <= r_state;
        end
    end

    assign w_dump_start = pretrig_ready && (trigger || r_trigger_flg) && dump_start_ok;

    // -------------------------------
    // 再アーム禁止フラグ
    // DUMP完了後は一度enable=0を通すまで再アームしない
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_rearm_block <= 1'b0;
        end else begin
            if (!enable) begin
                r_rearm_block <= 1'b0;
            end else if ((r_state == S_DUMP) && dump_done) begin
                r_rearm_block <= 1'b1;
            end else begin
                r_rearm_block <= r_rearm_block;
            end
        end
    end

    // -------------------------------
    // トリガ保留フラグ
    // pretrig_readyまでtriggerイベントを保持
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_trigger_flg <= 1'b0;
        end else begin
            if (!enable) begin
                r_trigger_flg <= 1'b0;
            end else if (r_state != S_ARMED) begin
                r_trigger_flg <= 1'b0;
            end else if (trigger) begin
                r_trigger_flg <= 1'b1;
            end else begin
                r_trigger_flg <= r_trigger_flg;
            end
        end
    end

    // -------------------------------
    // DUMP開始IRQ（レベル）
    // - ARMEDでDUMP遷移条件成立時にセット
    // - ソフトからのclearパルスでクリア
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_irq_dump <= 1'b0;
        end else begin
            if (irq_clear) begin
                r_irq_dump <= 1'b0;
            end else if ((r_state == S_ARMED) && w_dump_start) begin
                r_irq_dump <= 1'b1;
            end else begin
                r_irq_dump <= 1'b0;
            end
        end
    end

    assign irq = r_irq_dump;

    // dump開始パルス生成
    assign start_dump = (r_state == S_DUMP) && (r_state_prev != S_DUMP);

    // DUMP遷移条件が成立した瞬間にwr_ptrをキャプチャ
    assign cap_start_ptr = (r_state == S_ARMED) && w_dump_start;

    // 各出力信号
    assign en_wr = (r_state == S_ARMED);
    assign en_rd = (r_state == S_DUMP);

    assign is_dump = (r_state == S_DUMP);
    assign en_stream2data = (r_state == S_ARMED);

    // 上流tready制御（dump中はバックプレッシャーをかける）
    assign i2s_tready = (r_state == S_PASS)  ? af_tready :
                        (r_state == S_ARMED) ? 1'b1 :
                                               1'b0;

endmodule
