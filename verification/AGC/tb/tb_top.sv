`timescale 1ns/1ps

import axi_vip_pkg::*;
import axi4stream_vip_pkg::*;
import playback_test_axi_vip_0_0_pkg::*;
import playback_test_axi4stream_vip_0_0_pkg::*;
import playback_test_axi4stream_vip_1_0_pkg::*;
import csv_pkg::*;

module tb_playback;

    localparam int CLK_FREQ_HZ         = 100_000_000;
    localparam int BAUD_RATE           = 115_200;
    localparam int BAUD_DIV            = CLK_FREQ_HZ / BAUD_RATE;  // ≒868
    localparam int UART_BITS_PER_BYTE  = 10;   // Start + 8bit + Stop
    localparam int UART_BYTES_PER_FRAME= 9;
    localparam int UART_FRAME_CLKS     = BAUD_DIV * UART_BITS_PER_BYTE * UART_BYTES_PER_FRAME;
    // uart_tx_model と同じ値にしておく
    localparam int FRAME_INTERVAL_CLKS = 400_000; // 4ms
    localparam int UART_WAIT_FRAMES    = 1;       // 3フレームぶん待つ
    localparam int UART_PREROLL_CLKS   = UART_WAIT_FRAMES * (UART_FRAME_CLKS + FRAME_INTERVAL_CLKS);

  // ------------------------------------------------------------
  // クロック / リセット / UART
  // ------------------------------------------------------------
  logic aclk    = 0;
  logic aresetn = 0;
  logic rx;  // ToF → DUT(UART RX)

  always #5 aclk = ~aclk; // 100MHz

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

  // AXI-Lite Master（AGCレジスタ書き込み用）
  // ※型名はパッケージに合わせて
  playback_test_axi_vip_0_0_mst_t        axi_agc_mst;

  // AXIS Master（calculation への入力ストリーム）
  playback_test_axi4stream_vip_0_0_mst_t axis_src_mst;

  // AXIS Slave（calculation からの出力ストリーム）
  playback_test_axi4stream_vip_1_0_slv_t axis_sink_slv;

  axi4stream_transaction         axis_tr;
  axi4stream_monitor_transaction mon_tr;

  // AXI-Lite 応答
  logic resp;

  // ベースアドレス（BD で割り当てた値に合わせて変更）
  localparam AGC_BASE = 32'h44A0_0000;

  // CSV比較用
  int max_abs_diff;
  int mismatch_cnt;

  // ------------------------------------------------------------
  // UART ToF モデル
  //   - 100MHz / 115200bps / 8N1
  //   - 4msごとに同じ距離(dmm)を投げる簡易モデル
  // ------------------------------------------------------------
  uart_tx_model #(
    .CLK_FREQ_HZ  (100_000_000),
    .BAUD_RATE    (115_200),
    .DIST_MM      (16'd1500),       // 1.0m 固定（必要なら後で変える）
    .FRAME_INTERVAL_CLKS(321_880)   // 4ms 間隔 400_000 - 78_120
  ) U_uart_tx_model (
    .clk   (aclk),
    .rst_n (aresetn),
    .rx    (rx)
  );

  // ------------------------------------------------------------
  // CSV 出力の初期化
  // ------------------------------------------------------------
  initial begin
    csv_output_init(
      // HW 出力を書き出す CSV
      "../../../../../../verification/AGC/output/playback_case1_hw.csv",
      // golden 側 (AGC適用後S16の期待値)
      "../../../../../../verification/AGC/output/playback_case1_golden.csv"
    );
  end

  final begin
    csv_output_close(max_abs_diff, mismatch_cnt);
    $display("[CMP] max_abs_diff=%0d, mismatch_cnt=%0d",
             max_abs_diff, mismatch_cnt);
    if (max_abs_diff > 1) begin
      $error("[CMP] Max abs diff > 1 LSB");
    end
  end

  // ------------------------------------------------------------
  // シミュレーション本体
  // ------------------------------------------------------------
  initial begin
    aresetn = 0;
    rx      = 1'b1; // UART idle 高
    repeat (20) @(posedge aclk);
    aresetn = 1;

    // AXI VIP インスタンス生成 & 起動
    axi_agc_mst   = new("axi_agc_mst",   dut.axi_vip_0.inst.IF);
    axis_src_mst  = new("axis_src_mst",  dut.axi4stream_vip_0.inst.IF);
    axis_sink_slv = new("axis_sink_slv", dut.axi4stream_vip_1.inst.IF);

    axi_agc_mst.start_master();
    axis_src_mst.start_master();
    axis_sink_slv.start_slave();

    // 出力監視を並列で開始
    fork
      monitor_output();
    join_none

    repeat (10) @(posedge aclk);

    // AGC IP のレジスタ初期化（AXI-Lite）
    program_agc();

    //repeat (5) @(posedge aclk);
    repeat (399_314) @(posedge aclk);

    // 入力 CSV を AXIS で流し込む
    drive_input_from_csv();

    $display("[TB] Wait UART preroll frames ...");
    repeat (UART_PREROLL_CLKS) @(posedge aclk);
    $display("[TB] UART preroll done. Start audio stream.");

    // 送信終了後、パイプラインが抜け切るのを少し待つ
    repeat (20000) @(posedge aclk);

    $display("All CSV samples consumed. Finish simulation.");
    $finish;
  end

  // ============================================================
  // AXI-Lite write helper
  // ============================================================
  task automatic axi_agc_write(input logic [31:0] offset,
                               input logic [31:0] data);
    axi_agc_mst.AXI4LITE_WRITE_BURST(AGC_BASE + offset, 0, data, resp);
  endtask

  // ============================================================
  // AGC IP のレジスタ初期化
  //   ※オフセットや値は実際のレジスタマップに合わせて変更してください
  // ============================================================
  task automatic program_agc();
    // ゲイン上下限 (Q2.14)
    axi_agc_write(32'h20, 32'h00002000); // min_gain = 0.5 → 0x2000
    axi_agc_write(32'h24, 32'h00007FFF); // max_gain = 1.9 → 0x7FFF

    // α = 1/64 → shift=6
    axi_agc_write(32'h28, 32'h00000006);

    // 感度 (mm) 例: 50mm
    //axi_agc_write(32'h10, 32'h00000032);
    axi_agc_write(32'h10, 32'h00000000);

    axi_agc_write(32'h00, 32'h00000000);
  endtask

    // ============================================================
    // 入力 CSV → AXIS Master 送出 (モノラルCSV→ステレオAXIS: L/R同じ)
    // ============================================================
    task automatic drive_input_from_csv();
        string   csv_path;
        shortint sample_q15;
        int      ok;
        xil_axi4stream_data_byte data_bytes[4];
        logic [31:0] tdata_word;
        int ch;

        csv_path = "../../../../../../verification/AGC/input/playback_case1_input.csv";
        csv_init(csv_path);

        forever begin
            ok = csv_next_sample_q15(sample_q15);
            if (!ok) begin
                $display("[TB] CSV EOF reached.");
                break;
            end

            // tdata[27:12] に Q15 サンプルを格納
            tdata_word        = 32'd0;
            tdata_word[27:12] = sample_q15[15:0];

            // ---- ここがポイント：L(0)とR(1)を2回送る ----
            for (ch = 0; ch < 2; ch++) begin
                axis_tr = axis_src_mst.driver.create_transaction($sformatf("tr_ch%d", ch));

                // 32bit → byte[4] へ (LSB→MSB)
                data_bytes[0] = tdata_word[7:0];
                data_bytes[1] = tdata_word[15:8];
                data_bytes[2] = tdata_word[23:16];
                data_bytes[3] = tdata_word[31:24];

                axis_tr.set_data(data_bytes);
                axis_tr.set_id(ch);  // 0=Left, 1=Right

                axis_src_mst.driver.send(axis_tr);
            end
        end
    endtask

  // ============================================================
  // 出力 AXIS を監視して CSV に書き出し＆比較
  // ============================================================
  task automatic monitor_output();
    xil_axi4stream_data_byte data_bytes[4];
    logic [31:0]             tdata_word;
    shortint                 sample_q15;
    int                      ch_idx = 0;

    forever begin
      axis_sink_slv.monitor.item_collected_port.get(mon_tr);

      mon_tr.get_data(data_bytes);
      tdata_word = { data_bytes[3], data_bytes[2], data_bytes[1], data_bytes[0] };

      // 出力も [27:12] を Q15 として解釈
      sample_q15 = shortint'(tdata_word[27:12]);

      // Left チャンネルのみ CSV 出力
      if (ch_idx == 0) begin
        csv_output_write_q15(sample_q15);
      end

      ch_idx ^= 1;
    end
  endtask

endmodule
