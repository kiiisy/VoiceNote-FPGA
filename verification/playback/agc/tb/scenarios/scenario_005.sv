`timescale 1ns/1ps

`define TB $root.tb_agc_top

module playback_scenario_005;
    // ------------------------------------------------------------
    // scenario_005
    // 内容：gain_max 制限を設け、目標gainより高い値へ張り付かないことを確認する
    // ------------------------------------------------------------
    task automatic run();
        `TB.scenario_begin("scenario_005");

        `TB.set_agc_reg(
            32'h0000_0000, // auto mode
            32'h0000_0000, // 常に距離更新を反映
            32'h0000_0000,
            32'h0000_2000,
            32'h0000_5000, // 1.25x に制限
            32'h0000_0002
        );
        `TB.set_uart_distance_mm(16'd2000);
        `TB.wait_uart_preroll();

        `TB.drive_input_from_csv();

        repeat (`TB.POST_FLUSH_CYCLES) @(posedge `TB.aclk);

        `TB.scenario_end();
    endtask
endmodule

`undef TB
