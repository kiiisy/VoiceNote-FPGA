`timescale 1ns/1ps

module uart_tx_model #(
    parameter int CLK_FREQ_HZ        = 100_000_000,
    parameter int BAUD_RATE          = 115_200,
    parameter int FRAME_INTERVAL_CLKS= 400_000,     // 4ms @100MHz
    parameter      [15:0] DIST_MM    = 16'd1000     // 1.0m
)(
    input  wire clk,
    input  wire rst_n,
    output reg  rx    // DUT 側から見た UART RX
);

    localparam int BAUD_DIV = CLK_FREQ_HZ / BAUD_RATE; // ≒868

    // 簡易フレーム:
    // [0] 0x59
    // [1] 0x59
    // [2] Dist_L
    // [3] Dist_H
    // [4] Amp_L (0)
    // [5] Amp_H (0)
    // [6] Temp_L (0)
    // [7] Temp_H (0)
    // [8] Checksum = sum(0..7) の下位8bit
    byte frame[0:8];

    // ビット送信用タスク
    task automatic send_byte(input byte b);
        int i;
        begin
            // Start bit (0)
            rx <= 1'b0;
            repeat (BAUD_DIV) @(posedge clk);

            // Data bits (LSB first)
            for (i = 0; i < 8; i++) begin
                rx <= b[i];
                repeat (BAUD_DIV) @(posedge clk);
            end

            // Stop bit (1)
            rx <= 1'b1;
            repeat (BAUD_DIV) @(posedge clk);
        end
    endtask

    // フレーム送信用タスク
    task automatic send_frame();
        int i;
        byte checksum;
        begin
            // フレーム内容構成
            frame[0] = 8'h59;
            frame[1] = 8'h59;
            frame[2] = DIST_MM[7:0];   // Dist_L
            frame[3] = DIST_MM[15:8];  // Dist_H
            frame[4] = 8'h00;          // Amp_L
            frame[5] = 8'h00;          // Amp_H
            frame[6] = 8'h00;          // Temp_L
            frame[7] = 8'h00;          // Temp_H

            checksum = 8'd0;
            for (i = 0; i <= 7; i++) begin
                checksum = checksum + frame[i];
            end
            frame[8] = checksum;

            // 9バイト送信
            for (i = 0; i <= 8; i++) begin
                send_byte(frame[i]);
            end
        end
    endtask

    // メインシーケンス
    initial begin
        rx = 1'b1; // idle

        // リセット解除待ち
        wait (rst_n == 1'b1);

        // 少し待ってから測距開始
        repeat (100) @(posedge clk);

        forever begin
            repeat (FRAME_INTERVAL_CLKS) @(posedge clk);
            send_frame();
            // フレーム間隔
        end
    end

endmodule
