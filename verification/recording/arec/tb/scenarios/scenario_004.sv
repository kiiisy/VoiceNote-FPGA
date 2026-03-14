`timescale 1ns/1ps

`define TB $root.tb_top

module scenario_004;
    // ------------------------------------------------------------
    // scenario_004
    // 内容：一度DUMP後、再DUMP抑止とenable再投入での再アーム動作を確認する
    // ------------------------------------------------------------
    task automatic run();
        logic [2:0] state_reg_now;

        `TB.scenario_begin("scenario_004");

        // re-arm
        `TB.set_arec_trigger_recording_cfg_reg(16'h0300, 5'd6, 12'd512, 4'd2);
        `TB.wait_irq_assert();
        if (`TB.r_scenario_fail_cnt != 0) begin
            `TB.scenario_end();
            return;
        end
        `TB.clear_irq_w1c();
        `TB.scenario_expect((`TB.irq === 1'b0), "irq clear failed");
        `TB.wait_until_arec_pass_state();

        // enable=1維持のままは再DUMPしないことを確認
        `TB.check_no_dump_in_window();

        // enableを落として再アーム解除
        `TB.axi_arec_write(32'h00, 32'h00000000);
        repeat (20) @(posedge `TB.aclk);
        `TB.axi_arec_write(32'h00, 32'h00000001);

        // 少なくともARMEDに戻ることを確認
        repeat (`TB.AREC_PASS_POLL_CYCLES) @(posedge `TB.aclk);
        `TB.axi_arec_read(32'h04, `TB.arec_rdata);
        state_reg_now = `TB.arec_rdata[18:16];
        `TB.scenario_expect((state_reg_now == 3'b001),
                                     $sformatf("expected ARMED after re-enable, got state=%0d", state_reg_now));

        wait (`TB.src.eof == 1'b1);

        `TB.scenario_end();
    endtask
`undef TB

endmodule
