module arec_core #(
    parameter integer C_S00_AXI_DATA_WIDTH = 32
)(
    input  wire clk,
    input  wire reset,

    // AXI-Stream Slave
    input  wire [C_S00_AXI_DATA_WIDTH-1:0] s00_axis_tdata,
    input  wire                            s00_axis_tvalid,
    output wire                            s00_axis_tready,
    input  wire [2:0]                      s00_axis_tid,

    // AXI-Stream Master
    output wire [C_S00_AXI_DATA_WIDTH-1:0] m00_axis_tdata,
    output wire                            m00_axis_tvalid,
    input  wire                            m00_axis_tready,
    output wire [2:0]                      m00_axis_tid,

    // registers
    input  wire [C_S00_AXI_DATA_WIDTH-1:0] control_reg,
    input  wire [C_S00_AXI_DATA_WIDTH-1:0] threshold_reg,
    input  wire [C_S00_AXI_DATA_WIDTH-1:0] window_samples_reg,
    input  wire [C_S00_AXI_DATA_WIDTH-1:0] required_windows_reg,
    input  wire [C_S00_AXI_DATA_WIDTH-1:0] pretrig_samples_reg,
    input  wire                            irq_clear,
    output wire [15:0]                     status_reg,
    output wire [2:0]                      state_reg,
    output wire                            irq
);
    // -------------------------------
    // 内部信号
    // -------------------------------
    wire [1:0] w_state;
    wire       w_i2s_tready;
    wire       w_en_stream2data;
    wire       w_en_wr;
    wire       w_en_rd;
    wire       w_start_dump;
    wire       w_cap_start_ptr;
    wire       w_is_dump;
    wire       w_dump_done;

    wire               w_sample_stb;
    wire signed [15:0] w_sample16_data;
    wire [35:0]        w_packed_data;
    wire               w_trigger;
    wire               w_triggered_latched;
    wire               w_mon_sample_stb;
    wire               w_dump_start_ok;
    wire [11:0]        w_dump_len_raw;
    wire [11:0]        w_dump_len;
    wire               w_pretrig_ready;
    reg  [11:0]        r_armed_sample_cnt;

    wire [35:0] w_dump_packed;
    wire        w_dump_packed_valid;
    wire        w_dump_packed_ready;

    wire [31:0] w_dump_tdata;
    wire        w_dump_tvalid;
    wire [2:0]  w_dump_tid;
    wire        w_dump_tready;
    reg         r_dump_sel;
    wire        w_dump_sel_next;
    wire        w_is_pass;

    // 監視対象サンプルの有効ストローブ
    assign w_mon_sample_stb = w_sample_stb & w_en_stream2data;

    // DUMP開始
    assign w_dump_start_ok  = w_sample_stb && (s00_axis_tid == 3'd1);

    // dump中ははレジスタ保持し、dumpデータが空になるまでPASSへ戻さない
    assign w_dump_sel_next  = w_is_dump ? 1'b1 :
                              (r_dump_sel && w_dump_tvalid) ? 1'b1 :
                              1'b0;
    // DUMP経路のtready
    assign w_dump_tready = m00_axis_tready & r_dump_sel;

    // レジスタ値の有効範囲ガード（0→1、最大2048）
    assign w_dump_len_raw = (pretrig_samples_reg[11:0] == 12'd0)   ? 12'd1 :
                            (pretrig_samples_reg[11:0] > 12'd2048) ? 12'd2048 :
                                                                     pretrig_samples_reg[11:0];
    // dump長を偶数に補正（L/Rペア分断防止のため）
    assign w_dump_len = w_dump_len_raw[0] ?
                        ((w_dump_len_raw == 12'd1) ? 12'd2 : (w_dump_len_raw - 12'd1)) :
                                                             w_dump_len_raw;

    // -------------------------------
    // ARMED中のサンプルカウント
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_armed_sample_cnt <= 12'd0;
        end else begin
            if (!control_reg[0]) begin
                r_armed_sample_cnt <= 12'd0;
            end else if (w_en_stream2data && w_sample_stb && !w_pretrig_ready) begin
                r_armed_sample_cnt <= r_armed_sample_cnt + 12'd1;
            end else begin
                r_armed_sample_cnt <= r_armed_sample_cnt;
            end
        end
    end

    assign w_pretrig_ready = (r_armed_sample_cnt >= w_dump_len);

    // -------------------------------
    // サブモジュール
    // -------------------------------
    core_ctrl U_core_ctrl(
        .clk            (clk),               // in
        .reset          (reset),             // in
        .enable         (control_reg[0]),    // in
        .irq_clear      (irq_clear),         // in
        .trigger        (w_trigger),         // in
        .pretrig_ready  (w_pretrig_ready),   // in
        .dump_start_ok  (w_dump_start_ok),   // in
        .dump_done      (w_dump_done),       // in
        .af_tready      (m00_axis_tready),   // in
        .state_reg      (w_state),           // out
        .irq            (irq),               // out
        .i2s_tready     (w_i2s_tready),      // out
        .en_stream2data (w_en_stream2data),  // out
        .en_wr          (w_en_wr),           // out
        .en_rd          (w_en_rd),           // out
        .start_dump     (w_start_dump),      // out
        .cap_start_ptr  (w_cap_start_ptr),   // out
        .is_dump        (w_is_dump)          // out
    );

    stream2data U_stream2data(
        .clk           (clk),                // in
        .reset         (reset),              // in
        .s_axis_tdata  (s00_axis_tdata),     // in
        .s_axis_tvalid (s00_axis_tvalid),    // in
        .s_axis_tready (s00_axis_tready),    // in
        .s_axis_tid    (s00_axis_tid),       // in
        .sample_stb    (w_sample_stb),       // out
        .packed_data   (w_packed_data),      // out
        .sample16_data (w_sample16_data)     // out
    );

    window_detector U_window_detector(
        .clk                 (clk),                        // in
        .reset               (reset),                      // in
        .enable              (control_reg[0]),             // in
        .window_shift_reg    (window_samples_reg[4:0]),    // in
        .required_windows_reg(required_windows_reg[3:0]),  // in
        .threshold_reg       (threshold_reg[15:0]),        // in
        .sample_stb          (w_mon_sample_stb),           // in
        .sample16            (w_sample16_data),            // in
        .trigger_pulse       (w_trigger),                  // out
        .triggered_latched   (w_triggered_latched)         // out
    );

    bram_ctrl #(
        .DEPTH (2048),
        .WIDTH (36)
    ) U_bram_ctrl (
        .clk           (clk),                  // in
        .reset         (reset),                // in
        .wr_en         (w_en_wr),              // in
        .in_valid      (w_mon_sample_stb),     // in
        .in_ready      (/* not use */),        // out
        .in_packed     (w_packed_data),        // in
        .rd_en         (w_en_rd),              // in
        .start_dump    (w_start_dump),         // in
        .cap_start_ptr (w_cap_start_ptr),      // in
        .dump_len      (w_dump_len),           // in
        .dump_done     (w_dump_done),          // out
        .out_packed    (w_dump_packed),        // out
        .out_valid     (w_dump_packed_valid),  // out
        .out_ready     (w_dump_packed_ready)   // in
    );

    data2stream U_data2stream(
        .clk          (clk),                 // in
        .reset        (reset),               // in
        .en           (r_dump_sel),          // in
        .in_packed    (w_dump_packed),       // in
        .in_valid     (w_dump_packed_valid), // in
        .in_ready     (w_dump_packed_ready), // out
        .m_axis_tdata (w_dump_tdata),        // out
        .m_axis_tvalid(w_dump_tvalid),       // out
        .m_axis_tready(w_dump_tready),       // in
        .m_axis_tid   (w_dump_tid)           // out
    );

    // -------------------------------
    // dump/pass出力切替の保持
    // -------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_dump_sel <= 1'b0;
        end else begin
            r_dump_sel <= w_dump_sel_next;
        end
    end

    // -------------------------------
    // 出力MUX
    // -------------------------------
    assign w_is_pass = (w_state == 2'd0);

    assign s00_axis_tready = w_i2s_tready;

    assign m00_axis_tdata  = r_dump_sel ? w_dump_tdata  :
                             w_is_pass ? s00_axis_tdata : {C_S00_AXI_DATA_WIDTH{1'b0}};
    assign m00_axis_tvalid = r_dump_sel ? w_dump_tvalid :
                             w_is_pass ? s00_axis_tvalid : 1'b0;
    assign m00_axis_tid    = r_dump_sel ? w_dump_tid    :
                             w_is_pass ? s00_axis_tid   : 3'd0;

    // -------------------------------
    // ステータス出力
    // -------------------------------
    assign state_reg       = {1'b0, w_state};
    assign status_reg      = {
        10'd0,
        w_pretrig_ready,    // [5]
        w_en_rd,            // [4]
        w_en_wr,            // [3]
        w_is_dump,          // [2]
        w_dump_done,        // [1]
        w_triggered_latched // [0]
    };

endmodule
