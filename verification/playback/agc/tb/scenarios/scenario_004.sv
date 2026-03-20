`timescale 1ns/1ps

`define TB $root.tb_agc_top

module playback_scenario_004;
    // ------------------------------------------------------------
    // scenario_004
    // 内容：manual gain モードで固定ゲインを与え、手動設定値どおりに出力されることを確認する
    // ------------------------------------------------------------
    task automatic run();
        `TB.scenario_begin("scenario_004");

        `TB.set_agc_reg(
            32'h0000_0001, // manual mode
            32'h0000_2000,
            32'h0000_6000, // 1.5x
            32'h0000_2000,
            32'h0000_7FFF,
            32'h0000_0006
        );
        `TB.set_uart_distance_mm(16'd1500);
        `TB.wait_uart_preroll();

        `TB.drive_input_from_csv();

        repeat (`TB.POST_FLUSH_CYCLES) @(posedge `TB.aclk);

        `TB.scenario_end();
    endtask
endmodule

`undef TB
