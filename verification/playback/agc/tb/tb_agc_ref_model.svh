// ------------------------------------------------------------
// AGC参照モデル
// 役割:
// - AGC入力ハンドシェイク時点の有効gainを使って期待出力を生成する
// - monitor_output() から呼ばれ、DUT出力と順番どおりに比較する
// - AGC制御そのものはシナリオ側、データパス整合は本モデルが担当する
// ------------------------------------------------------------
localparam signed [15:0] REF_MAX16 = 16'h7FFF;
localparam signed [15:0] REF_MIN16 = 16'h8000;

logic [2:0]      r_ref_tid_q[$];
shortint         r_ref_sample_q[$];

// ------------------------------------------------------------
// 参照モデル初期化
// ------------------------------------------------------------
task automatic ref_model_init();
    r_ref_fail_cnt = 0;
    r_ref_tid_q.delete();
    r_ref_sample_q.delete();
endtask

// ------------------------------------------------------------
// 有効gain取得
// manual mode時はmanual_gain_reg、auto mode時はDUTのgain_smoothを使う
// ------------------------------------------------------------
function automatic signed [15:0] ref_model_get_gain();
    if (r_ref_control_reg[0]) begin
        ref_model_get_gain = r_ref_manual_gain_reg[15:0];
    end else begin
        ref_model_get_gain = dut.agc_0.inst.U_core.gain_smooth_reg;
    end
endfunction

// ------------------------------------------------------------
// 期待サンプル生成
// RTL calculation.v と同じく sample * gain >> 14 で飽和させる
// ------------------------------------------------------------
function automatic shortint ref_model_calc_sample(input shortint sample_q15);
    reg signed [15:0] ref_gain;
    reg signed [31:0] ref_product;
    reg signed [31:0] ref_shifted;
    reg signed [15:0] ref_sat;
begin
    ref_gain    = ref_model_get_gain();
    ref_product = sample_q15 * ref_gain;
    ref_shifted = ref_product >>> 14;

    if (ref_shifted > REF_MAX16) begin
        ref_sat = REF_MAX16;
    end else if (ref_shifted < REF_MIN16) begin
        ref_sat = REF_MIN16;
    end else begin
        ref_sat = ref_shifted[15:0];
    end

    ref_model_calc_sample = shortint'(ref_sat);
end
endfunction

// ------------------------------------------------------------
// 期待値キュー登録
// 入力ハンドシェイク成立順に期待tid/sampleを積む
// ------------------------------------------------------------
task automatic ref_model_push_input(
    input logic [2:0] in_tid,
    input shortint    in_sample_q15
);
    r_ref_tid_q.push_back(in_tid);
    r_ref_sample_q.push_back(ref_model_calc_sample(in_sample_q15));
endtask

// ------------------------------------------------------------
// 出力比較
// monitor_output() から呼ばれ、期待値キュー先頭と比較する
// ------------------------------------------------------------
task automatic ref_model_check_output(
    input logic [2:0] out_tid,
    input shortint    out_sample_q15
);
    logic [2:0] exp_tid;
    shortint    exp_sample_q15;
begin
    if (r_ref_tid_q.size() == 0) begin
        r_ref_fail_cnt = r_ref_fail_cnt + 1;
        $error("[REF][FAIL] unexpected output act(tid=%0d,s=%0d)",
               out_tid, out_sample_q15);
    end else begin
        exp_tid        = r_ref_tid_q.pop_front();
        exp_sample_q15 = r_ref_sample_q.pop_front();

        if ((exp_tid != out_tid) || (exp_sample_q15 != out_sample_q15)) begin
            r_ref_fail_cnt = r_ref_fail_cnt + 1;
            $error("[REF][FAIL] data mismatch exp(tid=%0d,s=%0d) act(tid=%0d,s=%0d)",
                   exp_tid, exp_sample_q15, out_tid, out_sample_q15);
        end
    end
end
endtask

// ------------------------------------------------------------
// 保留期待値数取得
// ------------------------------------------------------------
function automatic int ref_model_pending_count();
    ref_model_pending_count = r_ref_tid_q.size();
endfunction

// ------------------------------------------------------------
// 入力ハンドシェイク監視
// DUT入力ポートで受けた実データを参照モデルへ流し込む
// ------------------------------------------------------------
always @(posedge aclk or negedge aresetn) begin
    shortint in_sample_q15;

    if (!aresetn) begin
        ref_model_init();
    end else begin
        if (dut.agc_0.s00_axis_tvalid && dut.agc_0.s00_axis_tready) begin
            in_sample_q15 = shortint'(dut.agc_0.s00_axis_tdata[27:12]);
            ref_model_push_input(dut.agc_0.s00_axis_tid[2:0], in_sample_q15);
        end
    end
end
