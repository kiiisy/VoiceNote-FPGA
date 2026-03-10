`timescale 1ns/1ps

`define TB $root.tb_top

module scenario_001;
    // ------------------------------------------------------------
    // scenario_001
    // 内容：AREC無効(PASS-through)で、入力と出力のCSV一致を確認する
    // ------------------------------------------------------------
    task automatic run();
        `TB.scenario_begin("scenario_001");

        // PASS-through
        `TB.set_arec_passthrough_reg();

        // 入力終了まで待機
        wait (`TB.src.eof == 1'b1);

        `TB.scenario_end();
    endtask
`undef TB

endmodule
