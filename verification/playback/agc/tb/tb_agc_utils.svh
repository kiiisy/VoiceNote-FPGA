// ------------------------------------------------------------
// シナリオ開始処理
// ------------------------------------------------------------
task automatic scenario_begin(input string name);
    r_scenario_fail_cnt = 0;
    r_scenario_pass = 1'b0;
    r_scenario_name = name;
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
// 条件チェック
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
// UART距離設定
// ------------------------------------------------------------
task automatic set_uart_distance_mm(input logic [15:0] dist_mm);
    r_dist_mm_cfg = dist_mm;
    $display("[TB] UART dist_mm = %0d", dist_mm);
endtask

// ------------------------------------------------------------
// UARTプリロール待機
// ------------------------------------------------------------
task automatic wait_uart_preroll();
    $display("[TB] Wait UART preroll frames ...");
    repeat (UART_PREROLL_CLKS) @(posedge aclk);
    $display("[TB] UART preroll done. Start audio stream.");
endtask

// ------------------------------------------------------------
// 入力CSV送信
// ------------------------------------------------------------
task automatic drive_input_from_csv();
    shortint sample_q15;
    int      ok;
    xil_axi4stream_data_byte data_bytes[4];
    logic [31:0] tdata_word;
    int ch;
    int sample_wait_clks;
    int rem_accum;

    csv_init(INPUT_CSV_PATH);
    rem_accum = 0;

    forever begin
        ok = csv_next_sample_q15(sample_q15);
        if (!ok) begin
            $display("[TB] CSV EOF reached.");
            break;
        end

        tdata_word        = 32'd0;
        tdata_word[27:12] = sample_q15[15:0];

        for (ch = 0; ch < 2; ch++) begin
            axis_tr = axis_src_mst.driver.create_transaction($sformatf("tr_ch%0d", ch));
            data_bytes[0] = tdata_word[7:0];
            data_bytes[1] = tdata_word[15:8];
            data_bytes[2] = tdata_word[23:16];
            data_bytes[3] = tdata_word[31:24];
            axis_tr.set_data(data_bytes);
            axis_tr.set_id(ch);
            axis_src_mst.driver.send(axis_tr);
        end

        sample_wait_clks = (AUDIO_SAMPLE_CLKS > 0) ? AUDIO_SAMPLE_CLKS : 1;
        rem_accum = rem_accum + AUDIO_SAMPLE_REM_CLKS;
        if (rem_accum >= AUDIO_SAMPLE_RATE_HZ) begin
            sample_wait_clks = sample_wait_clks + 1;
            rem_accum = rem_accum - AUDIO_SAMPLE_RATE_HZ;
        end
        repeat (sample_wait_clks) @(posedge aclk);
    end
endtask
