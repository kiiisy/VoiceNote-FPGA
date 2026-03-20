`timescale 1ns/1ps

`define TB $root.tb_agc_top

module playback_scenario_001;
    // ------------------------------------------------------------
    // scenario_001
    // 内容：距離更新を実質止め、入力と出力がほぼ一致することを確認する
    // ------------------------------------------------------------
    task automatic run();
        `TB.scenario_begin("scenario_001");

        `TB.set_agc_default_reg();
        `TB.set_uart_distance_mm(16'd1500);
        `TB.wait_uart_preroll();

        `TB.drive_input_from_csv();

        repeat (`TB.POST_FLUSH_CYCLES) @(posedge `TB.aclk);

        `TB.scenario_end();
    endtask
endmodule

`undef TB
