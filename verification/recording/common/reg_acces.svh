// ------------------------------------------------------------
// ベースアドレス定義
// ------------------------------------------------------------
localparam logic [31:0] I2S_RX_BASE = 32'h44A0_0000;
localparam logic [31:0] ACU_BASE    = 32'h0000_0000;
localparam logic [31:0] AREC_BASE   = 32'h44B0_0000;

// ------------------------------------------------------------
// AXI-Lite 書き込みヘルパー
// ------------------------------------------------------------
task automatic axi_i2s_write(input logic [31:0] offset, input logic [31:0] data);
    axi_i2s_mst.AXI4LITE_WRITE_BURST(I2S_RX_BASE + offset, 0, data, resp);
endtask

task automatic axi_acu_write(input logic [31:0] offset, input logic [31:0] data);
    axi_acu_mst.AXI4LITE_WRITE_BURST(ACU_BASE + offset, 0, data, resp);
endtask

task automatic axi_arec_write(input logic [31:0] offset, input logic [31:0] data);
    axi_arec_mst.AXI4LITE_WRITE_BURST(AREC_BASE + offset, 0, data, resp);
endtask

task automatic axi_arec_read(input logic [31:0] offset, output logic [31:0] data);
    axi_arec_mst.AXI4LITE_READ_BURST(AREC_BASE + offset, 0, data, arec_rresp);
endtask

// ------------------------------------------------------------
// ACU設定
// ------------------------------------------------------------
task automatic set_acu_reg();
    // DCカット
    axi_acu_write(32'h10, 32'h3F7F54A7);
    axi_acu_write(32'h18, 32'h00000001);  // dc_pass = 1 (バイパス)

    // ノイズゲート閾値 (Q34)
    axi_acu_write(32'h20, 32'h03333334);  // th_open low
    axi_acu_write(32'h24, 32'h00000000);  // th_open high
    axi_acu_write(32'h2C, 32'h028F5C28);  // th_close low
    axi_acu_write(32'h30, 32'h00000000);  // th_close high

    // アタック / リリース係数 (Q22)
    axi_acu_write(32'h38, 32'h003FBBE0);  // a_attack
    axi_acu_write(32'h48, 32'h00004420);  // b_attack
    axi_acu_write(32'h40, 32'h003FF92C);  // a_release
    axi_acu_write(32'h50, 32'h000006D3);  // b_release

    // ノイズゲートパス
    axi_acu_write(32'h58, 32'h00000001);  // ng_pass = 1 (バイパス)

    // 制御系
    axi_acu_write(32'h00, 32'h00000081);  // ap_start + auto_restart
endtask

// ------------------------------------------------------------
// AREC設定（PASS固定）
// ------------------------------------------------------------
task automatic set_arec_passthrough_reg();
    // reg0: CONTROL (bit0=enable)
    axi_arec_write(32'h00, 32'h00000000);  // enable=0 -> PASS固定

    // 以下は将来の有効化に備えて初期値を設定（現状は未使用）
    // reg4: THRESHOLD
    axi_arec_write(32'h10, 32'h00001000);
    // reg5: WINDOW_SHIFT
    axi_arec_write(32'h14, 32'h00000006);
    // reg6: PRETRIG_SAMPLES
    axi_arec_write(32'h18, 32'h00000400);
    // reg7: CONSEC_WINS
    axi_arec_write(32'h1C, 32'h00000001);
endtask

// ------------------------------------------------------------
// AREC設定（トリガ録音）
// ------------------------------------------------------------
// この関数未使用。削除してもいい
task automatic set_arec_trigger_recording_reg();
    // いったんdisableで各設定を書き込む
    axi_arec_write(32'h00, 32'h00000000);  // CONTROL.enable=0

    // trigger parameters
    // reg4: THRESHOLD (Q15 |sample|平均の線形しきい値)
    axi_arec_write(32'h10, 32'h00000300);
    // reg5: WINDOW_SHIFT (window=2^shift samples)
    axi_arec_write(32'h14, 32'h00000006);  // 64 samples
    // reg6: PRETRIG_SAMPLES (dump length)
    axi_arec_write(32'h18, 32'h00000200);  // 512 samples
    // reg7: CONSEC_WINS
    axi_arec_write(32'h1C, 32'h00000002);  // 2 windows

    // enable AREC
    axi_arec_write(32'h00, 32'h00000001);  // CONTROL.enable=1
endtask

task automatic set_arec_trigger_recording_cfg_reg(
    input logic [15:0] threshold,
    input logic [4:0]  window_shift,
    input logic [11:0] pretrig_samples,
    input logic [3:0]  consec_wins
);
    // いったんdisableで各設定を書き込む
    axi_arec_write(32'h00, 32'h00000000);  // CONTROL.enable=0

    // trigger parameters
    axi_arec_write(32'h10, {16'd0, threshold});
    axi_arec_write(32'h14, {27'd0, window_shift});
    axi_arec_write(32'h18, {20'd0, pretrig_samples});
    axi_arec_write(32'h1C, {28'd0, consec_wins});

    // enable AREC
    axi_arec_write(32'h00, 32'h00000001);  // CONTROL.enable=1
endtask
