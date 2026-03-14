// ------------------------------------------------------------
// SV参照モデル（DUT制御同期のデータ整合チェッカ）
// - 制御タイミングはDUT信号に同期
// - データ内容（tid/sample16）の整合を検証
// ------------------------------------------------------------
localparam int REF_DEPTH = 2048;

int          r_ref_wr_ptr;
int          r_ref_dump_ptr;
int          r_ref_dump_rem;
logic [35:0] r_ref_ring [0:REF_DEPTH-1];

// ------------------------------------------------------------
// 参照モデルエラー記録
// ------------------------------------------------------------
task automatic ref_fail(input string msg);
    r_ref_fail_cnt = r_ref_fail_cnt + 1;
    $error("[REF][FAIL] %s", msg);
endtask

// ------------------------------------------------------------
// 補助関数
// ------------------------------------------------------------
function automatic int ref_wrap_add1(input int p);
    if (p == REF_DEPTH-1) begin
        return 0;
    end
    return p + 1;
endfunction

// ------------------------------------------------------------
// 参照モデル初期化
// ------------------------------------------------------------
task automatic ref_model_init();
    r_ref_wr_ptr   = 0;
    r_ref_dump_ptr = 0;
    r_ref_dump_rem = 0;
endtask

// ------------------------------------------------------------
// 参照モデル1サイクル更新
// ------------------------------------------------------------
task automatic ref_model_step();
    int in_hs;
    int out_hs;
    int dut_state;
    int dut_cap_start_ptr;
    int dut_start_dump;
    int dut_en_wr;
    int in_tid;
    int in_data_word;
    logic [35:0] exp_packed;
    logic [2:0] exp_tid;
    logic signed [15:0] exp_sample16;
    logic [2:0] act_tid;
    logic signed [15:0] act_sample16;

    // DUT観測信号
    in_hs  = dut.arec_0.s00_axis_tvalid & dut.arec_0.s00_axis_tready;
    out_hs = dut.arec_0.m00_axis_tvalid & dut.arec_0.m00_axis_tready;
    dut_state = dut.arec_0.inst.U_core.w_state;             // 0:PASS,1:ARMED,2:DUMP
    dut_cap_start_ptr = dut.arec_0.inst.U_core.w_cap_start_ptr;
    dut_start_dump    = dut.arec_0.inst.U_core.w_start_dump;
    dut_en_wr = dut.arec_0.inst.U_core.w_en_wr;
    in_tid = dut.arec_0.s00_axis_tid;
    in_data_word = dut.arec_0.s00_axis_tdata;

    // ARMED中に受理した入力をリングへ格納（wr_ctrl相当）
    if (in_hs && dut_en_wr) begin
        r_ref_ring[r_ref_wr_ptr] = {in_tid[2:0], in_data_word[31:0], 1'b0};
        r_ref_wr_ptr = ref_wrap_add1(r_ref_wr_ptr);
    end

    // DUMP開始位置をDUTで確定した後のタイミングで同期
    // cap_start_ptr周期はr_start_ptrがまだ旧値の可能性があるため、
    // start_dump周期でラッチする。
    if (dut_start_dump) begin
        r_ref_dump_ptr = dut.arec_0.inst.U_core.U_bram_ctrl.r_start_ptr;
        r_ref_dump_rem = dut.arec_0.inst.U_core.w_dump_len;
    end

    // PASS中はライブ入力と出力を比較（同時成立時のみ）
    if ((dut_state == 0) && in_hs && out_hs) begin
        exp_tid      = in_tid[2:0];
        exp_sample16 = in_data_word[27:12];
        act_tid      = dut.arec_0.m00_axis_tid[2:0];
        act_sample16 = dut.arec_0.m00_axis_tdata[27:12];
        if ((act_tid !== exp_tid) || (act_sample16 !== exp_sample16)) begin
            ref_fail($sformatf("PASS data mismatch exp(tid=%0d,s=%0d) act(tid=%0d,s=%0d)",
                               exp_tid, exp_sample16, act_tid, act_sample16));
        end
    end

    // DUMP中はリング内容と出力を比較
    if ((dut_state == 2) && out_hs) begin
        exp_packed   = r_ref_ring[r_ref_dump_ptr];
        exp_tid      = exp_packed[35:33];
        exp_sample16 = exp_packed[28:13];
        act_tid      = dut.arec_0.m00_axis_tid[2:0];
        act_sample16 = dut.arec_0.m00_axis_tdata[27:12];
        if ((act_tid !== exp_tid) || (act_sample16 !== exp_sample16)) begin
            ref_fail($sformatf("DUMP data mismatch exp(tid=%0d,s=%0d) act(tid=%0d,s=%0d) ptr=%0d rem=%0d",
                               exp_tid, exp_sample16, act_tid, act_sample16,
                               r_ref_dump_ptr, r_ref_dump_rem));
        end

        r_ref_dump_ptr = ref_wrap_add1(r_ref_dump_ptr);
        if (r_ref_dump_rem > 0) begin
            r_ref_dump_rem = r_ref_dump_rem - 1;
        end
    end
endtask

always @(posedge aclk) begin
    if (!aresetn) begin
        ref_model_init();
    end else begin
        ref_model_step();
    end
end
