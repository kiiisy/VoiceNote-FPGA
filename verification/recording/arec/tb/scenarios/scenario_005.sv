`timescale 1ns/1ps

`define TB $root.tb_top

module scenario_005;
    // ------------------------------------------------------------
    // scenario_005
    // 内容：高しきい値で非トリガ(未DUMP)とIRQ非発行を確認する
    // ------------------------------------------------------------
    task automatic run();
        logic [2:0] state_reg_now;

        `TB.scenario_begin("scenario_005");

        // no trigger
        `TB.set_arec_trigger_recording_cfg_reg(16'h7fff, 5'd6, 12'd512, 4'd2);

        wait (`TB.src.eof == 1'b1);

        `TB.axi_arec_read(32'h04, `TB.arec_rdata);
        state_reg_now = `TB.arec_rdata[18:16];
        `TB.scenario_expect((state_reg_now != 3'b010), "unexpected DUMP state");
        `TB.scenario_expect((`TB.irq !== 1'b1), "unexpected irq assertion");

        `TB.scenario_end();
    endtask
`undef TB

endmodule
