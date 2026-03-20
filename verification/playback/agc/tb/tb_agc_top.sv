`timescale 1ns/1ps

import axi_vip_pkg::*;
import axi4stream_vip_pkg::*;
import playback_test_axi_vip_0_0_pkg::*;
import playback_test_axi4stream_vip_0_0_pkg::*;
import playback_test_axi4stream_vip_1_0_pkg::*;
import csv_pkg::*;

module tb_agc_top;

// ------------------------------------------------------------
// インクルード定義
// ------------------------------------------------------------
`include "tb_agc_cfg.svh"

// ------------------------------------------------------------
// 内部信号
// ------------------------------------------------------------
logic aclk    = 0;
logic aresetn = 0;
logic rx      = 1'b1;
logic [15:0] r_dist_mm_cfg = 16'd1500;

logic resp;
int   max_abs_diff;
int   mismatch_cnt;
int   r_scenario_fail_cnt;
int   r_ref_fail_cnt;
bit   r_scenario_pass;
string r_scenario_name;

logic [31:0] r_ref_control_reg;
logic [31:0] r_ref_dist_sensitivity_reg;
logic [31:0] r_ref_manual_gain_reg;
logic [31:0] r_ref_gain_min_reg;
logic [31:0] r_ref_gain_max_reg;
logic [31:0] r_ref_alpha_config_reg;

axi4stream_transaction         axis_tr;
axi4stream_monitor_transaction mon_tr;

always #5 aclk = ~aclk;

`include "pb_reg_acces.svh"
`include "tb_agc_utils.svh"
`include "tb_agc_ref_model.svh"

// ------------------------------------------------------------
// DUT
// ------------------------------------------------------------
playback_test dut (
    .aclk   (aclk),
    .aresetn(aresetn),
    .rx     (rx)
);

// ------------------------------------------------------------
// AXI VIP ハンドル
// ------------------------------------------------------------
playback_test_axi_vip_0_0_mst_t        axi_agc_mst;
playback_test_axi4stream_vip_0_0_mst_t axis_src_mst;
playback_test_axi4stream_vip_1_0_slv_t axis_sink_slv;

// ------------------------------------------------------------
// UART ToF モデル
// ------------------------------------------------------------
uart_tx_model #(
    .CLK_FREQ_HZ         (CLK_FREQ_HZ),
    .BAUD_RATE           (BAUD_RATE),
    .FRAME_INTERVAL_CLKS (321_880)
) U_uart_tx_model (
    .clk   (aclk),
    .rst_n (aresetn),
    .dist_mm(r_dist_mm_cfg),
    .rx    (rx)
);

// ------------------------------------------------------------
// シナリオ
// ------------------------------------------------------------
playback_scenario_001 u_s001();
playback_scenario_002 u_s002();
playback_scenario_003 u_s003();
playback_scenario_004 u_s004();
playback_scenario_005 u_s005();

// ------------------------------------------------------------
// AXIS monitor
// ------------------------------------------------------------
task automatic monitor_output();
    xil_axi4stream_data_byte data_bytes[4];
    logic [31:0]             tdata_word;
    shortint                 sample_q15;
    int unsigned             beat_id;

    forever begin
        axis_sink_slv.monitor.item_collected_port.get(mon_tr);
        mon_tr.get_data(data_bytes);
        beat_id    = mon_tr.get_id();
        tdata_word = {data_bytes[3], data_bytes[2], data_bytes[1], data_bytes[0]};
        sample_q15 = shortint'(tdata_word[27:12]);

        ref_model_check_output(beat_id[2:0], sample_q15);

        if (beat_id[0] == 1'b0) begin
            csv_output_write_q15(sample_q15);
        end
    end
endtask

// ------------------------------------------------------------
// メインシーケンス
// ------------------------------------------------------------
initial begin
    int scenario_id;

    r_scenario_fail_cnt = 0;
    r_ref_fail_cnt = 0;
    r_scenario_pass = 1'b0;
    r_scenario_name = "";
    ref_model_init();

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

    aresetn = 1'b0;
    repeat (20) @(posedge aclk);
    aresetn = 1'b1;

    axi_agc_mst   = new("axi_agc_mst",   dut.axi_vip_0.inst.IF);
    axis_src_mst  = new("axis_src_mst",  dut.axi4stream_vip_0.inst.IF);
    axis_sink_slv = new("axis_sink_slv", dut.axi4stream_vip_1.inst.IF);

    axi_agc_mst.start_master();
    axis_src_mst.start_master();
    axis_sink_slv.start_slave();

    fork
        monitor_output();
    join_none

    repeat (10) @(posedge aclk);

    case (scenario_id)
        1: begin
            TESTCASE = "scenario_001";
            u_s001.run();
        end
        2: begin
            TESTCASE = "scenario_002";
            u_s002.run();
        end
        3: begin
            TESTCASE = "scenario_003";
            u_s003.run();
        end
        4: begin
            TESTCASE = "scenario_004";
            u_s004.run();
        end
        5: begin
            TESTCASE = "scenario_005";
            u_s005.run();
        end
        default: begin
            $warning("[TB] unknown SCENARIO_ID=%0d, fallback to scenario_001", scenario_id);
            TESTCASE = "scenario_001";
            u_s001.run();
        end
    endcase

    $display("All CSV samples consumed. Finish simulation.");
    $finish;
end

final begin
    int ref_pending_cnt;

    csv_output_close(max_abs_diff, mismatch_cnt);
    $display("[CMP] max_abs_diff=%0d, mismatch_cnt=%0d", max_abs_diff, mismatch_cnt);
    $display("[REF] mismatch_cnt=%0d", r_ref_fail_cnt);

    $display("[CMP][INFO] csv compare is informational for AGC.");

    ref_pending_cnt = ref_model_pending_count();
    if (ref_pending_cnt > 0) begin
        r_ref_fail_cnt = r_ref_fail_cnt + ref_pending_cnt;
        $error("[REF][FAIL] pending expected outputs remain (%0d)", ref_pending_cnt);
    end

    if (r_ref_fail_cnt > 0) begin
        $error("[REF][FAIL] compare failed (mismatch_cnt=%0d)", r_ref_fail_cnt);
    end else begin
        $display("[REF][PASS] compare passed");
    end

    if (r_scenario_name != "") begin
        $display("[SCENARIO] name=%s result=%s fail_cnt=%0d",
                 r_scenario_name, r_scenario_pass ? "PASS" : "FAIL", r_scenario_fail_cnt);
    end
end

endmodule
