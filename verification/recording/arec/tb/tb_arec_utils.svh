// ------------------------------------------------------------
// シナリオ開始処理
// ------------------------------------------------------------
task automatic scenario_begin(input string name);
    r_scenario_name = name;
    r_scenario_fail_cnt = 0;
    r_scenario_pass = 1'b0;
    $display("[SCENARIO][BEGIN] %s", name);
endtask

// ------------------------------------------------------------
// シナリオ失敗記録
// ------------------------------------------------------------
task automatic scenario_fail(input string msg);
    r_scenario_fail_cnt = r_scenario_fail_cnt + 1;
    $error("[SCENARIO][FAIL] %s", msg);
endtask

// ------------------------------------------------------------
// 条件チェック（失敗時にシナリオ失敗化）
// ------------------------------------------------------------
task automatic scenario_expect(input bit cond, input string msg);
    if (!cond) begin
        scenario_fail(msg);
    end
endtask

// ------------------------------------------------------------
// シナリオ終了処理
// ------------------------------------------------------------
task automatic scenario_end();
    r_scenario_pass = (r_scenario_fail_cnt == 0);
    $display("[SCENARIO][END] %s result=%s fail_cnt=%0d",
             r_scenario_name, r_scenario_pass ? "PASS" : "FAIL", r_scenario_fail_cnt);
endtask

// ------------------------------------------------------------
// IRQアサート待ち
// ------------------------------------------------------------
task automatic wait_irq_assert();
    int unsigned timeout_cycles;
    timeout_cycles = 0;
    while (timeout_cycles < IRQ_TIMEOUT_CYCLES) begin
        if (irq === 1'b1) begin
            $display("[AREC] irq asserted");
            return;
        end
        @(posedge aclk);
        timeout_cycles++;
    end
    scenario_fail("timeout waiting irq assert");
endtask

// ------------------------------------------------------------
// IRQクリア（W1C）
// ------------------------------------------------------------
task automatic clear_irq_w1c();
    // CONTROL[0]=enableを維持したまま bit1=1 を書く
    axi_arec_write(32'h00, 32'h00000003);
    @(posedge aclk);
    axi_arec_write(32'h00, 32'h00000001);
endtask

// ------------------------------------------------------------
// 一定期間DUMPに入らないことを確認
// ------------------------------------------------------------
task automatic check_no_dump_in_window();
    int unsigned c;
    logic [2:0] state_reg_now;
    for (c = 0; c < NO_DUMP_OBS_CYCLES; c++) begin
        if ((c % AREC_PASS_POLL_CYCLES) == 0) begin
            axi_arec_read(32'h04, arec_rdata);
            state_reg_now = arec_rdata[18:16];
            if (state_reg_now == 3'b010) begin
                scenario_fail("unexpected DUMP detected in no-dump window");
                return;
            end
        end
        @(posedge aclk);
    end
endtask

// ------------------------------------------------------------
// ARECがPASS状態へ戻るまで待機
// ------------------------------------------------------------
task automatic wait_until_arec_pass_state();
    int unsigned timeout_cycles;
    logic [2:0] state_reg_now;

    timeout_cycles = 0;
    while (timeout_cycles < AREC_PASS_TIMEOUT_CYCLES) begin
        axi_arec_read(32'h04, arec_rdata);  // reg1: status/state
        state_reg_now = arec_rdata[18:16];
        if (state_reg_now == 3'b000) begin
            $display("[AREC] returned to PASS. rdata=0x%08h", arec_rdata);
            return;
        end
        repeat (AREC_PASS_POLL_CYCLES) @(posedge aclk);
        timeout_cycles = timeout_cycles + AREC_PASS_POLL_CYCLES;
    end
    scenario_fail($sformatf("timeout waiting for PASS. last rdata=0x%08h", arec_rdata));
endtask
