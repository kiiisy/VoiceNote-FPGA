`timescale 1ns/1ps

import csv_pkg::*;

module i2s_input_dpi #(
    string CSV_PATH = "../../../../verification/AudioCleanUp/input/audio_clean_up_case1_input.csv"
) (
    input  logic sclk,      // I2S RX の sclk_out
    input  logic lrclk,     // I2S RX の lrclk_out (0: L, 1: R 想定)
    input  logic rstn,      // aresetn (1:動作, 0:リセット)
    output logic sdata,
    output logic eof        // CSV 読み終わりフラグ
);

shortint     cur_sample;     // 現ステレオフレームで使う値（L/R共通）
logic [15:0] shift_reg;
logic [4:0]  bit_idx;
logic        lrclk_d;
int          valid;

// 初期化時に CSV を開く
initial begin
  $display("start i2s_input_dpi, path=%s", CSV_PATH);
  csv_init(CSV_PATH);
end

  // LRCLK エッジで新しいサンプルを獲得
  //   - R(1)→L(0) のエッジを「新しいステレオフレーム開始」とみなす
  //   - そのとき CSV から 1 行読み込み → L/R 共通で使用
  always_ff @(posedge sclk or negedge rstn) begin
    if (!rstn) begin
      lrclk_d    <= 1'b0;
      bit_idx    <= 5'd0;
      shift_reg  <= 16'h0000;
      cur_sample <= 16'sh0000;
      eof        <= 1'b0;
    end else begin
      lrclk_d <= lrclk;

      if (lrclk != lrclk_d) begin
        // ---- LRCLK エッジ ----
        shortint new_sample;

        // R(1) → L(0) で「新しいステレオフレーム開始」
        if (lrclk_d == 1'b1 && lrclk == 1'b0) begin
          valid = csv_next_sample_q15(new_sample);

          if (!valid) begin
            eof        <= 1'b1;
            new_sample = 16'sh0000;   // EOF後は0を流す
          end
          cur_sample <= new_sample;   // 次以降用に保存
          shift_reg  <= new_sample[15:0];  // ★ この L フレームはすぐに new_sample を使う
        end else begin
          // L→R エッジ（R チャンネル開始）は、同じ cur_sample を使うだけ
          shift_reg <= cur_sample[15:0];
        end

        bit_idx <= 5'd0;   // 新しいチャネル開始なのでビット位置リセット
      end else begin
        // チャネル内：ビット位置を進める
        if (bit_idx != 5'd15)
          bit_idx <= bit_idx + 5'd1;
      end
    end
  end

// sdata 出力 (MSB → LSB)
always_ff @(negedge sclk or negedge rstn) begin
  if (!rstn) begin
    sdata <= 1'b0;
  end else begin
    sdata <= shift_reg[15 - bit_idx];
  end
end

endmodule
