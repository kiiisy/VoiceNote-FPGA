`timescale 1ns/1ps

import axi_vip_pkg::*;
import axi4stream_vip_pkg::*;
import recording_test_axi_vip_0_0_pkg::*;
import recording_test_axi_vip_1_0_pkg::*;
import recording_test_axi_vip_2_0_pkg::*;
import recording_test_axi4stream_vip_0_0_pkg::*;
import csv_pkg::*;

module tb_top;

// ------------------------------------------------------------
// インクルード定義
// ------------------------------------------------------------
`include "tb_cfg.svh"
`include "reg_acces.svh"
`include "tb_utils.svh"

// ------------------------------------------------------------
// 内部信号
// ------------------------------------------------------------
logic aclk = 0;
logic aresetn = 0;

logic lrclk;
logic sclk;
logic sdata = 0;

logic resp;
logic [31:0] arec_rdata;
xil_axi_resp_t arec_rresp;

logic irq;

logic eof = 0;
int  fd;

axi4stream_monitor_transaction mon_tr;

// 比較結果
int max_abs_diff;
int mismatch_cnt;
int r_scenario_fail_cnt;
bit r_scenario_pass;
string r_scenario_name;

always #5  aclk = ~aclk; // 100MHz

// ------------------------------------------------------------
// DUT
// ------------------------------------------------------------
recording_test dut (
    .aclk     (aclk),
    .aresetn  (aresetn),
    .lrclk_out(lrclk),
    .sclk_out (sclk),
    .sdata    (sdata),
    .irq      (irq)
);

// I2S
i2s_input_dpi src (
    .sclk (sclk),
    .lrclk(lrclk),
    .rstn (aresetn),
    .sdata(sdata),
    .eof  (eof)
);

// ------------------------------------------------------------
// AXI VIP ハンドル
// ------------------------------------------------------------
recording_test_axi_vip_0_0_mst_t        axi_i2s_mst;
recording_test_axi_vip_1_0_mst_t        axi_acu_mst;
recording_test_axi_vip_2_0_mst_t        axi_arec_mst;
recording_test_axi4stream_vip_0_0_slv_t axistream_slv;

// ------------------------------------------------------------
// シナリオ
// ------------------------------------------------------------
scenario_001 u_s001();
scenario_002 u_s002();
scenario_003 u_s003();
scenario_004 u_s004();
scenario_005 u_s005();

// ------------------------------------------------------------
// AXIS monitor (モノラルCSV→ステレオAXIS: L/R同じ)
// ------------------------------------------------------------
task automatic monitor_output();
    logic [31:0]             tdata_word;
    shortint                 sample_q15;
    xil_axi4stream_data_byte data_bytes[4];
    int                      ch_idx = 0;

    forever begin
        // AXI Streamの1トランザクション取得
        axistream_slv.monitor.item_collected_port.get(mon_tr);

        mon_tr.get_data(data_bytes);
        tdata_word = { data_bytes[3], data_bytes[2], data_bytes[1], data_bytes[0] };
        sample_q15 = shortint'(tdata_word[27:12]);

        // Leftチャンネルのみ書き出し
        if (ch_idx == 0) begin
            csv_output_write_q15(sample_q15);
        end

        ch_idx ^= 1;
    end
endtask

// ------------------------------------------------------------
// メインシーケンス
// ------------------------------------------------------------
initial begin
    int scenario_id;

    r_scenario_fail_cnt = 0;
    r_scenario_pass = 1'b0;
    r_scenario_name = "";

    if (!$value$plusargs("SCENARIO_ID=%d", scenario_id)) begin
        scenario_id = 1;
    end

    if (!$value$plusargs("INPUT_CSV=%s", INPUT_CSV_PATH)) begin
        INPUT_CSV_PATH = DEFAULT_INPUT_CSV;
    end
    if (!$value$plusargs("OUTPUT_CSV=%s", OUTPUT_CSV_PATH)) begin
        OUTPUT_CSV_PATH = DEFAULT_OUTPUT_CSV;
    end
    if (!$value$plusargs("GOLDEN_CSV=%s", GOLDEN_CSV_PATH)) begin
        GOLDEN_CSV_PATH = DEFAULT_GOLDEN_CSV;
    end

    $display("[TB] SCENARIO_ID = %0d", scenario_id);
    $display("[TB] INPUT_CSV   = %s", INPUT_CSV_PATH);
    $display("[TB] OUTPUT_CSV  = %s", OUTPUT_CSV_PATH);
    $display("[TB] GOLDEN_CSV  = %s", GOLDEN_CSV_PATH);

    csv_output_init(OUTPUT_CSV_PATH, GOLDEN_CSV_PATH);

    aresetn = 0;
    repeat(20) @(posedge aclk);
    aresetn = 1;

    // AXI VIP masterインスタンス作成
    axi_i2s_mst = new("axi_i2s_mst", dut.axi_vip_0.inst.IF);
    axi_i2s_mst.start_master();

    axi_acu_mst = new("axi_acu_mst", dut.axi_vip_1.inst.IF);
    axi_acu_mst.start_master();

    axi_arec_mst = new("axi_arec_mst", dut.axi_vip_2.inst.IF);
    axi_arec_mst.start_master();

    axistream_slv = new("axistream_slv", dut.axi4stream_vip_0.inst.IF);
    axistream_slv.start_slave();

    // 出力監視を並列で開始
    fork
        monitor_output();
    join_none

    repeat(5) @(posedge aclk);

    // I2Sのレジスタ設定
    axi_i2s_write(32'h30, 32'h0000_0001); // enable MCLK gen
    axi_i2s_write(32'h20, 32'h0000_0004); // SCK divider
    axi_i2s_write(32'h08, 32'h0000_0001); // I2S RX enable

    repeat(5) @(posedge aclk);

    // ACUのレジスタ設定（パススルー設定）
    set_acu_reg();

    // テストシナリオ実行
    case (scenario_id)
        1: begin TESTCASE = "scenario_001"; u_s001.run(); end
        2: begin TESTCASE = "scenario_002"; u_s002.run(); end
        3: begin TESTCASE = "scenario_003"; u_s003.run(); end
        4: begin TESTCASE = "scenario_004"; u_s004.run(); end
        5: begin TESTCASE = "scenario_005"; u_s005.run(); end
        default: begin
            $warning("[TB] unknown SCENARIO_ID=%0d, fallback to scenario_001", scenario_id);
            TESTCASE = "scenario_001";
            u_s001.run();
        end
    endcase

    repeat(5) @(posedge aclk);

    // CSV入力が終わるまで待つ
    wait (src.eof == 1'b1);

    // パイプラインが抜け切るのを少し待つ
    repeat (PASS_FLUSH_CYCLES) @(posedge aclk);

    $display("All CSV samples consumed. Finish simulation.");
    $finish;
end

final begin
    csv_output_close(max_abs_diff, mismatch_cnt);
    $display("[CMP] max_abs_diff=%0d, mismatch_cnt=%0d", max_abs_diff, mismatch_cnt);

    if ((max_abs_diff > 1) || (mismatch_cnt > 0)) begin
        $error("[CMP][FAIL] compare failed (max_abs_diff=%0d, mismatch_cnt=%0d)",
               max_abs_diff, mismatch_cnt);
    end else begin
        $display("[CMP][PASS] compare passed");
    end

    if (r_scenario_name != "") begin
        $display("[SCENARIO] name=%s result=%s fail_cnt=%0d",
                 r_scenario_name, r_scenario_pass ? "PASS" : "FAIL", r_scenario_fail_cnt);
    end
end

endmodule
