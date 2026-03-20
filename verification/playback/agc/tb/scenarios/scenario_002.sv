`timescale 1ns/1ps

`define TB $root.tb_agc_top

module playback_scenario_002;
    // ------------------------------------------------------------
    // scenario_002
    // 内容：固定距離で gain up 方向に更新し、出力が入力より大きくなることを確認する
    // ------------------------------------------------------------
    task automatic run();
        `TB.scenario_begin("scenario_002");

        `TB.set_agc_reg(
            32'h0000_0000, // auto mode
            32'h0000_0000, // 常に距離更新を反映
            32'h0000_0000,
            32'h0000_2000,
            32'h0000_7FFF,
            32'h0000_0002  // 速めに追従
        );
        `TB.set_uart_distance_mm(16'd1500);
        `TB.wait_uart_preroll();

        `TB.drive_input_from_csv();

        repeat (`TB.POST_FLUSH_CYCLES) @(posedge `TB.aclk);

        `TB.scenario_end();
    endtask
endmodule

`undef TB
