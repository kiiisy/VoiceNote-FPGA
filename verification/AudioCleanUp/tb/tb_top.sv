`timescale 1ns/1ps

import axi_vip_pkg::*;
import axi4stream_vip_pkg::*;
import recording_test_axi_vip_0_0_pkg::*;
import recording_test_axi_vip_1_0_pkg::*;
import recording_test_axi4stream_vip_0_0_pkg::*;
import csv_pkg::*;

module tb_recording;

// トップのIO
logic aclk = 0;
logic aresetn = 0;
logic lrclk;
logic sclk;
logic sdata = 0;
logic resp;
logic eof = 0;

int  fd;

axi4stream_monitor_transaction mon_tr;

// 比較結果
int max_abs_diff;
int mismatch_cnt;

// テスト対象
recording_test dut (
    .aaclk     (aclk),
    .aresetn  (aresetn),
    .lrclk_out(lrclk),
    .sclk_out (sclk),
    .sdata    (sdata)
);

  // DPI ベースの I2S 入力
i2s_input_dpi #(
    .CSV_PATH("../../../../../../verification/AudioCleanUp/input/audio_clean_up_case1_input.csv")
) src (
    .sclk (sclk),
    .lrclk(lrclk),
    .rstn (aresetn),
    .sdata(sdata),
    .eof  (eof)
);

always #5  aclk = ~aclk; // 100MHz

// AXI VIP のマスター／スレーブハンドル
recording_test_axi_vip_0_0_mst_t       axi_i2s_mst;
recording_test_axi_vip_1_0_mst_t       axi_acu_mst;
recording_test_axi4stream_vip_0_0_slv_t axistream_slv;

// I2S RXのベースアドレス
localparam I2S_RX_BASE = 32'h44A0_0000;
// ACUのベースアドレス
localparam ACU_BASE    = 32'h0000_0000;


initial begin
    csv_output_init(
      // HW 出力を書き出すファイル
      "../../../../../../verification/AudioCleanUp/output/audio_clean_up_case1.csv",
      // golden 側 (C++ or Python で作った S16 CSV)
      "../../../../../../verification/AudioCleanUp/output/audio_clean_up_case1_cpp.csv"
    );
end

final begin
    csv_output_close(max_abs_diff, mismatch_cnt);
    $display("[CMP] max_abs_diff=%0d, mismatch_cnt=%0d", max_abs_diff, mismatch_cnt);
    // 許容誤差 ±1 LSB 以内なら OK とする
    if (max_abs_diff > 1) begin
        $error("[CMP] Max abs diff > 1 LSB");
    end
end

// シミュレーション開始
initial begin
    aresetn = 0;
    repeat(10) @(posedge aclk);
    aresetn = 1;

    // AXI VIP master インスタンス作成
    axi_i2s_mst = new("axi_i2s_mst", dut.axi_vip_0.inst.IF);
    axi_i2s_mst.start_master();

    axi_acu_mst = new("axi_acu_mst", dut.axi_vip_1.inst.IF);
    axi_acu_mst.start_master();

    axistream_slv = new("axistream_slv", dut.axi4stream_vip_0.inst.IF);
    axistream_slv.start_slave();

    // 出力監視を並列で開始
    fork
      monitor_acu_output();
    join_none

    repeat(5) @(posedge aclk);

    // I2Sのレジスタ設定
    axi_i2s_write(32'h30, 32'h0000_0001); // enable MCLK gen
    axi_i2s_write(32'h20, 32'h0000_0004); // SCK divider
    axi_i2s_write(32'h08, 32'h0000_0001); // I2S RX enable

    repeat(5) @(posedge aclk);

    // ACUのレジスタ設定
    program_audio_cleanup();

    repeat(5) @(posedge aclk);

    // CSV 入力が終わるまで待つ
    wait (src.eof == 1'b1);

    // パイプラインが抜け切るのを少し待つ
    repeat (2000) @(posedge aclk);  // 100MHz × 2000 ≒ 20us

    $display("All CSV samples consumed. Finish simulation.");
    $finish;
end

task automatic monitor_acu_output();
    logic [31:0]             tdata_word;
    shortint                 sample_q15;
    xil_axi4stream_data_byte data_bytes[4];
    int                      ch_idx = 0;

    forever begin
        // AXI Stream の 1 トランザクション取得
        axistream_slv.monitor.item_collected_port.get(mon_tr);

        mon_tr.get_data(data_bytes);
        tdata_word = { data_bytes[3], data_bytes[2], data_bytes[1], data_bytes[0] };

        // Q15 を取り出す
        sample_q15 = shortint'(tdata_word[27:12]);

        // Left チャンネルのみ書き出し
        if (ch_idx == 0) begin
            csv_output_write_q15(sample_q15);
        end

        ch_idx ^= 1;
      end
endtask

// 32bit write helper
task axi_i2s_write(input logic [31:0] offset, input logic [31:0] data);
    axi_i2s_mst.AXI4LITE_WRITE_BURST(I2S_RX_BASE + offset, 0, data, resp);
endtask

task axi_acu_write(input logic [31:0] offset, input logic [31:0] data);
    axi_acu_mst.AXI4LITE_WRITE_BURST(ACU_BASE + offset, 0, data, resp);
endtask

// Audio Clean Up IP のレジスタ初期化（ここはそのまま）
task automatic program_audio_cleanup();
    // DCカット
    axi_acu_write(32'h10, 32'h3F7F54A7);
    axi_acu_write(32'h18, 32'h00000000);  // dc_pass = 1 (バイパス)

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
    axi_acu_write(32'h58, 32'h00000000);  // ng_pass = 1 (バイパス)

    // 制御系
    axi_acu_write(32'h00, 32'h00000081);  // ap_start + auto_restart
endtask

endmodule
