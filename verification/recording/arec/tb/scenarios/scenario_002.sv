`timescale 1ns/1ps

`define TB $root.tb_top

module scenario_002;
    // ------------------------------------------------------------
    // scenario_002
    // 内容：トリガ発火でDUMP遷移し、IRQ発行/クリアとPASS復帰を確認する
    // ------------------------------------------------------------
    task automatic run();
        `TB.scenario_begin("scenario_002");

        // DUMP + IRQ
        `TB.set_arec_trigger_recording_cfg_reg(16'h0300, 5'd6, 12'd512, 4'd2);
        `TB.wait_irq_assert();
        `TB.clear_irq_w1c();
        `TB.scenario_expect((`TB.irq === 1'b0), "irq clear failed");
        `TB.wait_until_arec_pass_state();

        wait (`TB.src.eof == 1'b1);

        `TB.scenario_end();
    endtask
`undef TB

endmodule
